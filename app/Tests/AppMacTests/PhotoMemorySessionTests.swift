import BirthdayCore
import CoreGraphics
import Foundation
import ImageIO
import MediaIO
import UniformTypeIdentifiers
import XCTest
@testable import IOSPS

@MainActor
private final class ControlledClock {
    private var current: Date
    init(_ start: Date) { self.current = start }
    func set(_ date: Date) { current = date }
    func advance(by seconds: TimeInterval) { current = current.addingTimeInterval(seconds) }
    func now() -> Date { current }
}

final class PhotoMemorySessionTests: XCTestCase {
    @MainActor
    func testEndToEndSaveOrderRestartUpdateSaveAsAndTieBreak() async throws {
        let root = try makeDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let mediaDir = root.appendingPathComponent("Media", isDirectory: true)
        let memoriesDir = root.appendingPathComponent("PhotoMemories", isDirectory: true)
        let draftsDir = root.appendingPathComponent("PhotoDrafts", isDirectory: true)
        let projectsDir = root.appendingPathComponent("Projects", isDirectory: true)
        try FileManager.default.createDirectory(at: projectsDir, withIntermediateDirectories: true)

        let photoA = root.appendingPathComponent("photo-a.png")
        let photoB = root.appendingPathComponent("photo-b.png")
        try writePNG(to: photoA, width: 160, height: 120, color: (0.85, 0.2, 0.2))
        try writePNG(to: photoB, width: 160, height: 120, color: (0.2, 0.35, 0.85))

        let clock = ControlledClock(Date(timeIntervalSince1970: 1_795_100_000))
        let library = MediaLibrary(directory: mediaDir)
        let store = PhotoMemoryStore(directory: memoriesDir, library: library)
        let memories = PhotoMemorySession(store: store)
        let editor = PhotoEditingSession(draftStore: PhotoDraftRecoveryStore(directory: draftsDir), clock: { clock.now() })
        editor.onSubstantiveProjectSaved = { event in _ = memories.handleProjectSaved(event) }

        // Save Photo A (2:1 crop -> 160x80).
        let importedA = await editor.importPhoto(from: photoA)
        XCTAssertTrue(importedA)
        editor.beginCrop(aspectChoice: "2:1")
        await editor.commitCrop()
        let compA = projectsDir.appendingPathComponent("work-a.comp", isDirectory: true)
        let savedA = await editor.saveProject(to: compA)
        XCTAssertTrue(savedA)
        await memories.waitForInFlightPublications()
        let idA = try XCTUnwrap(editor.currentProjectReference?.projectID)

        // Save Photo B later (1:1 crop -> 120x120).
        clock.advance(by: 60)
        let importedB = await editor.importPhoto(from: photoB)
        XCTAssertTrue(importedB)
        editor.beginCrop(aspectChoice: "1:1")
        await editor.commitCrop()
        let compB = projectsDir.appendingPathComponent("work-b.comp", isDirectory: true)
        let savedB = await editor.saveProject(to: compB)
        XCTAssertTrue(savedB)
        await memories.waitForInFlightPublications()
        let idB = try XCTUnwrap(editor.currentProjectReference?.projectID)

        XCTAssertEqual(memories.items.map(\.id), [idB, idA])

        // Simulate app restart with fresh sessions -> order preserved and clicking reopens exact project.
        let restartedMemories = PhotoMemorySession(store: PhotoMemoryStore(directory: memoriesDir, library: MediaLibrary(directory: mediaDir)))
        await restartedMemories.reload()
        XCTAssertEqual(restartedMemories.items.map(\.id), [idB, idA])

        let restartedEditor = PhotoEditingSession(
            draftStore: PhotoDraftRecoveryStore(directory: root.appendingPathComponent("DraftsRestart", isDirectory: true)),
            clock: { clock.now() }
        )
        restartedEditor.onSubstantiveProjectSaved = { event in _ = restartedMemories.handleProjectSaved(event) }
        let entryA = try XCTUnwrap(restartedMemories.items.first { $0.id == idA })
        let reopenedA = await restartedEditor.openProject(reference: PhotoProjectReference(projectID: entryA.id, fileURL: entryA.projectURL))
        XCTAssertTrue(reopenedA)
        XCTAssertEqual(restartedEditor.pixelWidth, 160)
        XCTAssertEqual(restartedEditor.pixelHeight, 80)

        // Re-edit A (rotate 90 -> 80x160) and save -> updates preview & timestamp, moves A above B with NO duplicate.
        clock.advance(by: 120)
        restartedEditor.rotateClockwise()
        let resavedA = await restartedEditor.saveProject()
        XCTAssertTrue(resavedA)
        await restartedMemories.waitForInFlightPublications()
        XCTAssertEqual(restartedMemories.items.count, 2)
        XCTAssertEqual(restartedMemories.items.map(\.id), [idA, idB])
        XCTAssertEqual(restartedMemories.items[0].entry.pixelWidth, 80)
        XCTAssertEqual(restartedMemories.items[0].entry.pixelHeight, 160)

        // Save As independent project at the EXACT SAME timestamp -> creates 3rd entry sorted deterministically by ProjectID.
        let compC = projectsDir.appendingPathComponent("work-c.comp", isDirectory: true)
        let savedAsC = await restartedEditor.saveProject(to: compC, asNew: true)
        XCTAssertTrue(savedAsC)
        await restartedMemories.waitForInFlightPublications()
        let idC = try XCTUnwrap(restartedEditor.currentProjectReference?.projectID)
        XCTAssertNotEqual(idC, idA)
        XCTAssertEqual(restartedMemories.items.count, 3)
        let topTwo = Array(restartedMemories.items.prefix(2)).map(\.id)
        let expectedTopTwo = [idA, idC].sorted { $0.rawValue.uuidString < $1.rawValue.uuidString }
        XCTAssertEqual(topTwo, expectedTopTwo)
        XCTAssertEqual(restartedMemories.items[2].id, idB)
    }

    @MainActor
    func testNonSubstantiveActionsKeepTimelineIntactAndMovieHandoffUsesSavedVersion() async throws {
        let root = try makeDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let mediaDir = root.appendingPathComponent("Media", isDirectory: true)
        let memoriesDir = root.appendingPathComponent("PhotoMemories", isDirectory: true)
        let projectsDir = root.appendingPathComponent("Projects", isDirectory: true)
        try FileManager.default.createDirectory(at: projectsDir, withIntermediateDirectories: true)

        let source = root.appendingPathComponent("original.png")
        try writePNG(to: source, width: 200, height: 120, color: (0.2, 0.65, 0.35))

        let clock = ControlledClock(Date(timeIntervalSince1970: 1_795_200_000))
        let library = MediaLibrary(directory: mediaDir)
        let store = PhotoMemoryStore(directory: memoriesDir, library: library)
        let memories = PhotoMemorySession(store: store)
        let editor = PhotoEditingSession(
            draftStore: PhotoDraftRecoveryStore(directory: root.appendingPathComponent("Drafts", isDirectory: true)),
            clock: { clock.now() }
        )
        editor.onSubstantiveProjectSaved = { event in _ = memories.handleProjectSaved(event) }

        // 1. Import only, save without edit, auto-draft, standalone export -> timeline stays empty.
        let importedSource = await editor.importPhoto(from: source)
        XCTAssertTrue(importedSource)
        let savedRaw = await editor.saveProject(to: projectsDir.appendingPathComponent("raw.comp", isDirectory: true))
        XCTAssertTrue(savedRaw)
        let savedDraft = await editor.saveDraftNow()
        XCTAssertTrue(savedDraft)
        let exportedPNG = await editor.exportImage(format: .png, to: root.appendingPathComponent("out.png"))
        XCTAssertTrue(exportedPNG)
        let exportedJPEG = await editor.exportImage(format: .jpeg, to: root.appendingPathComponent("out.jpg"))
        XCTAssertTrue(exportedJPEG)
        await memories.waitForInFlightPublications()
        XCTAssertTrue(memories.items.isEmpty)

        // 2. Substantive edit (1:1 crop -> 120x120) + save -> 1 entry.
        editor.beginCrop(aspectChoice: "1:1")
        await editor.commitCrop()
        let savedURL = projectsDir.appendingPathComponent("cropped.comp", isDirectory: true)
        let savedCropped = await editor.saveProject(to: savedURL)
        XCTAssertTrue(savedCropped)
        await memories.waitForInFlightPublications()
        XCTAssertEqual(memories.items.count, 1)
        let baselineEntry = memories.items[0].entry

        // 3. Repeat save, unsaved edit, undo-back save -> entry & timestamp unchanged.
        clock.advance(by: 30)
        let repeatSaved = await editor.saveProject()
        XCTAssertTrue(repeatSaved)
        editor.rotateClockwise()
        await memories.waitForInFlightPublications()
        XCTAssertEqual(memories.items.count, 1)
        XCTAssertEqual(memories.items[0].entry, baselineEntry)
        editor.undo()
        let undoSaved = await editor.saveProject()
        XCTAssertTrue(undoSaved)
        await memories.waitForInFlightPublications()
        XCTAssertEqual(memories.items.count, 1)
        XCTAssertEqual(memories.items[0].entry, baselineEntry)

        // 4. Read-only index directory -> previous list stays intact and retry updates cleanly without duplicates.
        clock.advance(by: 60)
        editor.beginCrop(aspectChoice: "2:1")
        await editor.commitCrop() // 120x60
        try FileManager.default.setAttributes([.posixPermissions: 0o555], ofItemAtPath: memoriesDir.path)
        defer { try? FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: memoriesDir.path) }
        let savedWhileReadOnly = await editor.saveProject()
        XCTAssertTrue(savedWhileReadOnly)
        await memories.waitForInFlightPublications()
        XCTAssertTrue(memories.hasPendingRetries)
        XCTAssertEqual(memories.items.count, 1)
        XCTAssertEqual(memories.items[0].entry, baselineEntry)

        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: memoriesDir.path)
        let retrySucceeded = await memories.retryPendingPublications()
        XCTAssertTrue(retrySucceeded)
        XCTAssertFalse(memories.hasPendingRetries)
        XCTAssertEqual(memories.items.count, 1)
        XCTAssertEqual(memories.items[0].entry.pixelWidth, 120)
        XCTAssertEqual(memories.items[0].entry.pixelHeight, 60)

        // 5. Handoff to PhotoMovieSession resolves the SAVED edited version (120x60, not original 200x120).
        let movieMedia = try XCTUnwrap(memories.items[0].movieMedia)
        let movieSession = PhotoMovieSession(library: library, previewDirectory: root.appendingPathComponent("MoviePreview"))
        XCTAssertTrue(movieSession.addPreparedPhoto(movieMedia, name: memories.items[0].entry.title))
        XCTAssertEqual(movieSession.photos.count, 1)
        let handedOffURL = movieSession.photos[0].sourceURL
        let imgSource = try XCTUnwrap(CGImageSourceCreateWithURL(handedOffURL as CFURL, nil))
        let img = try XCTUnwrap(CGImageSourceCreateImageAtIndex(imgSource, 0, nil))
        XCTAssertEqual(img.width, 120)
        XCTAssertEqual(img.height, 60)
    }

    private func makeDirectory() throws -> URL {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: false)
        return dir
    }

    private func writePNG(to url: URL, width: Int, height: Int, color: (CGFloat, CGFloat, CGFloat)) throws {
        let space = try XCTUnwrap(CGColorSpace(name: CGColorSpace.sRGB))
        let context = try XCTUnwrap(CGContext(
            data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
            space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ))
        context.setFillColor(red: color.0, green: color.1, blue: color.2, alpha: 1)
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        let image = try XCTUnwrap(context.makeImage())
        let dest = try XCTUnwrap(CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil))
        CGImageDestinationAddImage(dest, image, nil)
        XCTAssertTrue(CGImageDestinationFinalize(dest))
    }
}
