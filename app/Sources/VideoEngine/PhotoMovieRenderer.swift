import AVFoundation
import BirthdayCore
import CoreGraphics
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

    private struct ActiveShot {
        let image: CGImage
        let scene: TemplateScene
        let progress: CGFloat
    }

    private struct DissolveOverlay {
        let shot: ActiveShot
        let weight: CGFloat
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
        let overlaps = (0..<max(0, clips.count - 1)).map { scenes[$0].transitionFrames }
        let timeline = try Timeline(clips: clips, overlaps: overlaps)

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

        // Keep at most the two adjacent shots in memory during a cross-dissolve.
        var loadedImages: [Int: CGImage] = [:]
        var cursor = 0
        let clock = ContinuousClock()
        for outputFrame in 0..<timeline.durationFrames {
            try Task.checkCancellation()
            while cursor < photos.count,
                  timeline.clipStartFrames[cursor] + scenes[cursor].frames <= outputFrame {
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
            let primaryProgress = CGFloat(primaryOffset) / CGFloat(max(1, primaryScene.frames - 1))
            let primaryShot = ActiveShot(image: primaryImage, scene: primaryScene, progress: primaryProgress)

            let overlay: DissolveOverlay?
            if let secondaryIndex {
                guard let secondaryImage = loadedImages[secondaryIndex] else {
                    throw Failure.unreadablePhoto(photos[secondaryIndex].id)
                }
                let secondaryScene = scenes[secondaryIndex]
                let secondaryOffset = outputFrame - timeline.clipStartFrames[secondaryIndex]
                let secondaryProgress = CGFloat(secondaryOffset) / CGFloat(max(1, secondaryScene.frames - 1))
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
            while !input.isReadyForMoreMediaData {
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
