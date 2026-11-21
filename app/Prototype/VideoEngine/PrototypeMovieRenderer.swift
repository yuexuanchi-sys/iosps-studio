import AVFoundation
import BirthdayCore
import CoreGraphics
import CoreVideo
import Foundation
import ImageIO
import TimelineKit

nonisolated enum PrototypeMovieError: Error {
    case unsupportedTimeline
    case missingPhoto
    case missingTemplate
    case frameAllocation
    case encoderUnavailable
    case incompleteWrite
}

nonisolated enum PrototypeMovieRenderer {
    private static let width = 1280
    private static let height = 720

    /// Turns the selected still into a silent H.264 track using the timeline's integer frame grid.
    static func write(photo: URL, timeline: Timeline, to destination: URL) async throws {
        guard timeline.clips.count == 1, timeline.clipStartFrames == [0],
              timeline.clips[0].startFrame == 0 else { throw PrototypeMovieError.unsupportedTimeline }
        let buffer = CVReadOnlyPixelBuffer(unsafeBuffer: try frame(for: photo))
        let writer = try AVAssetWriter(outputURL: destination, fileType: .mp4)
        let fps = VideoTiming.framesPerSecond
        let settings: [String: Any] = [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: width,
            AVVideoHeightKey: height,
            AVVideoCompressionPropertiesKey: [
                AVVideoExpectedSourceFrameRateKey: fps,
                AVVideoAllowFrameReorderingKey: false,
            ],
        ]
        guard writer.canApply(outputSettings: settings, forMediaType: .video) else {
            throw PrototypeMovieError.encoderUnavailable
        }
        let input = AVAssetWriterInput(mediaType: .video, outputSettings: settings)
        guard writer.canAdd(input) else { throw PrototypeMovieError.encoderUnavailable }
        let receiver = writer.inputPixelBufferReceiver(for: input, pixelBufferAttributes: nil)
        writer.movieTimeScale = CMTimeScale(fps)
        try writer.start()
        writer.startSession(atSourceTime: .zero)
        do {
            for index in 0..<timeline.durationFrames {
                try Task.checkCancellation()
                try await receiver.append(buffer, with: CMTime(value: Int64(index), timescale: CMTimeScale(fps)))
            }
            writer.endSession(atSourceTime: CMTime(value: Int64(timeline.durationFrames), timescale: CMTimeScale(fps)))
            receiver.finish()
            await writer.finishWriting()
            guard writer.status == .completed else { throw writer.error ?? PrototypeMovieError.incompleteWrite }
        } catch {
            if writer.status == .writing { writer.cancelWriting() }
            throw error
        }
    }

    private static func frame(for photo: URL) throws -> CVPixelBuffer {
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: width,
        ]
        guard let source = CGImageSourceCreateWithURL(photo as CFURL, nil),
              let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
            throw PrototypeMovieError.missingPhoto
        }
        var storage: CVPixelBuffer?
        let result = CVPixelBufferCreate(kCFAllocatorDefault, width, height, kCVPixelFormatType_32BGRA, nil, &storage)
        guard result == kCVReturnSuccess, let storage,
              CVPixelBufferLockBaseAddress(storage, []) == kCVReturnSuccess else {
            throw PrototypeMovieError.frameAllocation
        }
        defer { CVPixelBufferUnlockBaseAddress(storage, []) }
        guard let address = CVPixelBufferGetBaseAddress(storage),
              let space = CGColorSpace(name: CGColorSpace.sRGB),
              let context = CGContext(data: address, width: width, height: height, bitsPerComponent: 8,
                                      bytesPerRow: CVPixelBufferGetBytesPerRow(storage), space: space,
                                      bitmapInfo: CGBitmapInfo.byteOrder32Little.rawValue |
                                                  CGImageAlphaInfo.premultipliedFirst.rawValue) else {
            throw PrototypeMovieError.frameAllocation
        }
        let canvas = CGRect(x: 0, y: 0, width: CGFloat(width), height: CGFloat(height))
        let scale = min(canvas.width / CGFloat(image.width), canvas.height / CGFloat(image.height))
        let fitted = CGSize(width: CGFloat(image.width) * scale, height: CGFloat(image.height) * scale)
        let rect = CGRect(x: (canvas.width - fitted.width) / 2, y: (canvas.height - fitted.height) / 2,
                          width: fitted.width, height: fitted.height)
        context.setFillColor(gray: 0, alpha: 1)
        context.fill(canvas)
        context.interpolationQuality = .high
        context.draw(image, in: rect)
        return storage
    }
}
