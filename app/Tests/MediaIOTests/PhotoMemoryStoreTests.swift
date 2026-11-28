import BirthdayCore
import CoreGraphics
import Foundation
import ImageIO
import MediaIO
import Testing
import UniformTypeIdentifiers

@Suite
struct PhotoMemoryStoreTests {
    @Test
    func publishesReopensUpdatesAndPreservesPreviousIndexOnReadOnlyFailure() async throws {
        let root = try makeDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let mediaDir = root.appendingPathComponent("Media", isDirectory: true)
        let indexDir = root.appendingPathComponent("Memories", isDirectory: true)
        let projectsDir = root.appendingPathComponent("Projects", isDirectory: true)
        try FileManager.default.createDirectory(at: projectsDir, withIntermediateDirectories: true)

        let library = MediaLibrary(directory: mediaDir)
        let store = PhotoMemoryStore(directory: indexDir, library: library)

        let projectA = try writeFakeProject(named: "a.comp", in: projectsDir)
        let projectB = try writeFakeProject(named: "b.comp", in: projectsDir)
        let idA = ProjectID()
        let idB = ProjectID()
        let t1 = Date(timeIntervalSince1970: 1_795_000_000)
        let t2 = Date(timeIntervalSince1970: 1_795_000_120)
        let t3 = Date(timeIntervalSince1970: 1_795_000_240)

        let pngA = try makePNGData(width: 120, height: 80, red: 0.85, green: 0.2, blue: 0.2)
        let pngB = try makePNGData(width: 80, height: 120, red: 0.2, green: 0.35, blue: 0.85)
        let pngAv2 = try makePNGData(width: 96, height: 96, red: 0.2, green: 0.75, blue: 0.3)

        _ = try await store.publish(PhotoMemoryPublication(
            projectID: idA, title: "a", projectURL: projectA, savedAt: t1,
            pixelWidth: 120, pixelHeight: 80, previewPNGData: pngA
        ))
        let afterTwo = try await store.publish(PhotoMemoryPublication(
            projectID: idB, title: "b", projectURL: projectB, savedAt: t2,
            pixelWidth: 80, pixelHeight: 120, previewPNGData: pngB
        ))
        #expect(afterTwo.entries.map(\.id) == [idB, idA])

        // Reopen with fresh store instance -> order and resolved media match.
        let reopenedStore = PhotoMemoryStore(directory: indexDir, library: MediaLibrary(directory: mediaDir))
        let loaded = try await reopenedStore.loadTimeline()
        #expect(loaded.entries.map(\.id) == [idB, idA])
        let resolved = await reopenedStore.resolve(loaded)
        #expect(resolved.count == 2)
        for item in resolved {
            if case .ready(_, let media) = item.health {
                #expect(FileManager.default.fileExists(atPath: media.sourceURL.path))
                #expect(FileManager.default.fileExists(atPath: media.thumbnailURL.path))
            } else {
                Issue.record("Expected ready memory health, got \(item.health)")
            }
        }

        // Read-only index directory causes publish to fail while preserving previous timeline intact.
        let indexFile = indexDir.appendingPathComponent("timeline.json")
        let previousBytes = try Data(contentsOf: indexFile)
        try FileManager.default.setAttributes([.posixPermissions: 0o555], ofItemAtPath: indexDir.path)
        defer { try? FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: indexDir.path) }

        let updatePub = PhotoMemoryPublication(
            projectID: idA, title: "a-v2", projectURL: projectA, savedAt: t3,
            pixelWidth: 96, pixelHeight: 96, previewPNGData: pngAv2
        )
        await #expect(throws: PhotoMemoryStoreError.writeFailed) {
            _ = try await store.publish(updatePub)
        }
        #expect(try Data(contentsOf: indexFile) == previousBytes)
        #expect(try await store.loadTimeline().entries.map(\.id) == [idB, idA])

        // Restore write permission and retry idempotently -> updates idA, moves to top, zero duplicates.
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: indexDir.path)
        let retried = try await store.publish(updatePub)
        #expect(retried.entries.count == 2)
        #expect(retried.entries.map(\.id) == [idA, idB])
        #expect(retried.entry(for: idA)?.title == "a-v2")
    }

    @Test
    func isolatesMissingUnreadableAndDamagedPreviewWhileKeepingHealthyEntries() async throws {
        let root = try makeDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let mediaDir = root.appendingPathComponent("Media", isDirectory: true)
        let indexDir = root.appendingPathComponent("Memories", isDirectory: true)
        let projectsDir = root.appendingPathComponent("Projects", isDirectory: true)
        try FileManager.default.createDirectory(at: projectsDir, withIntermediateDirectories: true)

        let library = MediaLibrary(directory: mediaDir)
        let store = PhotoMemoryStore(directory: indexDir, library: library)
        let png = try makePNGData(width: 64, height: 64, red: 0.7, green: 0.4, blue: 0.2)
        let base = Date(timeIntervalSince1970: 1_795_001_000)

        let healthyURL = try writeFakeProject(named: "healthy.comp", in: projectsDir)
        let missingURL = try writeFakeProject(named: "missing.comp", in: projectsDir)
        let lockedURL = try writeFakeProject(named: "locked.comp", in: projectsDir)
        let corruptThumbURL = try writeFakeProject(named: "corrupt-thumb.comp", in: projectsDir)

        let ids = (0..<4).map { _ in ProjectID() }
        let urls = [healthyURL, missingURL, lockedURL, corruptThumbURL]
        let titles = ["healthy", "missing", "locked", "corrupt-thumb"]
        for i in 0..<4 {
            _ = try await store.publish(PhotoMemoryPublication(
                projectID: ids[i], title: titles[i], projectURL: urls[i],
                savedAt: base.addingTimeInterval(TimeInterval(i * 10)),
                pixelWidth: 64, pixelHeight: 64, previewPNGData: png
            ))
        }

        let timeline = try await store.loadTimeline()
        // Delete missing.comp, revoke permissions on locked.comp/manifest.json, corrupt corrupt-thumb's thumbnail.
        try FileManager.default.removeItem(at: missingURL)
        let lockedManifest = lockedURL.appendingPathComponent("manifest.json")
        try FileManager.default.setAttributes([.posixPermissions: 0o000], ofItemAtPath: lockedManifest.path)
        defer { try? FileManager.default.setAttributes([.posixPermissions: 0o644], ofItemAtPath: lockedManifest.path) }

        if let corruptEntry = timeline.entry(for: ids[3]),
           let corruptMedia = try await library.load(id: corruptEntry.previewMediaID) {
            try Data("not-a-valid-png".utf8).write(to: corruptMedia.thumbnailURL, options: .atomic)
        }

        let resolved = await store.resolve(timeline)
        let byID = Dictionary(uniqueKeysWithValues: resolved.map { ($0.id, $0) })

        if case .ready = byID[ids[0]]?.health { } else { Issue.record("Expected healthy entry to stay ready") }
        if case .missingProject = byID[ids[1]]?.health { } else { Issue.record("Expected missingProject") }
        if case .unreadableProject = byID[ids[2]]?.health { } else { Issue.record("Expected unreadableProject") }
        if case .damagedPreview = byID[ids[3]]?.health { } else { Issue.record("Expected damagedPreview") }
    }

    private func makeDirectory() throws -> URL {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: false)
        return dir
    }

    private func writeFakeProject(named name: String, in directory: URL) throws -> URL {
        let pkg = directory.appendingPathComponent(name, isDirectory: true)
        try FileManager.default.createDirectory(at: pkg, withIntermediateDirectories: true)
        try Data(#"{"format":"com.compositor.project","version":22}"#.utf8)
            .write(to: pkg.appendingPathComponent("manifest.json"), options: .atomic)
        return pkg
    }

    private func makePNGData(width: Int, height: Int, red: CGFloat, green: CGFloat, blue: CGFloat) throws -> Data {
        let space = CGColorSpace(name: CGColorSpace.sRGB)!
        let context = CGContext(
            data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
            space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )!
        context.setFillColor(red: red, green: green, blue: blue, alpha: 1)
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        let image = context.makeImage()!
        let data = NSMutableData()
        let dest = CGImageDestinationCreateWithData(data, UTType.png.identifier as CFString, 1, nil)!
        CGImageDestinationAddImage(dest, image, nil)
        CGImageDestinationFinalize(dest)
        return data as Data
    }
}
