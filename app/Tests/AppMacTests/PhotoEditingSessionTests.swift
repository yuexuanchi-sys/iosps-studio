import BirthdayCore
import CoreGraphics
import CryptoKit
import Foundation
import ImageIO
import UniformTypeIdentifiers
import XCTest
@testable import IOSPS

final class PhotoEditingSessionTests: XCTestCase {
    @MainActor
    func testHistorySupportsTwentyFiveUndoRedoAndClearsRedoOnNewEdit() async throws {
        let root = try makeDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let source = root.appendingPathComponent("fixture.png")
        try writeImage(to: source, width: 160, height: 120, type: .png)
        let originalDigest = SHA256.hash(data: try Data(contentsOf: source))

        let draftStore = PhotoDraftRecoveryStore(directory: root.appendingPathComponent("Drafts", isDirectory: true))
        let session = PhotoEditingSession(draftStore: draftStore)
        var emitted: [PhotoProjectSavedEvent] = []
        session.onSubstantiveProjectSaved = { emitted.append($0) }

        let imported = await session.importPhoto(from: source)
        XCTAssertTrue(imported)
        XCTAssertEqual(session.pixelWidth, 160)
        XCTAssertEqual(session.pixelHeight, 120)
        XCTAssertEqual(session.undoCount, 0)
        XCTAssertEqual(session.redoCount, 0)
        XCTAssertTrue(emitted.isEmpty)

        // Commit 25 undoable edits (23 geometry steps + 2 exposure pixel commits).
        for step in 0..<23 {
            if step % 3 == 0 {
                session.flipHorizontal()
            } else {
                session.rotateClockwise()
            }
        }
        session.beginExposureAdjustment()
        session.updateExposure(0.6)
        await session.commitActiveAdjustment()
        session.beginExposureAdjustment()
        session.updateExposure(-0.3)
        await session.commitActiveAdjustment()

        XCTAssertEqual(session.undoCount, 25)
        XCTAssertTrue(session.canUndo)
        XCTAssertFalse(session.canRedo)

        // Undo 22 steps (> 20 required) and verify history tracks each step accurately.
        for _ in 0..<22 {
            session.undo()
        }
        XCTAssertEqual(session.undoCount, 3)
        XCTAssertEqual(session.redoCount, 22)
        XCTAssertTrue(session.canUndo)
        XCTAssertTrue(session.canRedo)

        // Redo 5 steps and verify replay.
        for _ in 0..<5 {
            session.redo()
        }
        XCTAssertEqual(session.undoCount, 8)
        XCTAssertEqual(session.redoCount, 17)

        // A new edit must clear the entire redo branch.
        session.rotateClockwise()
        XCTAssertEqual(session.undoCount, 9)
        XCTAssertEqual(session.redoCount, 0)
        XCTAssertFalse(session.canRedo)

        XCTAssertTrue(emitted.isEmpty)
        XCTAssertEqual(SHA256.hash(data: try Data(contentsOf: source)), originalDigest)
    }

    @MainActor
    func testDraftRecoveryCorruptFallbackAndProjectReopenWithEXIFOrientation() async throws {
        let root = try makeDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let source = root.appendingPathComponent("oriented.jpg")
        try writeImage(to: source, width: 160, height: 120, type: .jpeg, orientation: .right)
        let originalDigest = SHA256.hash(data: try Data(contentsOf: source))

        let draftDir = root.appendingPathComponent("Drafts", isDirectory: true)
        let draftStore = PhotoDraftRecoveryStore(directory: draftDir)
        let session = PhotoEditingSession(draftStore: draftStore)
        var emitted: [PhotoProjectSavedEvent] = []
        session.onSubstantiveProjectSaved = { emitted.append($0) }

        let imported = await session.importPhoto(from: source)
        XCTAssertTrue(imported)
        // EXIF .right rotates 160x120 into 120x160.
        XCTAssertEqual(session.pixelWidth, 120)
        XCTAssertEqual(session.pixelHeight, 160)

        // Draft 1: crop to 1:1 (120x120) and persist draft.
        session.beginCrop(aspectChoice: "1:1")
        await session.commitCrop()
        XCTAssertEqual(session.pixelWidth, 120)
        XCTAssertEqual(session.pixelHeight, 120)
        let draft1Saved = await session.saveDraftNow()
        XCTAssertTrue(draft1Saved)

        // Draft 2: crop to 2:1 (120x60) and persist draft (Draft 1 shifts to backup slot).
        session.beginCrop(aspectChoice: "2:1")
        await session.commitCrop()
        XCTAssertEqual(session.pixelWidth, 120)
        XCTAssertEqual(session.pixelHeight, 60)
        let draft2Saved = await session.saveDraftNow()
        XCTAssertTrue(draft2Saved)
        XCTAssertTrue(emitted.isEmpty)

        // Fresh session restores Draft 2 (latest valid draft) without notifying memories.
        let restored = PhotoEditingSession(draftStore: draftStore)
        var restoredEvents: [PhotoProjectSavedEvent] = []
        restored.onSubstantiveProjectSaved = { restoredEvents.append($0) }
        let didRestoreLatest = await restored.restoreLatestValidDraft()
        XCTAssertTrue(didRestoreLatest)
        XCTAssertTrue(restored.restoredFromDraft)
        XCTAssertEqual(restored.pixelWidth, 120)
        XCTAssertEqual(restored.pixelHeight, 60)
        XCTAssertTrue(restoredEvents.isEmpty)

        // Corrupt latest draft manifest -> fresh session falls back to valid backup (Draft 1: 120x120).
        let latestManifest = draftDir.appendingPathComponent("latest/draft.comp/manifest.json")
        try Data("corrupted-json".utf8).write(to: latestManifest, options: .atomic)
        let fallback = PhotoEditingSession(draftStore: draftStore)
        let didFallback = await fallback.restoreLatestValidDraft()
        XCTAssertTrue(didFallback)
        XCTAssertTrue(fallback.restoredFromDraft)
        XCTAssertEqual(fallback.pixelWidth, 120)
        XCTAssertEqual(fallback.pixelHeight, 120)

        // Saving restored draft persists valid project package that reopens with identical ProjectID.
        let savedURL = root.appendingPathComponent("recovered.comp", isDirectory: true)
        let saved = await fallback.saveProject(to: savedURL)
        XCTAssertTrue(saved)
        let savedRef = try XCTUnwrap(fallback.currentProjectReference)
        XCTAssertEqual(fallback.savedEvents.count, 1)

        let reopened = PhotoEditingSession(draftStore: PhotoDraftRecoveryStore(directory: root.appendingPathComponent("Drafts2", isDirectory: true)))
        let didOpen = await reopened.openProject(reference: savedRef)
        XCTAssertTrue(didOpen)
        XCTAssertEqual(reopened.currentProjectReference?.projectID, savedRef.projectID)
        XCTAssertEqual(reopened.pixelWidth, 120)
        XCTAssertEqual(reopened.pixelHeight, 120)
        XCTAssertTrue(reopened.savedEvents.isEmpty)
        XCTAssertEqual(SHA256.hash(data: try Data(contentsOf: source)), originalDigest)
    }

    @MainActor
    func testSubstantiveSaveCallbackMatrixAndReadOnlyFailureProtection() async throws {
        let root = try makeDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let outputs = root.appendingPathComponent("Outputs", isDirectory: true)
        try FileManager.default.createDirectory(at: outputs, withIntermediateDirectories: false)

        let source = root.appendingPathComponent("photo.png")
        try writeImage(to: source, width: 160, height: 120, type: .png)
        let originalDigest = SHA256.hash(data: try Data(contentsOf: source))

        var tick = 0
        let fixedStart = Date(timeIntervalSince1970: 1_795_000_000)
        let session = PhotoEditingSession(
            draftStore: PhotoDraftRecoveryStore(directory: root.appendingPathComponent("Drafts", isDirectory: true)),
            clock: {
                tick += 1
                return fixedStart.addingTimeInterval(TimeInterval(tick * 10))
            }
        )
        var events: [PhotoProjectSavedEvent] = []
        session.onSubstantiveProjectSaved = { events.append($0) }

        // 1. Import only -> no notification.
        let imported = await session.importPhoto(from: source)
        XCTAssertTrue(imported)
        XCTAssertEqual(events.count, 0)

        // 2. Save without any substantive edit -> writes file, NO notification.
        let uneditedProject = outputs.appendingPathComponent("unedited.comp", isDirectory: true)
        let savedUnedited = await session.saveProject(to: uneditedProject)
        XCTAssertTrue(savedUnedited)
        XCTAssertEqual(events.count, 0)

        // 3. Auto-draft save -> NO notification.
        let drafted = await session.saveDraftNow()
        XCTAssertTrue(drafted)
        XCTAssertEqual(events.count, 0)

        // 4. Standalone PNG & JPEG exports -> verify dimensions, sRGB, alpha, and NO notification.
        let exportedPNG = outputs.appendingPathComponent("standalone.png")
        let exportedJPG = outputs.appendingPathComponent("standalone.jpg")
        let pngOK = await session.exportImage(format: .png, to: exportedPNG)
        let jpgOK = await session.exportImage(format: .jpeg, to: exportedJPG)
        XCTAssertTrue(pngOK)
        XCTAssertTrue(jpgOK)
        XCTAssertEqual(events.count, 0)
        let pngImg = try decodeImage(at: exportedPNG)
        let jpgImg = try decodeImage(at: exportedJPG)
        XCTAssertEqual(pngImg.width, 160)
        XCTAssertEqual(pngImg.height, 120)
        XCTAssertEqual(jpgImg.width, 160)
        XCTAssertEqual(jpgImg.height, 120)
        XCTAssertEqual(pngImg.colorSpace?.name, CGColorSpace.sRGB)
        XCTAssertEqual(jpgImg.colorSpace?.name, CGColorSpace.sRGB)
        XCTAssertTrue([.first, .last, .premultipliedFirst, .premultipliedLast].contains(pngImg.alphaInfo))
        XCTAssertTrue([.none, .noneSkipFirst, .noneSkipLast].contains(jpgImg.alphaInfo))

        // Exporting over the source original must be rejected to keep originals read-only.
        let overwriteOriginal = await session.exportImage(format: .png, to: source)
        XCTAssertFalse(overwriteOriginal)
        XCTAssertEqual(SHA256.hash(data: try Data(contentsOf: source)), originalDigest)

        // 5. Substantive edit (2:1 crop + 90 deg rotate -> 80x160) + Save -> triggers Event #1!
        session.beginCrop(aspectChoice: "2:1")
        await session.commitCrop()
        session.rotateClockwise()
        XCTAssertEqual(session.pixelWidth, 80)
        XCTAssertEqual(session.pixelHeight, 160)
        let projectA = outputs.appendingPathComponent("project-a.comp", isDirectory: true)
        let savedA = await session.saveProject(to: projectA)
        XCTAssertTrue(savedA)
        XCTAssertEqual(events.count, 1)
        XCTAssertEqual(events[0].reference.fileURL, projectA)
        XCTAssertEqual(events[0].pixelWidth, 80)
        XCTAssertEqual(events[0].pixelHeight, 160)
        XCTAssertFalse(events[0].previewPNGData.isEmpty)
        XCTAssertFalse(events[0].isSavedAsNew)

        // 6. Repeat save with no new edits -> NO notification.
        let repeatSave = await session.saveProject()
        XCTAssertTrue(repeatSave)
        XCTAssertEqual(events.count, 1)

        // 7. Edit then undo back to saved state, then save -> NO notification.
        session.rotateClockwise()
        session.undo()
        let undoneSave = await session.saveProject()
        XCTAssertTrue(undoneSave)
        XCTAssertEqual(events.count, 1)

        // 8. Substantive edit + failed save in read-only directory -> NO notification, previous file intact.
        session.beginExposureAdjustment()
        session.updateExposure(1.0)
        await session.commitActiveAdjustment()
        let projectABeforeFailure = try Data(contentsOf: projectA.appendingPathComponent("manifest.json"))
        try FileManager.default.setAttributes([.posixPermissions: 0o555], ofItemAtPath: outputs.path)
        defer { try? FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: outputs.path) }
        let failedSave = await session.saveProject()
        XCTAssertFalse(failedSave)
        XCTAssertNotNil(session.errorMessage)
        XCTAssertEqual(events.count, 1)
        XCTAssertEqual(try Data(contentsOf: projectA.appendingPathComponent("manifest.json")), projectABeforeFailure)

        // 9. Restore permissions & retry save -> triggers Event #2 with SAME ProjectID.
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: outputs.path)
        let retriedSave = await session.saveProject()
        XCTAssertTrue(retriedSave)
        XCTAssertEqual(events.count, 2)
        XCTAssertEqual(events[1].reference.projectID, events[0].reference.projectID)
        XCTAssertGreaterThan(events[1].savedAt, events[0].savedAt)

        // 10. Save As independent project -> triggers Event #3 with a brand-new ProjectID.
        let projectB = outputs.appendingPathComponent("project-b.comp", isDirectory: true)
        let savedAsB = await session.saveProject(to: projectB, asNew: true)
        XCTAssertTrue(savedAsB)
        XCTAssertEqual(events.count, 3)
        XCTAssertNotEqual(events[2].reference.projectID, events[0].reference.projectID)
        XCTAssertEqual(events[2].reference.fileURL, projectB)
        XCTAssertTrue(events[2].isSavedAsNew)

        // 11. Fresh session opens project-a (browse only -> 0 events, repeat save -> 0 events, edit+save -> 1 event with project-a ID).
        let reopened = PhotoEditingSession(draftStore: PhotoDraftRecoveryStore(directory: root.appendingPathComponent("Drafts2", isDirectory: true)))
        var reopenedEvents: [PhotoProjectSavedEvent] = []
        reopened.onSubstantiveProjectSaved = { reopenedEvents.append($0) }
        let openedA = await reopened.openProject(at: projectA)
        XCTAssertTrue(openedA)
        XCTAssertEqual(reopenedEvents.count, 0)
        let noChangeSave = await reopened.saveProject()
        XCTAssertTrue(noChangeSave)
        XCTAssertEqual(reopenedEvents.count, 0)
        reopened.rotateClockwise()
        let updatedSave = await reopened.saveProject()
        XCTAssertTrue(updatedSave)
        XCTAssertEqual(reopenedEvents.count, 1)
        XCTAssertEqual(reopenedEvents[0].reference.projectID, events[0].reference.projectID)
        XCTAssertEqual(SHA256.hash(data: try Data(contentsOf: source)), originalDigest)
    }

    private func makeDirectory() throws -> URL {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: false)
        return directory
    }

    private func writeImage(
        to url: URL,
        width: Int,
        height: Int,
        type: UTType,
        orientation: CGImagePropertyOrientation? = nil
    ) throws {
        let space = try XCTUnwrap(CGColorSpace(name: CGColorSpace.sRGB))
        let alpha: CGImageAlphaInfo = type == .png ? .premultipliedLast : .noneSkipLast
        let context = try XCTUnwrap(CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: space,
            bitmapInfo: alpha.rawValue
        ))
        if type == .png {
            context.clear(CGRect(x: 0, y: 0, width: width, height: height))
        } else {
            context.setFillColor(red: 0.94, green: 0.90, blue: 0.84, alpha: 1)
            context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        }
        context.setFillColor(red: 0.22, green: 0.45, blue: 0.78, alpha: 1)
        context.fill(CGRect(x: 10, y: 10, width: width - 20, height: height - 20))
        context.setFillColor(red: 0.85, green: 0.34, blue: 0.22, alpha: 1)
        context.fill(CGRect(x: width / 2, y: 16, width: width / 3, height: height / 3))
        let image = try XCTUnwrap(context.makeImage())
        let destination = try XCTUnwrap(CGImageDestinationCreateWithURL(url as CFURL, type.identifier as CFString, 1, nil))
        let properties = orientation.map { [kCGImagePropertyOrientation: $0.rawValue] as CFDictionary }
        CGImageDestinationAddImage(destination, image, properties)
        XCTAssertTrue(CGImageDestinationFinalize(destination))
    }

    private func decodeImage(at url: URL) throws -> CGImage {
        let source = try XCTUnwrap(CGImageSourceCreateWithURL(url as CFURL, nil))
        return try XCTUnwrap(CGImageSourceCreateImageAtIndex(source, 0, nil))
    }
}
