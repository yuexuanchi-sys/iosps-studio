import AVFoundation
import BirthdayCore
import CoreGraphics
import Foundation
import ImageIO
import MediaIO
import UniformTypeIdentifiers
import XCTest
@testable import IOSPS

final class PhotoMovieSessionTests: XCTestCase {
    @MainActor
    func testMixedPhotoImportReorderRemoveAndTemplateSwitchPreservesPhotosAndOriginals() async throws {
        let root = try makeDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let library = MediaLibrary(directory: root.appendingPathComponent("Media"))
        let session = PhotoMovieSession(library: library, previewDirectory: root.appendingPathComponent("Preview"))

        let p1 = root.appendingPathComponent("p1.jpg")
        let p2 = root.appendingPathComponent("p2.jpg")
        let corrupt = root.appendingPathComponent("corrupt.jpg")
        let missing = root.appendingPathComponent("missing.jpg")
        let clip = root.appendingPathComponent("clip.mov")
        try writePhoto(to: p1, background: (0.85, 0.15, 0.15))
        try writePhoto(to: p2, background: (0.15, 0.35, 0.85))
        try Data("Synthetic invalid photo".utf8).write(to: corrupt)
        let fixtureVideo = try XCTUnwrap(Bundle(for: Self.self).url(
            forResource: "source-a", withExtension: "mov", subdirectory: "VideoEditorFixtures"
        ))
        try FileManager.default.copyItem(at: fixtureVideo, to: clip)
        let originalBytes = try [p1, p2].map { try Data(contentsOf: $0) }

        let imported = try XCTUnwrap(session.importPhotos([p1, corrupt, missing, clip, p2]))
        await imported.value

        XCTAssertEqual(session.photos.map(\.name), ["p1.jpg", "p2.jpg"])
        XCTAssertEqual(session.importIssues.map(\.name), ["corrupt.jpg", "missing.jpg", "clip.mov"])
        for (index, item) in session.photos.enumerated() {
            let loaded = try await library.load(id: item.id)
            let local = try XCTUnwrap(loaded)
            XCTAssertNotEqual(local.sourceURL, [p1, p2][index])
            XCTAssertEqual(try Data(contentsOf: local.sourceURL), originalBytes[index])
        }
        XCTAssertEqual(try [p1, p2].map { try Data(contentsOf: $0) }, originalBytes)

        XCTAssertEqual(session.catalog.count, 8)
        XCTAssertEqual(session.selectedTemplateID, "warm-keepsake")
        XCTAssertEqual(session.estimatedDurationFrames, 78)

        session.movePhoto(from: 1, by: -1)
        XCTAssertEqual(session.photos.map(\.name), ["p2.jpg", "p1.jpg"])

        session.selectTemplate(id: "sunny-journey")
        XCTAssertEqual(session.photos.map(\.name), ["p2.jpg", "p1.jpg"])
        XCTAssertEqual(session.estimatedDurationFrames, 52)

        session.selectTemplate(id: "starry-night")
        XCTAssertEqual(session.photos.map(\.name), ["p2.jpg", "p1.jpg"])
        XCTAssertEqual(session.estimatedDurationFrames, 102)

        session.removePhoto(at: 0)
        XCTAssertEqual(session.photos.map(\.name), ["p1.jpg"])
        XCTAssertEqual(session.estimatedDurationFrames, 60)
    }

    @MainActor
    func testBuiltInCatalogResolvesAllEightTemplatesAndBundledMusic() async throws {
        let root = try makeDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let library = MediaLibrary(directory: root.appendingPathComponent("Media"))
        let session = PhotoMovieSession(library: library, previewDirectory: root.appendingPathComponent("Preview"))

        XCTAssertEqual(session.catalog.count, 8)
        XCTAssertEqual(session.musicMode, .templateDefault)
        XCTAssertTrue(session.activeMusicDisplayName.contains("温暖钢琴"), session.activeMusicDisplayName)

        for descriptor in session.catalog {
            let spec = try XCTUnwrap(descriptor.template.music)
            let resolved = try XCTUnwrap(session.resolvedMusic(for: descriptor.template))
            XCTAssertTrue(FileManager.default.fileExists(atPath: resolved.url.path))
            let asset = AVURLAsset(url: resolved.url)
            let duration = try await asset.load(.duration)
            let audioTracks = try await asset.loadTracks(withMediaType: .audio)
            XCTAssertEqual(audioTracks.count, 1)
            let requiredSeconds = Double(spec.startFrame + spec.frames) / Double(VideoTiming.framesPerSecond)
            XCTAssertGreaterThanOrEqual(duration.seconds, requiredSeconds)
        }

        let p1 = root.appendingPathComponent("candle-a.jpg")
        let p2 = root.appendingPathComponent("candle-b.jpg")
        try writePhoto(to: p1, background: (0.14, 0.22, 0.52))
        try writePhoto(to: p2, background: (0.58, 0.22, 0.16))
        let imported = try XCTUnwrap(session.importPhotos([p1, p2]))
        await imported.value

        session.selectTemplate(id: "birthday-candle")
        XCTAssertTrue(session.activeMusicDisplayName.contains("晶莹八音盒"), session.activeMusicDisplayName)
        session.setOpeningCaption("祝你生日快乐")

        session.muteMusic()
        XCTAssertEqual(session.musicMode, .muted)
        XCTAssertNil(session.resolvedMusic(for: try XCTUnwrap(session.effectiveTemplate)))
        session.useTemplateMusic()
        XCTAssertEqual(session.musicMode, .templateDefault)
        XCTAssertNotNil(session.resolvedMusic(for: try XCTUnwrap(session.effectiveTemplate)))

        let output = root.appendingPathComponent("bundled-candle.mp4")
        let exported = try XCTUnwrap(session.export(at: output))
        await exported.value
        XCTAssertTrue(session.message?.contains("已导出") == true, session.message ?? "nil")

        let asset = AVURLAsset(url: output)
        let duration = try await asset.load(.duration)
        let videoTracks = try await asset.loadTracks(withMediaType: .video)
        let audioTracks = try await asset.loadTracks(withMediaType: .audio)
        let track = try XCTUnwrap(videoTracks.first)
        let naturalSize = try await track.load(.naturalSize)
        XCTAssertEqual(naturalSize, CGSize(width: 1920, height: 1080))
        // birthday-candle: 48 + 45 - 15 = 78 frames = 2.60s
        XCTAssertEqual(duration.seconds, 78.0 / 30.0, accuracy: 0.08)
        XCTAssertEqual(audioTracks.count, 1)

        let attachment = XCTAttachment(data: try Data(contentsOf: output), uniformTypeIdentifier: UTType.mpeg4Movie.identifier)
        attachment.name = "photo-movie-bundled-candle"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    @MainActor
    func testPreviewPlaysAdvancesPausesAndStopsOnLeave() async throws {
        let root = try makeDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let library = MediaLibrary(directory: root.appendingPathComponent("Media"))
        let session = PhotoMovieSession(library: library, previewDirectory: root.appendingPathComponent("Preview"))

        let p1 = root.appendingPathComponent("first.jpg")
        let p2 = root.appendingPathComponent("second.jpg")
        let wav = root.appendingPathComponent("bgm-440.wav")
        try writePhoto(to: p1, background: (0.8, 0.2, 0.2))
        try writePhoto(to: p2, background: (0.2, 0.7, 0.3))
        try writeStereoWave(to: wav, frequency: 440, seconds: 3.0)

        let imported = try XCTUnwrap(session.importPhotos([p1, p2]))
        await imported.value
        session.selectTemplate(id: "sunny-journey")
        session.selectMusic(wav)

        let previewTask = try XCTUnwrap(session.preview())
        await previewTask.value

        XCTAssertTrue(session.hasPreview)
        XCTAssertTrue(session.isPlaying)
        XCTAssertNotNil(session.previewURL)
        let item = try XCTUnwrap(session.player.currentItem)
        let duration = try await item.asset.load(.duration)
        let videoTracks = try await item.asset.loadTracks(withMediaType: .video)
        let audioTracks = try await item.asset.loadTracks(withMediaType: .audio)
        XCTAssertEqual(duration.seconds, 52.0 / 30.0, accuracy: 0.06)
        XCTAssertEqual(videoTracks.count, 1)
        XCTAssertEqual(audioTracks.count, 1)

        for _ in 0..<50 {
            if session.player.currentTime().seconds >= 0.2 { break }
            try await Task.sleep(for: .milliseconds(100))
        }
        XCTAssertGreaterThanOrEqual(session.player.currentTime().seconds, 0.2)

        session.pausePreview()
        XCTAssertFalse(session.isPlaying)
        let pausedAt = session.player.currentTime().seconds
        try await Task.sleep(for: .milliseconds(300))
        XCTAssertEqual(session.player.currentTime().seconds, pausedAt, accuracy: 0.08)
    }

    @MainActor
    func testExportProgressCancellationCorruptAudioAndReadOnlyRecovery() async throws {
        let root = try makeDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let library = MediaLibrary(directory: root.appendingPathComponent("Media"))
        let session = PhotoMovieSession(library: library, previewDirectory: root.appendingPathComponent("Preview"))
        let outputs = root.appendingPathComponent("Outputs")
        try FileManager.default.createDirectory(at: outputs, withIntermediateDirectories: false)

        let p1 = root.appendingPathComponent("p1.jpg")
        let p2 = root.appendingPathComponent("p2.jpg")
        let wav440 = root.appendingPathComponent("tone-440.wav")
        let wav660 = root.appendingPathComponent("tone-660.wav")
        let corruptAudio = root.appendingPathComponent("corrupt.m4a")
        try writePhoto(to: p1, background: (0.8, 0.15, 0.15))
        try writePhoto(to: p2, background: (0.15, 0.25, 0.85))
        try writeStereoWave(to: wav440, frequency: 440, seconds: 3.0)
        try writeStereoWave(to: wav660, frequency: 660, seconds: 3.0)
        try Data("Not audio data".utf8).write(to: corruptAudio)
        let originalBytes = try [p1, p2, wav440, wav660].map { try Data(contentsOf: $0) }

        let imported = try XCTUnwrap(session.importPhotos([p1, p2]))
        await imported.value
        session.selectTemplate(id: "sunny-journey")
        session.selectMusic(wav440)

        let movie = outputs.appendingPathComponent("memory.mp4")
        let firstExport = try XCTUnwrap(session.export(at: movie))
        await firstExport.value
        XCTAssertEqual(session.progress, 1.0, accuracy: 0.001)
        XCTAssertEqual(session.lastExportURL, movie)
        let baselineBytes = try Data(contentsOf: movie)
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: outputs.path), ["memory.mp4"])

        // Add more shots and switch to a longer template so cancellation deterministically interrupts an active render.
        let extraImport = try XCTUnwrap(session.importPhotos([p1, p2, p1, p2]))
        await extraImport.value
        session.selectTemplate(id: "starry-night")
        let cancelled = try XCTUnwrap(session.export(at: movie))
        await Task.yield()
        session.cancelCurrentOperation()
        await cancelled.value
        XCTAssertTrue(session.message?.contains("取消") == true, session.message ?? "nil")
        XCTAssertEqual(try Data(contentsOf: movie), baselineBytes)
        XCTAssertFalse(try FileManager.default.contentsOfDirectory(atPath: outputs.path).contains { $0.hasSuffix(".part") })

        while session.photos.count > 2 {
            session.removePhoto(at: session.photos.count - 1)
        }
        session.selectTemplate(id: "sunny-journey")

        session.selectMusic(corruptAudio)
        let badAudioExport = try XCTUnwrap(session.export(at: movie))
        await badAudioExport.value
        XCTAssertTrue(session.message?.contains("配乐") == true, session.message ?? "nil")
        XCTAssertEqual(try Data(contentsOf: movie), baselineBytes)

        session.selectMusic(wav660)
        try FileManager.default.setAttributes([.posixPermissions: 0o555], ofItemAtPath: outputs.path)
        defer { try? FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: outputs.path) }
        let readOnlyExport = try XCTUnwrap(session.export(at: movie))
        await readOnlyExport.value
        XCTAssertTrue(session.message?.contains("无法写入") == true, session.message ?? "nil")
        XCTAssertEqual(try Data(contentsOf: movie), baselineBytes)

        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: outputs.path)
        let recoveredExport = try XCTUnwrap(session.export(at: movie))
        await recoveredExport.value
        XCTAssertTrue(session.message?.contains("已导出") == true, session.message ?? "nil")
        XCTAssertEqual(session.progress, 1.0, accuracy: 0.001)

        let asset = AVURLAsset(url: movie)
        let duration = try await asset.load(.duration)
        let videoTracks = try await asset.loadTracks(withMediaType: .video)
        let audioTracks = try await asset.loadTracks(withMediaType: .audio)
        let track = try XCTUnwrap(videoTracks.first)
        let naturalSize = try await track.load(.naturalSize)
        XCTAssertEqual(naturalSize, CGSize(width: 1920, height: 1080))
        XCTAssertEqual(duration.seconds, 52.0 / 30.0, accuracy: 0.06)
        XCTAssertEqual(audioTracks.count, 1)
        XCTAssertEqual(try [p1, p2, wav440, wav660].map { try Data(contentsOf: $0) }, originalBytes)
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: outputs.path), ["memory.mp4"])

        let attachment = XCTAttachment(data: try Data(contentsOf: movie), uniformTypeIdentifier: UTType.mpeg4Movie.identifier)
        attachment.name = "photo-movie-session-recovered"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private func makeDirectory() throws -> URL {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: false)
        return directory
    }

    private func writePhoto(to url: URL, background: (CGFloat, CGFloat, CGFloat)) throws {
        let space = try XCTUnwrap(CGColorSpace(name: CGColorSpace.sRGB))
        let context = try XCTUnwrap(CGContext(
            data: nil, width: 640, height: 360, bitsPerComponent: 8, bytesPerRow: 0,
            space: space, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
        ))
        context.setFillColor(red: background.0, green: background.1, blue: background.2, alpha: 1)
        context.fill(CGRect(x: 0, y: 0, width: 640, height: 360))
        let image = try XCTUnwrap(context.makeImage())
        let destination = try XCTUnwrap(CGImageDestinationCreateWithURL(url as CFURL, UTType.jpeg.identifier as CFString, 1, nil))
        CGImageDestinationAddImage(destination, image, nil)
        XCTAssertTrue(CGImageDestinationFinalize(destination))
    }

    private func writeStereoWave(to url: URL, frequency: Double, seconds: Double) throws {
        let sampleRate = 44_100
        let channels = 2
        let bitsPerSample = 16
        let count = Int((seconds * Double(sampleRate)).rounded())
        var pcm = Data()
        pcm.reserveCapacity(count * channels * 2)
        for index in 0..<count {
            let phase = 2.0 * Double.pi * frequency * Double(index) / Double(sampleRate)
            let sample = Int16((sin(phase) * 0.75 * Double(Int16.max)).rounded())
            var little = sample.littleEndian
            withUnsafeBytes(of: &little) { bytes in
                pcm.append(contentsOf: bytes)
                pcm.append(contentsOf: bytes)
            }
        }
        let byteRate = UInt32(sampleRate * channels * bitsPerSample / 8)
        let blockAlign = UInt16(channels * bitsPerSample / 8)
        let dataSize = UInt32(pcm.count)
        let chunkSize = UInt32(36 + pcm.count)
        var wav = Data()
        wav.append(contentsOf: "RIFF".utf8)
        appendLittleEndian(chunkSize, to: &wav)
        wav.append(contentsOf: "WAVE".utf8)
        wav.append(contentsOf: "fmt ".utf8)
        appendLittleEndian(UInt32(16), to: &wav)
        appendLittleEndian(UInt16(1), to: &wav)
        appendLittleEndian(UInt16(channels), to: &wav)
        appendLittleEndian(UInt32(sampleRate), to: &wav)
        appendLittleEndian(byteRate, to: &wav)
        appendLittleEndian(blockAlign, to: &wav)
        appendLittleEndian(UInt16(bitsPerSample), to: &wav)
        wav.append(contentsOf: "data".utf8)
        appendLittleEndian(dataSize, to: &wav)
        wav.append(pcm)
        try wav.write(to: url)
    }

    private func appendLittleEndian<T: FixedWidthInteger>(_ value: T, to data: inout Data) {
        var little = value.littleEndian
        withUnsafeBytes(of: &little) { data.append(contentsOf: $0) }
    }
}
