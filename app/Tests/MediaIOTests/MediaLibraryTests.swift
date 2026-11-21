import AVFoundation
import BirthdayCore
import CoreGraphics
import CoreMedia
import CoreVideo
import Foundation
import ImageIO
import MediaIO
import Testing
import UniformTypeIdentifiers

struct MediaLibraryTests {
    @Test func orderedBatchPreservesOriginalAndSeparatesFailures() async throws {
        let directory = try makeDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let good = directory.appendingPathComponent("good.png")
        let invalid = directory.appendingPathComponent("invalid.png")
        let unsupported = directory.appendingPathComponent("text.txt")
        let original = try examplePNG()
        try original.write(to: good)
        try Data("unreadable image".utf8).write(to: invalid)
        try Data("text".utf8).write(to: unsupported)
        let root = directory.appendingPathComponent("library", isDirectory: true)
        let library = MediaLibrary(directory: root)

        let outcomes = await library.importFiles([unsupported, good, invalid])
        try #require(outcomes.count == 3)
        if case .failure(let error) = outcomes[0] {
            #expect(error == .unsupportedFormat)
        } else {
            Issue.record("Unsupported file was accepted")
        }
        let media = try outcomes[1].get()
        if case .failure(let error) = outcomes[2] {
            #expect(error == .unreadableMedia)
        } else {
            Issue.record("Invalid image was accepted")
        }
        #expect(media.sourceURL != good)
        let importedBytes = try Data(contentsOf: media.sourceURL)
        let originalBytes = try Data(contentsOf: good)
        #expect(importedBytes == original)
        #expect(originalBytes == original)
        let published = try FileManager.default.contentsOfDirectory(atPath: root.path)
        #expect(published == [media.id.rawValue.uuidString])

        let reopened = MediaLibrary(directory: root)
        let restored = try await reopened.load(id: media.id)
        #expect(restored == media)
    }

    @Test func jpegOrientationIsAppliedToPNGThumbnail() async throws {
        let directory = try makeDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let jpeg = directory.appendingPathComponent("rotated.jpg")
        let bytes = try examplePNG()
        let source = try #require(CGImageSourceCreateWithData(bytes as CFData, nil))
        let image = try #require(CGImageSourceCreateImageAtIndex(source, 0, nil))
        let destination = try #require(CGImageDestinationCreateWithURL(jpeg as CFURL, UTType.jpeg.identifier as CFString, 1, nil))
        CGImageDestinationAddImage(destination, image, [kCGImagePropertyOrientation: 6] as CFDictionary)
        try #require(CGImageDestinationFinalize(destination))
        let library = MediaLibrary(directory: directory.appendingPathComponent("library", isDirectory: true))

        let outcomes = await library.importFiles([jpeg])
        let result = try #require(outcomes.first)
        let media = try result.get()
        let thumbnailSource = try #require(CGImageSourceCreateWithURL(media.thumbnailURL as CFURL, nil))
        let thumbnail = try #require(CGImageSourceCreateImageAtIndex(thumbnailSource, 0, nil))
        #expect(thumbnail.width < thumbnail.height)
        #expect(max(thumbnail.width, thumbnail.height) <= 512)
        #expect(thumbnail.colorSpace?.model == .rgb)
    }

    @Test func emptyBatchAndMissingMediaAreRecoverable() async throws {
        let directory = try makeDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let library = MediaLibrary(directory: directory)
        let outcomes = await library.importFiles([])
        let missing = try await library.load(id: MediaID())
        #expect(outcomes.isEmpty)
        #expect(missing == nil)
    }

    @Test func supportedFormatsPublishOrientedDisplayP3Thumbnails() async throws {
        let directory = try makeDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
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

        let files = [jpeg, png, heic, mov, mp4]
        let library = MediaLibrary(directory: directory.appendingPathComponent("library", isDirectory: true))
        let results = await library.importFiles(files)
        try #require(results.count == files.count)
        for (index, result) in results.enumerated() {
            let original = files[index]
            let item = try result.get()
            let originalBytes = try Data(contentsOf: original)
            let publishedBytes = try Data(contentsOf: item.sourceURL)
            #expect(publishedBytes == originalBytes, "Original bytes differ for \(original.pathExtension)")
            #expect(item.kind == (index < 3 ? .photo : .video))
            let source = try #require(CGImageSourceCreateWithURL(item.thumbnailURL as CFURL, nil))
            let thumbnail = try #require(CGImageSourceCreateImageAtIndex(source, 0, nil))
            let expectedWidth = index == 1 ? 512 : 256
            let expectedHeight = index == 1 ? 256 : 512
            #expect(thumbnail.width == expectedWidth && thumbnail.height == expectedHeight,
                    "Unexpected \(original.pathExtension) thumbnail size")
            #expect(thumbnail.colorSpace?.name == CGColorSpace.displayP3,
                    "Missing Display P3 profile for \(original.pathExtension)")
        }
    }

    private func writePhoto(to url: URL, type: UTType, orientation: CGImagePropertyOrientation) throws {
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

    private func writeMovie(to url: URL, type: AVFileType) async throws {
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

    private func fillMovieFrame(_ buffer: CVPixelBuffer) throws {
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

    private func makeDirectory() throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: false)
        return directory
    }

    private func examplePNG() throws -> Data {
        try #require(Data(base64Encoded: "iVBORw0KGgoAAAANSUhEUgAAAAIAAAABCAIAAAB7QOjdAAAAD0lEQVR4nGP4z8DA8J8BAAf/Af8Bf4mnAAAAAElFTkSuQmCC"))
    }
}
