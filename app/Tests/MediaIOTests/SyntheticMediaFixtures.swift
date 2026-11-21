import AVFoundation
import CoreGraphics
import CoreMedia
import CoreVideo
import Foundation
import ImageIO
import Testing
import UniformTypeIdentifiers

enum SyntheticMediaFixtures {
    static func writeSupportedFormats(in directory: URL) async throws -> [URL] {
        let jpeg = directory.appendingPathComponent("portrait.jpg")
        let png = directory.appendingPathComponent("landscape.png")
        let heic = directory.appendingPathComponent("portrait.heic")
        let mov = directory.appendingPathComponent("portrait.mov")
        let mp4 = directory.appendingPathComponent("portrait.mp4")
        try writePhoto(to: jpeg, type: .jpeg, orientation: .right)
        try writePhoto(to: png, type: .png, orientation: .up)
        try writePhoto(to: heic, type: .heic, orientation: .right)
        try await writeMovie(to: mov, type: .mov)
        try await writeMovie(to: mp4, type: .mp4)

        return [jpeg, png, heic, mov, mp4]
    }

    private static func writePhoto(to url: URL, type: UTType, orientation: CGImagePropertyOrientation) throws {
        let space = try #require(CGColorSpace(name: CGColorSpace.sRGB))
        let context = try #require(CGContext(data: nil, width: 768, height: 384, bitsPerComponent: 8,
                                            bytesPerRow: 0, space: space,
                                            bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue))
        context.setFillColor(red: 0.1, green: 0.4, blue: 0.8, alpha: 1)
        context.fill(CGRect(x: 0, y: 0, width: 768, height: 384))
        context.setFillColor(red: 0.8, green: 0.3, blue: 0.1, alpha: 1)
        context.fill(CGRect(x: 0, y: 0, width: 256, height: 384))
        let image = try #require(context.makeImage())
        let destination = try #require(CGImageDestinationCreateWithURL(url as CFURL, type.identifier as CFString, 1, nil))
        CGImageDestinationAddImage(destination, image, [kCGImagePropertyOrientation: orientation.rawValue] as CFDictionary)
        try #require(CGImageDestinationFinalize(destination))
    }

    private static func writeMovie(to url: URL, type: AVFileType) async throws {
        let writer = try AVAssetWriter(outputURL: url, fileType: type)
        let input = AVAssetWriterInput(mediaType: .video, outputSettings: [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: 768,
            AVVideoHeightKey: 384,
        ])
        input.transform = CGAffineTransform(a: 0, b: 1, c: -1, d: 0, tx: 384, ty: 0)
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: input, sourcePixelBufferAttributes: [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
            kCVPixelBufferWidthKey as String: 768,
            kCVPixelBufferHeightKey as String: 384,
        ])
        try #require(writer.canAdd(input))
        writer.add(input)
        try #require(writer.startWriting())
        writer.startSession(atSourceTime: .zero)
        let pool = try #require(adaptor.pixelBufferPool)
        var storage: CVPixelBuffer?
        let status = CVPixelBufferPoolCreatePixelBuffer(kCFAllocatorDefault, pool, &storage)
        try #require(status == kCVReturnSuccess)
        let buffer = try #require(storage)
        try fillMovieFrame(buffer)
        let clock = ContinuousClock()
        let deadline = clock.now.advanced(by: .seconds(5))
        while !input.isReadyForMoreMediaData {
            try #require(writer.status == .writing && clock.now < deadline)
            try await Task.sleep(for: .milliseconds(10))
        }
        try #require(adaptor.append(buffer, withPresentationTime: .zero))
        writer.endSession(atSourceTime: CMTime(value: 1, timescale: 30))
        input.markAsFinished()
        await writer.finishWriting()
        try #require(writer.status == .completed, "Could not generate \(type.rawValue): \(String(describing: writer.error))")
    }

    private static func fillMovieFrame(_ buffer: CVPixelBuffer) throws {
        try #require(CVPixelBufferLockBaseAddress(buffer, []) == kCVReturnSuccess)
        defer { CVPixelBufferUnlockBaseAddress(buffer, []) }
        let address = try #require(CVPixelBufferGetBaseAddress(buffer))
        let space = try #require(CGColorSpace(name: CGColorSpace.sRGB))
        let context = try #require(CGContext(data: address, width: 768, height: 384, bitsPerComponent: 8,
                                            bytesPerRow: CVPixelBufferGetBytesPerRow(buffer), space: space,
                                            bitmapInfo: CGBitmapInfo.byteOrder32Little.rawValue |
                                                        CGImageAlphaInfo.premultipliedFirst.rawValue))
        context.setFillColor(red: 0.13, green: 0.61, blue: 0.4, alpha: 1)
        context.fill(CGRect(x: 0, y: 0, width: 768, height: 384))
    }
}
