import AVFoundation
import BirthdayCore
import CoreGraphics
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

/// Renders ordered still photos on the shared frame grid.
public enum PhotoMovieRenderer {
    public enum Failure: Error {
        case emptyInput
        case unreadablePhoto(MediaID)
        case invalidDestination
        case encoderUnavailable
        case frameAllocation
        case incompleteWrite
    }

    private static let width = 1920
    private static let height = 1080
    private static let fps = CMTimeScale(VideoTiming.framesPerSecond)
    private static let motionScale: CGFloat = 1.12

    /// Publishes a silent H.264 movie after every shot has encoded successfully.
    public static func write(photos: [PhotoMovieInput], template: MemoryTemplate, to destination: URL) async throws {
        try Task.checkCancellation()
        guard !photos.isEmpty else { throw Failure.emptyInput }
        let scenes = photos.indices.map { template.scenes[$0 % template.scenes.count] }
        let clips = try zip(photos, scenes).map { photo, scene in
            try TimelineClip(media: photo.id, startFrame: 0, frameCount: scene.frames)
        }
        let timeline = try Timeline(clips: clips, overlaps: Array(repeating: 0, count: clips.count - 1))

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
        let writer = try AVAssetWriter(outputURL: staging, fileType: .mp4)
        let settings: [String: Any] = [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: width,
            AVVideoHeightKey: height,
            AVVideoCompressionPropertiesKey: [
                AVVideoExpectedSourceFrameRateKey: Int(fps),
                AVVideoAllowFrameReorderingKey: false,
            ],
        ]
        guard writer.canApply(outputSettings: settings, forMediaType: .video) else { throw Failure.encoderUnavailable }
        let input = AVAssetWriterInput(mediaType: .video, outputSettings: settings)
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: input, sourcePixelBufferAttributes: [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
            kCVPixelBufferWidthKey as String: width,
            kCVPixelBufferHeightKey as String: height,
        ])
        guard writer.canAdd(input) else { throw Failure.encoderUnavailable }
        writer.add(input)
        writer.movieTimeScale = fps
        guard writer.startWriting() else { throw writer.error ?? Failure.encoderUnavailable }
        defer { if writer.status == .writing { writer.cancelWriting() } }
        writer.startSession(atSourceTime: .zero)
        guard let pool = adaptor.pixelBufferPool else { throw Failure.frameAllocation }

        let clock = ContinuousClock()
        for (index, photo) in photos.enumerated() {
            try Task.checkCancellation()
            let image = try readPhoto(photo)
            let scene = scenes[index]
            let still = scene.motion == .still ? try makeFrame(image, in: pool, motion: .still, progress: 0) : nil
            for offset in 0..<scene.frames {
                try Task.checkCancellation()
                let deadline = clock.now.advanced(by: .seconds(10))
                while !input.isReadyForMoreMediaData {
                    guard writer.status == .writing, clock.now < deadline else {
                        throw writer.error ?? Failure.incompleteWrite
                    }
                    try await Task.sleep(for: .milliseconds(5))
                }
                let progress = CGFloat(offset) / CGFloat(max(1, scene.frames - 1))
                let frame = try still ?? makeFrame(image, in: pool, motion: scene.motion, progress: progress)
                let time = CMTime(value: Int64(timeline.clipStartFrames[index] + offset), timescale: fps)
                guard adaptor.append(frame, withPresentationTime: time) else {
                    throw writer.error ?? Failure.incompleteWrite
                }
            }
        }
        try Task.checkCancellation()
        writer.endSession(atSourceTime: CMTime(value: Int64(timeline.durationFrames), timescale: fps))
        input.markAsFinished()
        await writer.finishWriting()
        try Task.checkCancellation()
        guard writer.status == .completed else { throw writer.error ?? Failure.incompleteWrite }
        try EscrituraAtomica.instalar(staging, en: destination)
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

    private static func makeFrame(_ image: CGImage, in pool: CVPixelBufferPool,
                                  motion: PhotoMotion, progress: CGFloat) throws -> CVPixelBuffer {
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
        context.draw(image, in: crop(image: image, in: canvas, motion: motion, progress: progress))
        return storage
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
