import BirthdayCore

/// Describes validation failures for music pacing and soundtrack excerpt planning.
public enum MusicTimingError: Error, Equatable, Sendable {
    case invalidPhotoCount
    case invalidDuration
    case insufficientDuration
    case invalidBeatsPerMinute
    case invalidOverlapCount
    case negativeOverlap
    case invalidFadeDuration
    case invalidSourceDuration
    case excerptOutOfRange
}

/// Captures integer-frame shot durations, safe dissolve overlaps, and audio fades.
public struct MusicPacingPlan: Equatable, Sendable {
    public let sceneFrames: [Int]
    public let overlaps: [Int]
    public let totalFrames: Int
    public let fadeInFrames: Int
    public let fadeOutFrames: Int

    public init(
        sceneFrames: [Int],
        overlaps: [Int],
        totalFrames: Int,
        fadeInFrames: Int,
        fadeOutFrames: Int
    ) {
        self.sceneFrames = sceneFrames
        self.overlaps = overlaps
        self.totalFrames = totalFrames
        self.fadeInFrames = fadeInFrames
        self.fadeOutFrames = fadeOutFrames
    }

    /// Builds a validated timeline matching the planned shot lengths and overlaps.
    public func timeline(for media: [MediaID]) throws -> Timeline {
        guard media.count == sceneFrames.count else {
            throw MusicTimingError.invalidPhotoCount
        }
        let clips = try zip(media, sceneFrames).map { id, frameCount in
            try TimelineClip(media: id, startFrame: 0, frameCount: frameCount)
        }
        return try Timeline(clips: clips, overlaps: overlaps)
    }
}

/// Maps a validated soundtrack excerpt onto an output movie duration with linear fades.
public struct MusicAudioPlan: Equatable, Sendable {
    public let sourceStartFrame: Int
    public let excerptFrames: Int
    public let outputFrames: Int
    public let fadeInFrames: Int
    public let fadeOutFrames: Int

    /// Validates source bounds against available frames and scales fades for short movies.
    public init(
        sourceStartFrame: Int,
        requestedExcerptFrames: Int?,
        availableSourceFrames: Int,
        outputFrames: Int,
        fadeInFrames: Int = 15,
        fadeOutFrames: Int = 30
    ) throws {
        guard availableSourceFrames >= 1 else {
            throw MusicTimingError.invalidSourceDuration
        }
        guard (1...VideoTiming.maxOutputFrames).contains(outputFrames) else {
            throw MusicTimingError.invalidDuration
        }
        guard sourceStartFrame >= 0, sourceStartFrame < availableSourceFrames else {
            throw MusicTimingError.excerptOutOfRange
        }
        let resolvedExcerpt: Int
        if let requestedExcerptFrames {
            guard requestedExcerptFrames >= 1,
                  requestedExcerptFrames <= availableSourceFrames - sourceStartFrame else {
                throw MusicTimingError.excerptOutOfRange
            }
            resolvedExcerpt = requestedExcerptFrames
        } else {
            resolvedExcerpt = availableSourceFrames - sourceStartFrame
        }
        let fades = try MusicBeatAllocator.clampedFades(
            fadeIn: fadeInFrames,
            fadeOut: fadeOutFrames,
            totalFrames: outputFrames
        )
        self.sourceStartFrame = sourceStartFrame
        self.excerptFrames = resolvedExcerpt
        self.outputFrames = outputFrames
        self.fadeInFrames = fades.fadeIn
        self.fadeOutFrames = fades.fadeOut
    }

    /// Evaluates the combined fade-in and fade-out linear amplitude multiplier in [0, 1].
    public func gain(atSample sampleIndex: Int, totalSamples: Int, sampleRate: Int) -> Double {
        guard totalSamples > 0, sampleRate > 0, sampleIndex >= 0, sampleIndex < totalSamples else {
            return 0
        }
        let fps = Int64(VideoTiming.framesPerSecond)
        let fadeInSamples = Int(Int64(fadeInFrames) * Int64(sampleRate) / fps)
        let fadeOutSamples = Int(Int64(fadeOutFrames) * Int64(sampleRate) / fps)
        var amplitude = 1.0
        if fadeInSamples > 0, sampleIndex < fadeInSamples {
            amplitude *= Double(sampleIndex) / Double(fadeInSamples)
        }
        if fadeOutSamples > 0, sampleIndex >= totalSamples - fadeOutSamples {
            let remaining = max(0, totalSamples - 1 - sampleIndex)
            amplitude *= Double(remaining) / Double(fadeOutSamples)
        }
        return min(max(amplitude, 0), 1)
    }

    /// Maps an output sample index into the validated source excerpt, looping cleanly when needed.
    public func sourceSampleOffset(forOutputSample sampleIndex: Int, sampleRate: Int) -> Int {
        guard sampleIndex >= 0, sampleRate > 0 else { return 0 }
        let fps = Int64(VideoTiming.framesPerSecond)
        let startSample = Int(Int64(sourceStartFrame) * Int64(sampleRate) / fps)
        let excerptSamples = max(1, Int(Int64(excerptFrames) * Int64(sampleRate) / fps))
        return startSample + (sampleIndex % excerptSamples)
    }
}

/// Allocates photo shot durations on the shared 30 fps frame grid to match music length or beats.
public enum MusicBeatAllocator {
    /// Distributes exact integer frames across shots, snapping cuts to beats when BPM is supplied.
    public static func allocate(
        photoCount: Int,
        targetDurationFrames: Int,
        beatsPerMinute: Double? = nil,
        preferredOverlaps: [Int] = [],
        defaultFadeInFrames: Int = 15,
        defaultFadeOutFrames: Int = 30
    ) throws -> MusicPacingPlan {
        guard photoCount >= 1 else {
            throw MusicTimingError.invalidPhotoCount
        }
        guard (1...VideoTiming.maxOutputFrames).contains(targetDurationFrames) else {
            throw MusicTimingError.invalidDuration
        }
        guard targetDurationFrames >= photoCount else {
            throw MusicTimingError.insufficientDuration
        }
        if let beatsPerMinute {
            guard beatsPerMinute.isFinite, beatsPerMinute > 0 else {
                throw MusicTimingError.invalidBeatsPerMinute
            }
        }
        let overlapCount = max(0, photoCount - 1)
        let requestedOverlaps: [Int]
        if preferredOverlaps.isEmpty {
            requestedOverlaps = Array(repeating: 0, count: overlapCount)
        } else {
            guard preferredOverlaps.count == overlapCount else {
                throw MusicTimingError.invalidOverlapCount
            }
            guard preferredOverlaps.allSatisfy({ $0 >= 0 }) else {
                throw MusicTimingError.negativeOverlap
            }
            requestedOverlaps = preferredOverlaps
        }

        let fades = try clampedFades(
            fadeIn: defaultFadeInFrames,
            fadeOut: defaultFadeOutFrames,
            totalFrames: targetDurationFrames
        )

        let netFrames = computeNetFrames(
            photoCount: photoCount,
            targetDurationFrames: targetDurationFrames,
            beatsPerMinute: beatsPerMinute
        )

        // Clamp overlaps so every shot satisfies Timeline's incoming + outgoing <= clipLength invariant.
        var clampedOverlaps = Array(repeating: 0, count: overlapCount)
        for index in 0..<overlapCount {
            let maxAllowed = min(netFrames[index], max(0, netFrames[index + 1] - 1))
            clampedOverlaps[index] = min(requestedOverlaps[index], maxAllowed)
        }

        var sceneFrames: [Int] = []
        sceneFrames.reserveCapacity(photoCount)
        for index in 0..<photoCount {
            let outgoing = index < overlapCount ? clampedOverlaps[index] : 0
            sceneFrames.append(netFrames[index] + outgoing)
        }

        return MusicPacingPlan(
            sceneFrames: sceneFrames,
            overlaps: clampedOverlaps,
            totalFrames: targetDurationFrames,
            fadeInFrames: fades.fadeIn,
            fadeOutFrames: fades.fadeOut
        )
    }

    /// Scales fade durations proportionally when a movie is shorter than their requested sum.
    public static func clampedFades(
        fadeIn: Int,
        fadeOut: Int,
        totalFrames: Int
    ) throws -> (fadeIn: Int, fadeOut: Int) {
        guard fadeIn >= 0, fadeOut >= 0 else {
            throw MusicTimingError.invalidFadeDuration
        }
        guard (1...VideoTiming.maxOutputFrames).contains(totalFrames) else {
            throw MusicTimingError.invalidDuration
        }
        let sum = fadeIn + fadeOut
        guard sum > totalFrames else {
            return (fadeIn, fadeOut)
        }
        if fadeOut == 0 {
            return (totalFrames, 0)
        }
        if fadeIn == 0 {
            return (0, totalFrames)
        }
        let scaledIn = Int((Double(totalFrames) * Double(fadeIn) / Double(sum)).rounded(.down))
        let scaledOut = totalFrames - scaledIn
        return (scaledIn, scaledOut)
    }

    private static func computeNetFrames(
        photoCount: Int,
        targetDurationFrames: Int,
        beatsPerMinute: Double?
    ) -> [Int] {
        guard photoCount > 1 else {
            return [targetDurationFrames]
        }
        guard let beatsPerMinute else {
            return equalNetFrames(photoCount: photoCount, targetDurationFrames: targetDurationFrames)
        }
        let beatFrames = Double(VideoTiming.framesPerSecond) * 60.0 / beatsPerMinute
        // When beats occur at least once every frame, every integer frame is a beat so equal cuts already align.
        guard beatFrames > 1.0 else {
            return equalNetFrames(photoCount: photoCount, targetDurationFrames: targetDurationFrames)
        }

        var beats: [Int] = []
        var step = 1
        while true {
            let candidate = Int((Double(step) * beatFrames).rounded())
            if candidate >= targetDurationFrames {
                break
            }
            if candidate >= 1, beats.last != candidate {
                beats.append(candidate)
            }
            step += 1
        }
        guard !beats.isEmpty else {
            return equalNetFrames(photoCount: photoCount, targetDurationFrames: targetDurationFrames)
        }

        var cuts: [Int] = [0]
        cuts.reserveCapacity(photoCount + 1)
        for index in 1..<photoCount {
            let minCut = cuts[index - 1] + 1
            let maxCut = targetDurationFrames - (photoCount - index)
            let ideal = Double(index) * Double(targetDurationFrames) / Double(photoCount)
            var chosen: Int?
            var bestDistance = Double.infinity
            for beat in beats where beat >= minCut && beat <= maxCut {
                let distance = abs(Double(beat) - ideal)
                if distance < bestDistance {
                    bestDistance = distance
                    chosen = beat
                }
            }
            let fallback = min(maxCut, max(minCut, Int(ideal.rounded())))
            cuts.append(chosen ?? fallback)
        }
        cuts.append(targetDurationFrames)

        return (0..<photoCount).map { cuts[$0 + 1] - cuts[$0] }
    }

    private static func equalNetFrames(photoCount: Int, targetDurationFrames: Int) -> [Int] {
        let base = targetDurationFrames / photoCount
        let remainder = targetDurationFrames % photoCount
        return (0..<photoCount).map { $0 < remainder ? base + 1 : base }
    }
}
