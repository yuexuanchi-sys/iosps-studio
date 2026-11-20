import BirthdayCore

/// Defines a source range whose end is exclusive.
public struct TimelineClip: Equatable, Codable, Sendable {
    public let media: MediaID
    public let startFrame: Int
    public let frameCount: Int

    /// Rejects invalid source ranges before composition.
    public init(media: MediaID, startFrame: Int, frameCount: Int) throws {
        guard (1...VideoTiming.maxOutputFrames).contains(frameCount),
              (0...(Int.max - frameCount)).contains(startFrame) else {
            throw Timeline.ValidationError.invalidSourceRange
        }
        self.media = media
        self.startFrame = startFrame
        self.frameCount = frameCount
    }

    private enum CodingKeys: String, CodingKey {
        case media, startFrame, frameCount
    }

    /// Applies the same range checks to data restored from disk.
    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(
            media: container.decode(MediaID.self, forKey: .media),
            startFrame: container.decode(Int.self, forKey: .startFrame),
            frameCount: container.decode(Int.self, forKey: .frameCount)
        )
    }
}

/// Positions a single visual track with cuts or two-clip dissolves.
public struct Timeline: Equatable, Codable, Sendable {
    public let clips: [TimelineClip]
    public let overlaps: [Int]
    public let clipStartFrames: [Int]
    public let durationFrames: Int

    public enum ValidationError: Error {
        case invalidSourceRange
        case invalidOverlapCount
        case invalidOverlap(clipIndex: Int)
        case outputTooLong
    }

    /// Validates boundaries and computes output positions on an integer frame grid.
    public init(clips: [TimelineClip], overlaps: [Int]) throws {
        guard overlaps.count == max(0, clips.count - 1) else {
            throw ValidationError.invalidOverlapCount
        }

        var positions: [Int] = []
        var endFrame = 0
        for (index, clip) in clips.enumerated() {
            let incoming = index == 0 ? 0 : overlaps[index - 1]
            let outgoing = overlaps.indices.contains(index) ? overlaps[index] : 0
            guard (0..<clip.frameCount).contains(incoming),
                  (0..<clip.frameCount).contains(outgoing),
                  incoming + outgoing <= clip.frameCount else {
                throw ValidationError.invalidOverlap(clipIndex: index)
            }
            let position = endFrame - incoming
            positions.append(position)
            endFrame = position + clip.frameCount
            guard endFrame <= VideoTiming.maxOutputFrames else {
                throw ValidationError.outputTooLong
            }
        }

        self.clips = clips
        self.overlaps = overlaps
        clipStartFrames = positions
        durationFrames = endFrame
    }

    private enum CodingKeys: String, CodingKey {
        case clips, overlaps
    }

    /// Recomputes derived positions instead of trusting persisted calculations.
    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(
            clips: container.decode([TimelineClip].self, forKey: .clips),
            overlaps: container.decode([Int].self, forKey: .overlaps)
        )
    }
}
