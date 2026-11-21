import AppKit
import CoreGraphics
import Foundation
import ImageIO
import MediaIO
import XCTest
@testable import IOSPS

final class AppMacTests: XCTestCase {
    func testAppHostContainsDesignSystemResources() throws {
        XCTAssertEqual(Bundle.main.bundleIdentifier, "org.iosps.birthday")
        let resources = try XCTUnwrap(
            Bundle.main.url(forResource: "IOSPSModules_DesignSystem", withExtension: "bundle")
        )
        XCTAssertNotNil(Bundle(url: resources))
    }

    @MainActor
    func testMixedMediaBatchPublishesReadableCopiesAndOrientedThumbnails() async throws {
        let directory = try makeDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let originals = try await SyntheticMediaFixtures.writeSupportedFormats(in: directory)
        let bytes = try originals.map { try Data(contentsOf: $0) }
        let unsupported = directory.appendingPathComponent("notes.txt")
        let invalid = directory.appendingPathComponent("broken.png")
        let missing = directory.appendingPathComponent("missing.heic")
        try Data("synthetic fixture".utf8).write(to: unsupported)
        try Data("invalid PNG".utf8).write(to: invalid)
        let root = directory.appendingPathComponent("library", isDirectory: true)
        let session = MediaImportSession(library: MediaLibrary(directory: root))
        let batch = [unsupported, originals[0], invalid, originals[1], missing] + Array(originals.dropFirst(2))
        let pasteboard = NSPasteboard.withUniqueName()
        defer { pasteboard.releaseGlobally() }
        XCTAssertTrue(pasteboard.writeObjects(batch.map { $0 as NSURL }))
        let droppedFiles = FinderDropTarget.DropView.fileURLs(from: pasteboard)
        XCTAssertEqual(droppedFiles, batch)

        let task = try XCTUnwrap(session.importFiles(droppedFiles))
        await task.value

        XCTAssertEqual(session.rows.map(\.filename), batch.map(\.lastPathComponent))
        let errors: [MediaImportError] = session.rows.compactMap { row in
            if case .failure(let error) = row.result { return error }
            return nil
        }
        XCTAssertEqual(errors, [.unsupportedFormat, .unreadableMedia, .unreadableFile])
        let imported = session.rows.compactMap { try? $0.result.get() }
        XCTAssertEqual(imported.count, originals.count)
        XCTAssertEqual(Set(try FileManager.default.contentsOfDirectory(atPath: root.path)),
                       Set(imported.map { $0.sourceURL.deletingLastPathComponent().lastPathComponent }))
        let reopened = MediaLibrary(directory: root)
        for (index, media) in imported.enumerated() {
            XCTAssertEqual(try Data(contentsOf: media.sourceURL), bytes[index])
            XCTAssertEqual(try Data(contentsOf: originals[index]), bytes[index])
            let restored = try await reopened.load(id: media.id)
            XCTAssertEqual(restored, media)
            let source = try XCTUnwrap(CGImageSourceCreateWithURL(media.thumbnailURL as CFURL, nil))
            let thumbnail = try XCTUnwrap(CGImageSourceCreateImageAtIndex(source, 0, nil))
            XCTAssertEqual(thumbnail.width, index == 1 ? 512 : 256)
            XCTAssertEqual(thumbnail.height, index == 1 ? 256 : 512)
            XCTAssertEqual(thumbnail.colorSpace?.name, CGColorSpace.displayP3)
        }
    }

    @MainActor
    func testCancellationKeepsPriorResultsAndAllowsRetry() async throws {
        let directory = try makeDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let originals = try await SyntheticMediaFixtures.writeSupportedFormats(in: directory)
        let session = MediaImportSession(library: MediaLibrary(directory: directory.appendingPathComponent("library")))
        let first = try XCTUnwrap(session.importFiles([originals[0]]))
        await first.value
        let firstItem = try XCTUnwrap(session.rows.first).result.get()

        XCTAssertNil(session.importFiles([]))
        let cancelled = try XCTUnwrap(session.importFiles([originals[1]]))
        XCTAssertTrue(session.isImporting)
        XCTAssertNil(session.importFiles([originals[2]]))
        session.cancel()
        await cancelled.value
        XCTAssertFalse(session.isImporting)
        XCTAssertEqual(session.rows.count, 2)
        XCTAssertEqual(session.rows[0].result, .success(firstItem))
        XCTAssertEqual(session.rows[1].result, .failure(.cancelled))

        let retry = try XCTUnwrap(session.importFiles([originals[1]]))
        await retry.value
        let retried = try XCTUnwrap(session.rows.last).result.get()
        XCTAssertEqual(retried.kind, .photo)
        XCTAssertEqual(session.rows.count, 3)
    }

    private func makeDirectory() throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: false)
        return directory
    }
}
