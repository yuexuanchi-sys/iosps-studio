import AVFoundation
import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

enum MediaThumbnailRenderer {
    private static let maxSide = 512

    static func readImage(for media: ImportedMedia) async throws(MediaImportError) -> CGImage {
        switch media.kind {
        case .photo:
            let options: [CFString: Any] = [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceCreateThumbnailWithTransform: true,
                kCGImageSourceThumbnailMaxPixelSize: maxSide,
            ]
            guard let source = CGImageSourceCreateWithURL(media.sourceURL as CFURL, nil),
                  let type = CGImageSourceGetType(source),
                  [UTType.jpeg.identifier, UTType.png.identifier, UTType.heic.identifier].contains(type as String),
                  let image = CGImageSourceCreateThumbnailAtIndex(
                    source, CGImageSourceGetPrimaryImageIndex(source), options as CFDictionary
                  ) else {
                throw .unreadableMedia
            }
            return image
        case .video:
            let asset = AVURLAsset(url: media.sourceURL, options: [
                AVURLAssetReferenceRestrictionsKey: NSNumber(value: AVAssetReferenceRestrictions.forbidAll.rawValue),
            ])
            let generator = AVAssetImageGenerator(asset: asset)
            generator.appliesPreferredTrackTransform = true
            generator.maximumSize = CGSize(width: CGFloat(maxSide), height: CGFloat(maxSide))
            do {
                let result = try await generator.image(at: .zero)
                return result.image
            } catch {
                throw Task.isCancelled ? MediaImportError.cancelled : MediaImportError.unreadableMedia
            }
        }
    }

    static func writePNG(_ image: CGImage, to url: URL) throws(MediaImportError) {
        let width = image.width
        let height = image.height
        guard (1...maxSide).contains(width), (1...maxSide).contains(height),
              let colorSpace = CGColorSpace(name: CGColorSpace.displayP3),
              let context = CGContext(
                data: nil,
                width: width,
                height: height,
                bitsPerComponent: 8,
                bytesPerRow: width * 4,
                space: colorSpace,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
              ),
              let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil) else {
            throw .thumbnailFailed
        }
        context.draw(image, in: CGRect(x: 0, y: 0, width: CGFloat(width), height: CGFloat(height)))
        guard let converted = context.makeImage() else { throw .thumbnailFailed }
        CGImageDestinationAddImage(destination, converted, nil)
        guard CGImageDestinationFinalize(destination) else { throw .thumbnailFailed }
    }
}
