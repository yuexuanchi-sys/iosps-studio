import AVFoundation
import BirthdayCore
import Foundation
import MediaIO
import TimelineKit
import XCTest
@testable import IOSPS

final class VideoEditingSessionTests: XCTestCase {
    @MainActor
    func testMixedImportEditsAndLegacyProjectRecovery() async throws {
        let root = try makeDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let library = MediaLibrary(directory: root.appendingPathComponent("Media"))
        let drafts = FileDraftStore(directory: root.appendingPathComponent("Drafts"))
        let session = VideoEditingSession(library: library, drafts: drafts)
        let urls = try fixtures()
        let originalBytes = try urls.map { try Data(contentsOf: $0) }
        let corrupt = root.appendingPathComponent("corrupt.mov")
        try Data("Synthetic unreadable MOV".utf8).write(to: corrupt)
        let missing = root.appendingPathComponent("missing.mp4")
        let imported = try XCTUnwrap(session.importVideos([urls[0], corrupt, missing, urls[1]]))
        await imported.value
        XCTAssertEqual(session.importIssues.map(\.name), ["corrupt.mov", "missing.mp4"])
        XCTAssertEqual(session.timeline.clips.map(\.frameCount), [60, 60])
        for (index, clip) in session.timeline.clips.enumerated() {
            let item = try await library.load(id: clip.media)
            let local = try XCTUnwrap(item)
            XCTAssertNotEqual(local.sourceURL, urls[index])
            XCTAssertEqual(try Data(contentsOf: local.sourceURL), originalBytes[index])
        }
        XCTAssertEqual(try urls.map { try Data(contentsOf: $0) }, originalBytes)

        let originals = session.timeline.clips.map(\.media)
        session.apply(.split(clip: 0, at: 30))
        XCTAssertEqual(session.timeline.clips.map(\.frameCount), [30, 30, 60])
        session.undo()
        XCTAssertEqual(session.timeline.clips.map(\.frameCount), [60, 60])
        session.redo()
        XCTAssertEqual(session.timeline.clips.map(\.frameCount), [30, 30, 60])
        session.apply(.delete(clip: 1))
        session.apply(.trim(clip: 1, from: 30, to: 60))
        session.apply(.move(from: 1, to: 0))
        XCTAssertEqual(session.timeline.clips.map(\.media), originals.reversed().map { $0 })
        XCTAssertEqual(session.timeline.clips.map(\.startFrame), [30, 0])

        let legacy = root.appendingPathComponent("legacy.json")
        try await drafts.saveProject(Project(content: .video(VideoProject(sources: originals))), at: legacy)
        let legacyOpen = try XCTUnwrap(session.open(at: legacy))
        await legacyOpen.value
        XCTAssertEqual(session.timeline.clips.map(\.media), originals)
        XCTAssertEqual(session.timeline.clips.map(\.frameCount), [60, 60])

        let corruptProject = root.appendingPathComponent("corrupt.json")
        try Data("invalid".utf8).write(to: corruptProject)
        let beforeFailure = session.timeline
        let invalidOpen = try XCTUnwrap(session.open(at: corruptProject))
        await invalidOpen.value
        XCTAssertEqual(session.timeline, beforeFailure)
    }

    @MainActor
    func testSaveAndExportPreservePreviousFilesOnFailureAndCancellation() async throws {
        let root = try makeDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let library = MediaLibrary(directory: root.appendingPathComponent("Media"))
        let drafts = FileDraftStore(directory: root.appendingPathComponent("Drafts"))
        let session = VideoEditingSession(library: library, drafts: drafts)
        let imported = try XCTUnwrap(session.importVideos(try fixtures()))
        await imported.value
        session.apply(.trim(clip: 0, from: 0, to: 30))
        session.apply(.trim(clip: 1, from: 30, to: 60))
        session.apply(.move(from: 1, to: 0))
        let successfulTimeline = session.timeline

        let outputs = root.appendingPathComponent("Outputs")
        try FileManager.default.createDirectory(at: outputs, withIntermediateDirectories: false)
        let project = outputs.appendingPathComponent("editor.json")
        let output = outputs.appendingPathComponent("editor.mp4")
        let saved = try XCTUnwrap(session.save(at: project))
        await saved.value
        let bytes = try Data(contentsOf: project)

        let started = try XCTUnwrap(session.preview())
        await started.value
        let item = try XCTUnwrap(session.player.currentItem)
        let previewDuration = try await item.asset.load(.duration)
        XCTAssertEqual(previewDuration.seconds, 2, accuracy: 1.0 / 30)
        session.pausePreview()

        let firstExport = try XCTUnwrap(session.export(at: output))
        await firstExport.value
        let firstBytes = try Data(contentsOf: output)
        let cancelled = try XCTUnwrap(session.export(at: output))
        session.cancelExport()
        await cancelled.value
        XCTAssertEqual(try Data(contentsOf: output), firstBytes)

        session.apply(.move(from: 0, to: 1))
        try FileManager.default.setAttributes([.posixPermissions: 0o555], ofItemAtPath: outputs.path)
        defer { try? FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: outputs.path) }
        let failedSave = try XCTUnwrap(session.save(at: project))
        await failedSave.value
        XCTAssertTrue(session.hasUnsavedEdits)
        XCTAssertEqual(try Data(contentsOf: project), bytes)
        let failedExport = try XCTUnwrap(session.export(at: output))
        await failedExport.value
        XCTAssertEqual(try Data(contentsOf: output), firstBytes)

        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: outputs.path)
        let opened = try XCTUnwrap(session.open(at: project))
        await opened.value
        XCTAssertEqual(session.timeline, successfulTimeline)
        let retry = try XCTUnwrap(session.export(at: output))
        await retry.value
        let asset = AVURLAsset(url: output)
        let duration = try await asset.load(.duration)
        let video = try await asset.loadTracks(withMediaType: .video)
        let audio = try await asset.loadTracks(withMediaType: .audio)
        XCTAssertEqual(duration.seconds, 2, accuracy: 1.0 / 30)
        XCTAssertEqual(video.count, 1)
        XCTAssertEqual(audio.count, 1)
        XCTAssertFalse(try FileManager.default.contentsOfDirectory(atPath: outputs.path).contains { $0.hasSuffix(".part") })
    }

    private func makeDirectory() throws -> URL {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: false)
        return directory
    }

    private func fixtures() throws -> [URL] {
        let bundle = Bundle(for: Self.self)
        return try [("source-a", "mov"), ("source-b", "mp4")].map { name, ext in
            try XCTUnwrap(bundle.url(forResource: name, withExtension: ext, subdirectory: "VideoEditorFixtures"))
        }
    }
}
