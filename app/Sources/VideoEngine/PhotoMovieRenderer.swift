import AVFoundation
import BirthdayCore
import CoreGraphics
import CoreMedia
import CoreText
import CoreVideo
import Foundation
import ImageIO
import TemplateKit
import TimelineKit

/// Identifies a photo and its resolved local file for one template shot.
public struct PhotoMovieInput: Sendable {
    public let id: MediaID
    public let url: URL

    public init(id: MediaID, url: URL) {
        self.id = id
        self.url = url
    }
}

/// Identifies a resolved local soundtrack file and excerpt fade settings for a photo movie.
public struct PhotoMovieMusic: Sendable {
    public let url: URL
    public let startFrame: Int
    public let excerptFrames: Int?
    public let fadeInFrames: Int
    public let fadeOutFrames: Int

    public init(
        url: URL,
        startFrame: Int = 0,
        excerptFrames: Int? = nil,
        fadeInFrames: Int = 15,
        fadeOutFrames: Int = 30
    ) {
        self.url = url
        self.startFrame = startFrame
        self.excerptFrames = excerptFrames
        self.fadeInFrames = fadeInFrames
        self.fadeOutFrames = fadeOutFrames
    }

    public init(
        url: URL,
        excerpt: TemplateMusic,
        fadeInFrames: Int = 15,
        fadeOutFrames: Int = 30
    ) {
        self.url = url
        self.startFrame = excerpt.startFrame
        self.excerptFrames = excerpt.frames
        self.fadeInFrames = fadeInFrames
        self.fadeOutFrames = fadeOutFrames
    }
}

/// Renders ordered still photos on the shared frame grid.
public enum PhotoMovieRenderer {
    public enum Failure: Error {
        case emptyInput
        case unreadablePhoto(MediaID)
        case unreadableAudio
        case audioExcerptOutOfRange
        case invalidDestination
        case encoderUnavailable
        case frameAllocation
        case incompleteWrite
    }

    private struct ActiveShot {
        let image: CGImage
        let scene: TemplateScene
        let progress: CGFloat
    }

    private struct DissolveOverlay {
        let shot: ActiveShot
        let weight: CGFloat
    }

    private struct DecodedAudio {
        let interleavedStereo: [Float]
        let plan: MusicAudioPlan
    }

    private static let width = 1920
    private static let height = 1080
    private static let fps = CMTimeScale(VideoTiming.framesPerSecond)
    private static let audioSampleRate = 44_100
    private static let audioChannels = 2
    // 44,100 / 30 = 1,470 audio samples per video frame on the shared 30 fps grid.
    private static let samplesPerVideoFrame = audioSampleRate / VideoTiming.framesPerSecond
    private static let motionScale: CGFloat = 1.12

    /// Publishes an H.264 movie (with optional AAC music) after every frame encodes cleanly.
    public static func write(
        photos: [PhotoMovieInput],
        template: MemoryTemplate,
        music: PhotoMovieMusic? = nil,
        pacing: MusicPacingPlan? = nil,
        to destination: URL,
        progress: (@Sendable (Double) -> Void)? = nil
    ) async throws {
        try Task.checkCancellation()
        guard !photos.isEmpty else { throw Failure.emptyInput }
        let scenes = photos.indices.map { template.scenes[$0 % template.scenes.count] }
        let timeline: Timeline
        let shotFrames: [Int]
        if let pacing {
            timeline = try pacing.timeline(for: photos.map(\.id))
            shotFrames = pacing.sceneFrames
        } else {
            let clips = try zip(photos, scenes).map { photo, scene in
                try TimelineClip(media: photo.id, startFrame: 0, frameCount: scene.frames)
            }
            let overlaps = (0..<max(0, clips.count - 1)).map { scenes[$0].transitionFrames }
            timeline = try Timeline(clips: clips, overlaps: overlaps)
            shotFrames = scenes.map(\.frames)
        }

        let decodedAudio: DecodedAudio?
        if let music {
            decodedAudio = try await readAudio(music, outputFrames: timeline.durationFrames)
        } else {
            decodedAudio = nil
        }

        guard destination.isFileURL, !destination.hasDirectoryPath else { throw Failure.invalidDestination }
        let hasScope = destination.startAccessingSecurityScopedResource()
        defer { if hasScope { destination.stopAccessingSecurityScopedResource() } }
        let directory = destination.deletingLastPathComponent()
        guard FileManager.default.isWritableFile(atPath: directory.path) else { throw Failure.invalidDestination }
        if let attributes = try? destination.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey]),
           attributes.isRegularFile == false || attributes.isSymbolicLink == true {
            throw Failure.invalidDestination
        }

        let staging = EscrituraAtomica.temporal(para: destination)
        defer { try? FileManager.default.removeItem(at: staging) }

        if let decodedAudio {
            let scratch = FileManager.default.temporaryDirectory
                .appendingPathComponent("iosps-movie-\(UUID().uuidString)", isDirectory: true)
            try FileManager.default.createDirectory(at: scratch, withIntermediateDirectories: true)
            defer { try? FileManager.default.removeItem(at: scratch) }

            let videoURL = scratch.appendingPathComponent("video.mp4")
            let audioURL = scratch.appendingPathComponent("audio.wav")
            progress?(0)
            try await writeSilentVideo(
                photos: photos,
                scenes: scenes,
                shotFrames: shotFrames,
                timeline: timeline,
                to: videoURL,
                progressRange: 0.0...0.8,
                progress: progress
            )
            try Task.checkCancellation()
            let totalAudioSamples = timeline.durationFrames * samplesPerVideoFrame
            try writeProcessedWave(from: decodedAudio, totalOutputSamples: totalAudioSamples, to: audioURL)
            try Task.checkCancellation()
            progress?(0.85)
            let duration = CMTime(value: Int64(timeline.durationFrames), timescale: fps)
            try await mux(videoURL: videoURL, audioURL: audioURL, duration: duration, to: staging)
            try Task.checkCancellation()
            try EscrituraAtomica.instalar(staging, en: destination)
            progress?(1)
        } else {
            progress?(0)
            try await writeSilentVideo(
                photos: photos,
                scenes: scenes,
                shotFrames: shotFrames,
                timeline: timeline,
                to: staging,
                progressRange: 0.0...1.0,
                progress: progress
            )
            try Task.checkCancellation()
            try EscrituraAtomica.instalar(staging, en: destination)
            progress?(1)
        }
    }

    private static func writeSilentVideo(
        photos: [PhotoMovieInput],
        scenes: [TemplateScene],
        shotFrames: [Int],
        timeline: Timeline,
        to outputURL: URL,
        progressRange: ClosedRange<Double>,
        progress: (@Sendable (Double) -> Void)?
    ) async throws {
        let writer = try AVAssetWriter(outputURL: outputURL, fileType: .mp4)
        let videoSettings: [String: Any] = [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: width,
            AVVideoHeightKey: height,
            AVVideoCompressionPropertiesKey: [
                AVVideoExpectedSourceFrameRateKey: Int(fps),
                AVVideoAllowFrameReorderingKey: false,
            ],
        ]
        guard writer.canApply(outputSettings: videoSettings, forMediaType: .video) else { throw Failure.encoderUnavailable }
        let videoInput = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: videoInput, sourcePixelBufferAttributes: [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
            kCVPixelBufferWidthKey as String: width,
            kCVPixelBufferHeightKey as String: height,
        ])
        guard writer.canAdd(videoInput) else { throw Failure.encoderUnavailable }
        writer.add(videoInput)
        writer.movieTimeScale = fps
        guard writer.startWriting() else { throw writer.error ?? Failure.encoderUnavailable }
        defer { if writer.status == .writing { writer.cancelWriting() } }
        writer.startSession(atSourceTime: .zero)
        guard let pool = adaptor.pixelBufferPool else { throw Failure.frameAllocation }

        // Keep at most the two adjacent shots in memory during a cross-dissolve.
        var loadedImages: [Int: CGImage] = [:]
        var cursor = 0
        let clock = ContinuousClock()
        let span = progressRange.upperBound - progressRange.lowerBound
        for outputFrame in 0..<timeline.durationFrames {
            try Task.checkCancellation()
            while cursor < photos.count,
                  timeline.clipStartFrames[cursor] + shotFrames[cursor] <= outputFrame {
                loadedImages.removeValue(forKey: cursor)
                cursor += 1
            }
            guard cursor < photos.count else { throw Failure.incompleteWrite }
            let primaryIndex = cursor
            let secondaryIndex: Int? = {
                let next = cursor + 1
                guard next < photos.count, timeline.clipStartFrames[next] <= outputFrame else { return nil }
                return next
            }()
            if loadedImages[primaryIndex] == nil {
                loadedImages[primaryIndex] = try readPhoto(photos[primaryIndex])
            }
            if let secondaryIndex, loadedImages[secondaryIndex] == nil {
                loadedImages[secondaryIndex] = try readPhoto(photos[secondaryIndex])
            }
            guard let primaryImage = loadedImages[primaryIndex] else {
                throw Failure.unreadablePhoto(photos[primaryIndex].id)
            }
            let primaryScene = scenes[primaryIndex]
            let primaryOffset = outputFrame - timeline.clipStartFrames[primaryIndex]
            let primaryProgress = CGFloat(primaryOffset) / CGFloat(max(1, shotFrames[primaryIndex] - 1))
            let primaryShot = ActiveShot(image: primaryImage, scene: primaryScene, progress: primaryProgress)

            let overlay: DissolveOverlay?
            if let secondaryIndex {
                guard let secondaryImage = loadedImages[secondaryIndex] else {
                    throw Failure.unreadablePhoto(photos[secondaryIndex].id)
                }
                let secondaryScene = scenes[secondaryIndex]
                let secondaryOffset = outputFrame - timeline.clipStartFrames[secondaryIndex]
                let secondaryProgress = CGFloat(secondaryOffset) / CGFloat(max(1, shotFrames[secondaryIndex] - 1))
                let overlap = timeline.overlaps[primaryIndex]
                // Span strictly between 0 and 1 across all overlap frames so every transition frame blends both shots.
                let weight = CGFloat(secondaryOffset + 1) / CGFloat(overlap + 1)
                overlay = DissolveOverlay(
                    shot: ActiveShot(image: secondaryImage, scene: secondaryScene, progress: secondaryProgress),
                    weight: weight
                )
            } else {
                overlay = nil
            }

            let deadline = clock.now.advanced(by: .seconds(10))
            while !videoInput.isReadyForMoreMediaData {
                try Task.checkCancellation()
                guard writer.status == .writing, clock.now < deadline else {
                    throw writer.error ?? Failure.incompleteWrite
                }
                try await Task.sleep(for: .milliseconds(5))
            }
            let frame = try makeFrame(primary: primaryShot, overlay: overlay, in: pool)
            let time = CMTime(value: Int64(outputFrame), timescale: fps)
            guard adaptor.append(frame, withPresentationTime: time) else {
                throw writer.error ?? Failure.incompleteWrite
            }
            let fraction = Double(outputFrame + 1) / Double(timeline.durationFrames)
            progress?(progressRange.lowerBound + span * fraction)
        }
        try Task.checkCancellation()
        writer.endSession(atSourceTime: CMTime(value: Int64(timeline.durationFrames), timescale: fps))
        videoInput.markAsFinished()
        await writer.finishWriting()
        try Task.checkCancellation()
        guard writer.status == .completed else { throw writer.error ?? Failure.incompleteWrite }
    }

    /// Muxes the encoded video track and faded stereo PCM soundtrack via AVAssetExportSession
    /// to avoid dual-input interleaving stalls in headless AVAssetWriter AAC encoding.
    private static func mux(videoURL: URL, audioURL: URL, duration: CMTime, to destination: URL) async throws {
        let composition = AVMutableComposition()
        let videoAsset = AVURLAsset(url: videoURL)
        let audioAsset = AVURLAsset(url: audioURL)
        guard let sourceVideo = try await videoAsset.loadTracks(withMediaType: .video).first,
              let sourceAudio = try await audioAsset.loadTracks(withMediaType: .audio).first,
              let compositionVideo = composition.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid),
              let compositionAudio = composition.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid) else {
            throw Failure.encoderUnavailable
        }
        let range = CMTimeRange(start: .zero, duration: duration)
        try compositionVideo.insertTimeRange(range, of: sourceVideo, at: .zero)
        try compositionAudio.insertTimeRange(range, of: sourceAudio, at: .zero)

        guard let session = AVAssetExportSession(asset: composition, presetName: AVAssetExportPresetHighestQuality) else {
            throw Failure.encoderUnavailable
        }
        try Task.checkCancellation()
        if #available(macOS 15.0, *) {
            try await session.export(to: destination, as: .mp4)
        } else {
            session.outputURL = destination
            session.outputFileType = .mp4
            await session.export()
            if session.status != .completed {
                throw session.error ?? Failure.incompleteWrite
            }
        }
    }

    private static func readAudio(_ music: PhotoMovieMusic, outputFrames: Int) async throws -> DecodedAudio {
        guard music.url.isFileURL else { throw Failure.unreadableAudio }
        let hasScope = music.url.startAccessingSecurityScopedResource()
        defer { if hasScope { music.url.stopAccessingSecurityScopedResource() } }
        do {
            let asset = AVURLAsset(url: music.url, options: [
                AVURLAssetPreferPreciseDurationAndTimingKey: true,
                AVURLAssetReferenceRestrictionsKey: NSNumber(value: AVAssetReferenceRestrictions.forbidAll.rawValue),
            ])
            let tracks = try await asset.loadTracks(withMediaType: .audio)
            guard let track = tracks.first else { throw Failure.unreadableAudio }
            let reader = try AVAssetReader(asset: asset)
            let pcmSettings: [String: Any] = [
                AVFormatIDKey: kAudioFormatLinearPCM,
                AVLinearPCMBitDepthKey: 32,
                AVLinearPCMIsFloatKey: true,
                AVLinearPCMIsBigEndianKey: false,
                AVLinearPCMIsNonInterleaved: false,
                AVNumberOfChannelsKey: audioChannels,
                AVSampleRateKey: audioSampleRate,
            ]
            let output = AVAssetReaderTrackOutput(track: track, outputSettings: pcmSettings)
            guard reader.canAdd(output) else { throw Failure.unreadableAudio }
            reader.add(output)
            guard reader.startReading() else { throw Failure.unreadableAudio }

            var pcm: [Float] = []
            while reader.status == .reading, let buffer = output.copyNextSampleBuffer() {
                try Task.checkCancellation()
                guard let block = CMSampleBufferGetDataBuffer(buffer) else { continue }
                let byteLength = CMBlockBufferGetDataLength(block)
                let floatCount = byteLength / MemoryLayout<Float>.size
                guard floatCount > 0 else { continue }
                var chunk = [Float](repeating: 0, count: floatCount)
                let copyStatus = chunk.withUnsafeMutableBytes { dest in
                    CMBlockBufferCopyDataBytes(
                        block,
                        atOffset: 0,
                        dataLength: floatCount * MemoryLayout<Float>.size,
                        destination: dest.baseAddress!
                    )
                }
                guard copyStatus == kCMBlockBufferNoErr else {
                    reader.cancelReading()
                    throw Failure.unreadableAudio
                }
                pcm.append(contentsOf: chunk)
            }
            guard reader.status == .completed else {
                reader.cancelReading()
                throw Failure.unreadableAudio
            }
            let totalSampleFrames = pcm.count / audioChannels
            let availableSourceFrames = totalSampleFrames / samplesPerVideoFrame
            guard availableSourceFrames >= 1 else { throw Failure.unreadableAudio }
            let plan = try MusicAudioPlan(
                sourceStartFrame: music.startFrame,
                requestedExcerptFrames: music.excerptFrames,
                availableSourceFrames: availableSourceFrames,
                outputFrames: outputFrames,
                fadeInFrames: music.fadeInFrames,
                fadeOutFrames: music.fadeOutFrames
            )
            return DecodedAudio(interleavedStereo: pcm, plan: plan)
        } catch is CancellationError {
            throw CancellationError()
        } catch let failure as Failure {
            throw failure
        } catch MusicTimingError.excerptOutOfRange {
            throw Failure.audioExcerptOutOfRange
        } catch {
            throw Failure.unreadableAudio
        }
    }

    private static func writeProcessedWave(
        from audio: DecodedAudio,
        totalOutputSamples: Int,
        to url: URL
    ) throws {
        let bitsPerSample = 16
        let bytesPerSample = bitsPerSample / 8
        let dataByteCount = totalOutputSamples * audioChannels * bytesPerSample
        let headerByteCount = 44
        var bytes = [UInt8](repeating: 0, count: headerByteCount + dataByteCount)

        func writeASCII(_ text: String, at offset: Int) {
            for (index, byte) in text.utf8.enumerated() {
                bytes[offset + index] = byte
            }
        }
        func writeUInt32(_ value: UInt32, at offset: Int) {
            bytes[offset] = UInt8(value & 0xFF)
            bytes[offset + 1] = UInt8((value >> 8) & 0xFF)
            bytes[offset + 2] = UInt8((value >> 16) & 0xFF)
            bytes[offset + 3] = UInt8((value >> 24) & 0xFF)
        }
        func writeUInt16(_ value: UInt16, at offset: Int) {
            bytes[offset] = UInt8(value & 0xFF)
            bytes[offset + 1] = UInt8((value >> 8) & 0xFF)
        }

        let byteRate = UInt32(audioSampleRate * audioChannels * bytesPerSample)
        let blockAlign = UInt16(audioChannels * bytesPerSample)
        writeASCII("RIFF", at: 0)
        writeUInt32(UInt32(36 + dataByteCount), at: 4)
        writeASCII("WAVE", at: 8)
        writeASCII("fmt ", at: 12)
        writeUInt32(16, at: 16)
        writeUInt16(1, at: 20)
        writeUInt16(UInt16(audioChannels), at: 22)
        writeUInt32(UInt32(audioSampleRate), at: 24)
        writeUInt32(byteRate, at: 28)
        writeUInt16(blockAlign, at: 32)
        writeUInt16(UInt16(bitsPerSample), at: 34)
        writeASCII("data", at: 36)
        writeUInt32(UInt32(dataByteCount), at: 40)

        let source = audio.interleavedStereo
        let plan = audio.plan
        var writeOffset = headerByteCount
        for outputSample in 0..<totalOutputSamples {
            let gain = Float(plan.gain(atSample: outputSample, totalSamples: totalOutputSamples, sampleRate: audioSampleRate))
            let sourceSample = plan.sourceSampleOffset(forOutputSample: outputSample, sampleRate: audioSampleRate)
            let sourceBase = sourceSample * audioChannels
            for channel in 0..<audioChannels {
                let clamped = min(max(source[sourceBase + channel] * gain, -1.0), 1.0)
                let quantized = Int16((clamped * Float(Int16.max)).rounded())
                let pattern = UInt16(bitPattern: quantized)
                bytes[writeOffset] = UInt8(pattern & 0xFF)
                bytes[writeOffset + 1] = UInt8((pattern >> 8) & 0xFF)
                writeOffset += 2
            }
        }
        try Data(bytes).write(to: url, options: .atomic)
    }

    private static func readPhoto(_ photo: PhotoMovieInput) throws -> CGImage {
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: width * 2,
        ]
        guard photo.url.isFileURL,
              let source = CGImageSourceCreateWithURL(photo.url as CFURL, nil),
              let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
            throw Failure.unreadablePhoto(photo.id)
        }
        return image
    }

    private static func makeFrame(
        primary: ActiveShot,
        overlay: DissolveOverlay?,
        in pool: CVPixelBufferPool
    ) throws -> CVPixelBuffer {
        var storage: CVPixelBuffer?
        guard CVPixelBufferPoolCreatePixelBuffer(kCFAllocatorDefault, pool, &storage) == kCVReturnSuccess,
              let storage, CVPixelBufferLockBaseAddress(storage, []) == kCVReturnSuccess else {
            throw Failure.frameAllocation
        }
        defer { CVPixelBufferUnlockBaseAddress(storage, []) }
        guard let address = CVPixelBufferGetBaseAddress(storage),
              let colorSpace = CGColorSpace(name: CGColorSpace.sRGB),
              let context = CGContext(data: address, width: width, height: height, bitsPerComponent: 8,
                                      bytesPerRow: CVPixelBufferGetBytesPerRow(storage), space: colorSpace,
                                      bitmapInfo: CGBitmapInfo.byteOrder32Little.rawValue |
                                                  CGImageAlphaInfo.premultipliedFirst.rawValue) else {
            throw Failure.frameAllocation
        }
        let canvas = CGRect(x: 0, y: 0, width: width, height: height)
        context.setFillColor(gray: 0, alpha: 1)
        context.fill(canvas)
        context.interpolationQuality = .high
        drawShot(primary, in: context, canvas: canvas)

        if let overlay {
            context.saveGState()
            context.setAlpha(overlay.weight)
            if normalizedCaption(overlay.shot.scene.caption) != nil {
                // Composite the incoming photo and caption together before applying dissolve alpha.
                context.beginTransparencyLayer(in: canvas, auxiliaryInfo: nil)
                drawShot(overlay.shot, in: context, canvas: canvas)
                context.endTransparencyLayer()
            } else {
                context.draw(overlay.shot.image, in: crop(image: overlay.shot.image, in: canvas,
                                                          motion: overlay.shot.scene.motion,
                                                          progress: overlay.shot.progress))
            }
            context.restoreGState()
        }
        return storage
    }

    private static func drawShot(_ shot: ActiveShot, in context: CGContext, canvas: CGRect) {
        context.draw(shot.image, in: crop(image: shot.image, in: canvas,
                                          motion: shot.scene.motion, progress: shot.progress))
        if let caption = normalizedCaption(shot.scene.caption) {
            drawCaption(caption, in: context, canvas: canvas)
        }
    }

    private static func normalizedCaption(_ caption: String?) -> String? {
        guard let trimmed = caption?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmed.isEmpty else {
            return nil
        }
        return trimmed
    }

    private static func drawCaption(_ text: String, in context: CGContext, canvas: CGRect) {
        let horizontalMargin: CGFloat = 120
        let bottomMargin: CGFloat = 72
        let paddingX: CGFloat = 36
        let paddingY: CGFloat = 20
        let cornerRadius: CGFloat = 18
        let fontSize: CGFloat = 56
        let maxTextWidth = canvas.width - (horizontalMargin + paddingX) * 2
        let maxTextHeight: CGFloat = 240

        let font = CTFontCreateWithName("PingFangSC-Semibold" as CFString, fontSize, nil)
        let alignment = CTTextAlignment.center
        let lineSpacing: CGFloat = 10
        let lineBreak = CTLineBreakMode.byWordWrapping
        let paragraphStyle: CTParagraphStyle = withUnsafeBytes(of: alignment) { alignBytes in
            withUnsafeBytes(of: lineSpacing) { spacingBytes in
                withUnsafeBytes(of: lineBreak) { breakBytes in
                    let settings = [
                        CTParagraphStyleSetting(spec: .alignment,
                                                valueSize: MemoryLayout<CTTextAlignment>.size,
                                                value: alignBytes.baseAddress!),
                        CTParagraphStyleSetting(spec: .lineSpacingAdjustment,
                                                valueSize: MemoryLayout<CGFloat>.size,
                                                value: spacingBytes.baseAddress!),
                        CTParagraphStyleSetting(spec: .lineBreakMode,
                                                valueSize: MemoryLayout<CTLineBreakMode>.size,
                                                value: breakBytes.baseAddress!),
                    ]
                    return CTParagraphStyleCreate(settings, settings.count)
                }
            }
        }
        let white = CGColor(red: 1, green: 1, blue: 1, alpha: 1)
        let backdrop = CGColor(red: 0, green: 0, blue: 0, alpha: 0.56)
        let shadow = CGColor(red: 0, green: 0, blue: 0, alpha: 0.45)
        let attributes: [NSAttributedString.Key: Any] = [
            NSAttributedString.Key(rawValue: kCTFontAttributeName as String): font,
            NSAttributedString.Key(rawValue: kCTForegroundColorAttributeName as String): white,
            NSAttributedString.Key(rawValue: kCTParagraphStyleAttributeName as String): paragraphStyle,
        ]
        let attributed = NSAttributedString(string: text, attributes: attributes)
        let framesetter = CTFramesetterCreateWithAttributedString(attributed as CFAttributedString)
        let suggested = CTFramesetterSuggestFrameSizeWithConstraints(
            framesetter,
            CFRange(location: 0, length: 0),
            nil,
            CGSize(width: maxTextWidth, height: maxTextHeight),
            nil
        )
        let textWidth = min(maxTextWidth, ceil(suggested.width) + 12)
        let textHeight = min(maxTextHeight, ceil(suggested.height) + 4)
        let pillWidth = textWidth + paddingX * 2
        let pillHeight = textHeight + paddingY * 2
        let pillRect = CGRect(
            x: (canvas.width - pillWidth) / 2,
            y: bottomMargin,
            width: pillWidth,
            height: pillHeight
        )
        let textRect = CGRect(
            x: pillRect.minX + paddingX,
            y: pillRect.minY + (pillRect.height - textHeight) / 2,
            width: textWidth,
            height: textHeight
        )

        context.saveGState()
        context.setFillColor(backdrop)
        let pillPath = CGPath(roundedRect: pillRect, cornerWidth: cornerRadius, cornerHeight: cornerRadius, transform: nil)
        context.addPath(pillPath)
        context.fillPath()

        context.setShadow(offset: CGSize(width: 0, height: -2), blur: 6, color: shadow)
        context.textMatrix = .identity
        let textPath = CGPath(rect: textRect, transform: nil)
        let frame = CTFramesetterCreateFrame(framesetter, CFRange(location: 0, length: 0), textPath, nil)
        CTFrameDraw(frame, context)
        context.restoreGState()
    }

    private static func crop(image: CGImage, in canvas: CGRect, motion: PhotoMotion, progress: CGFloat) -> CGRect {
        let scale = max(canvas.width / CGFloat(image.width), canvas.height / CGFloat(image.height))
        let zoom: CGFloat
        let horizontalOffset: CGFloat
        switch motion {
        case .still:
            zoom = 1
            horizontalOffset = 0
        case .zoomIn:
            zoom = 1 + (motionScale - 1) * progress
            horizontalOffset = 0
        case .zoomOut:
            zoom = motionScale - (motionScale - 1) * progress
            horizontalOffset = 0
        case .panLeft, .panRight:
            zoom = motionScale
            horizontalOffset = motion == .panLeft ? 1 - 2 * progress : 2 * progress - 1
        }
        let width = CGFloat(image.width) * scale * zoom
        let height = CGFloat(image.height) * scale * zoom
        let margin = (width - canvas.width) / 2
        return CGRect(x: -margin + margin * horizontalOffset, y: (canvas.height - height) / 2,
                      width: width, height: height)
    }
}
