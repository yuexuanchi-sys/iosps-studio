import BirthdayCore
import CoreGraphics
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
