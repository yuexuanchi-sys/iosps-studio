import AVFoundation
import BirthdayCore
import CoreGraphics
import Foundation
import ImageIO
import TemplateKit
import TimelineKit
import UniformTypeIdentifiers
import VideoEngine
import XCTest

final class PhotoMovieRendererTests: XCTestCase {
    @MainActor
    func testWritesOrderedPhotosAndHonorsOrientation() async throws {
        let directory = try makeDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let red = directory.appendingPathComponent("red.jpg")
        let portrait = directory.appendingPathComponent("portrait.jpg")
        try writePhoto(to: red, background: (1, 0, 0))
        try writePhoto(to: portrait, background: (0, 0, 1),
                       stripe: (CGRect(x: 0, y: 0, width: 320, height: 360), (0, 1, 0)), orientation: .right)
        let urls = [red, portrait]
        let originalBytes = try urls.map { try Data(contentsOf: $0) }
        let movie = directory.appendingPathComponent("ordered.mp4")
        try await PhotoMovieRenderer.write(photos: urls.map { .init(id: MediaID(), url: $0) },
                                           template: template(motions: ["still", "still"], frames: 6), to: movie)
        let asset = AVURLAsset(url: movie)
        let duration = try await asset.load(.duration)
        let tracks = try await asset.loadTracks(withMediaType: .video)
        let audio = try await asset.loadTracks(withMediaType: .audio)
        let track = try XCTUnwrap(tracks.first)
        XCTAssertEqual(track.naturalSize, CGSize(width: 1920, height: 1080))
        XCTAssertEqual(duration.seconds, 12.0 / 30.0, accuracy: 0.001)
        XCTAssertTrue(audio.isEmpty)
        XCTAssertEqual(try urls.map { try Data(contentsOf: $0) }, originalBytes)
        try attach(movie, as: "photo-movie-ordered")
    }

    @MainActor
    func testWritesAllFiveCameraMotions() async throws {
        let directory = try makeDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let photo = directory.appendingPathComponent("marker.jpg")
        let movie = directory.appendingPathComponent("motion.mp4")
        try writePhoto(to: photo, background: (0, 1, 0),
                       stripe: (CGRect(x: 280, y: 0, width: 80, height: 360), (1, 0, 0)))
        let input = PhotoMovieInput(id: MediaID(), url: photo)
        let motions = ["still", "zoomIn", "zoomOut", "panLeft", "panRight"]
        try await PhotoMovieRenderer.write(photos: Array(repeating: input, count: motions.count),
                                           template: template(motions: motions, frames: 7), to: movie)
        let duration = try await AVURLAsset(url: movie).load(.duration)
        XCTAssertEqual(duration.seconds, 35.0 / 30.0, accuracy: 0.001)
        try attach(movie, as: "photo-movie-motions")
    }

    @MainActor
    func testDissolvesTwoScenesWithExactFrameBoundaries() async throws {
        let directory = try makeDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let red = directory.appendingPathComponent("red.jpg")
        let blue = directory.appendingPathComponent("blue.jpg")
        try writePhoto(to: red, background: (1, 0, 0))
        try writePhoto(to: blue, background: (0, 0, 1))
        let urls = [red, blue]
        let originalBytes = try urls.map { try Data(contentsOf: $0) }
        let movie = directory.appendingPathComponent("dissolve.mp4")
        let dissolveTemplate = try template(scenes: [
            ["motion": "still", "frames": 30, "transitionFrames": 12],
            ["motion": "still", "frames": 30, "transitionFrames": 12],
        ])
        try await PhotoMovieRenderer.write(photos: urls.map { .init(id: MediaID(), url: $0) },
                                           template: dissolveTemplate, to: movie)
        let asset = AVURLAsset(url: movie)
        let duration = try await asset.load(.duration)
        let tracks = try await asset.loadTracks(withMediaType: .video)
        let audio = try await asset.loadTracks(withMediaType: .audio)
        let track = try XCTUnwrap(tracks.first)
        XCTAssertEqual(track.naturalSize, CGSize(width: 1920, height: 1080))
        XCTAssertEqual(duration.seconds, 48.0 / 30.0, accuracy: 0.001)
        XCTAssertTrue(audio.isEmpty)
        XCTAssertEqual(try urls.map { try Data(contentsOf: $0) }, originalBytes)
        try attach(movie, as: "photo-movie-dissolve")
    }

    @MainActor
    func testRendersChineseCaptionsAndPreservesUncaptionedFrames() async throws {
        let directory = try makeDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let first = directory.appendingPathComponent("first.jpg")
        let second = directory.appendingPathComponent("second.jpg")
        let third = directory.appendingPathComponent("third.jpg")
        try writePhoto(to: first, background: (0.05, 0.14, 0.42))
        try writePhoto(to: second, background: (0.06, 0.36, 0.16))
        try writePhoto(to: third, background: (0.45, 0.10, 0.14))
        let urls = [first, second, third]
        let originalBytes = try urls.map { try Data(contentsOf: $0) }
        let movie = directory.appendingPathComponent("captions.mp4")
        let captionedTemplate = try template(scenes: [
            ["motion": "still", "frames": 18, "transitionFrames": 6, "caption": "生日快乐，拾光留念"],
            ["motion": "still", "frames": 18, "transitionFrames": 6],
            ["motion": "still", "frames": 18, "transitionFrames": 0, "caption": "下一段旅程"],
        ])
        try await PhotoMovieRenderer.write(photos: urls.map { .init(id: MediaID(), url: $0) },
                                           template: captionedTemplate, to: movie)
        let asset = AVURLAsset(url: movie)
        let duration = try await asset.load(.duration)
        let tracks = try await asset.loadTracks(withMediaType: .video)
        let audio = try await asset.loadTracks(withMediaType: .audio)
        let track = try XCTUnwrap(tracks.first)
        XCTAssertEqual(track.naturalSize, CGSize(width: 1920, height: 1080))
        XCTAssertEqual(duration.seconds, 42.0 / 30.0, accuracy: 0.001)
        XCTAssertTrue(audio.isEmpty)
        XCTAssertEqual(try urls.map { try Data(contentsOf: $0) }, originalBytes)
        try attach(movie, as: "photo-movie-captions")
    }

    @MainActor
    func testMuxesMusicWithFadeInOutAndBeatPacing() async throws {
        let directory = try makeDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let p1 = directory.appendingPathComponent("p1.jpg")
        let p2 = directory.appendingPathComponent("p2.jpg")
        let p3 = directory.appendingPathComponent("p3.jpg")
        let wav = directory.appendingPathComponent("tone-440.wav")
        try writePhoto(to: p1, background: (0.8, 0.1, 0.1))
        try writePhoto(to: p2, background: (0.1, 0.7, 0.2))
        try writePhoto(to: p3, background: (0.1, 0.2, 0.85))
        try writeStereoWave(to: wav, segments: [(frequency: 440, seconds: 4.0)])
        let originalMedia = try [p1, p2, p3, wav].map { try Data(contentsOf: $0) }

        let pacing = try MusicBeatAllocator.allocate(
            photoCount: 3,
            targetDurationFrames: 90,
            beatsPerMinute: 120,
            preferredOverlaps: [12, 12],
            defaultFadeInFrames: 15,
            defaultFadeOutFrames: 30
        )
        let music = PhotoMovieMusic(
            url: wav,
            startFrame: 0,
            excerptFrames: 90,
            fadeInFrames: pacing.fadeInFrames,
            fadeOutFrames: pacing.fadeOutFrames
        )
        let movie = directory.appendingPathComponent("music.mp4")
        let recorder = ProgressRecorder()
        try await PhotoMovieRenderer.write(
            photos: [p1, p2, p3].map { .init(id: MediaID(), url: $0) },
            template: template(scenes: [
                ["motion": "zoomIn", "frames": 30, "transitionFrames": 12, "caption": "节拍回忆"],
                ["motion": "panRight", "frames": 30, "transitionFrames": 12],
                ["motion": "zoomOut", "frames": 30, "transitionFrames": 0],
            ]),
            music: music,
            pacing: pacing,
            to: movie,
            progress: { recorder.record($0) }
        )
        let asset = AVURLAsset(url: movie)
        let duration = try await asset.load(.duration)
        let videoTracks = try await asset.loadTracks(withMediaType: .video)
        let audioTracks = try await asset.loadTracks(withMediaType: .audio)
        let track = try XCTUnwrap(videoTracks.first)
        XCTAssertEqual(track.naturalSize, CGSize(width: 1920, height: 1080))
        XCTAssertEqual(duration.seconds, 3.0, accuracy: 0.05)
        XCTAssertEqual(audioTracks.count, 1)
        XCTAssertEqual(recorder.first, 0)
        XCTAssertEqual(recorder.last, 1)
        XCTAssertTrue(recorder.isNonDecreasing)
        XCTAssertEqual(try [p1, p2, p3, wav].map { try Data(contentsOf: $0) }, originalMedia)
        try attach(movie, as: "photo-movie-music")
    }

    @MainActor
    func testLoopsShortExcerptAndRejectsOutOfRangeOrCorruptAudio() async throws {
        let directory = try makeDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let p1 = directory.appendingPathComponent("p1.jpg")
        let p2 = directory.appendingPathComponent("p2.jpg")
        let outputs = directory.appendingPathComponent("Outputs")
        try FileManager.default.createDirectory(at: outputs, withIntermediateDirectories: false)
        try writePhoto(to: p1, background: (0.15, 0.25, 0.6))
        try writePhoto(to: p2, background: (0.6, 0.2, 0.25))
        let wav = directory.appendingPathComponent("two-tone.wav")
        // First 30 frames (1.0s) are 440 Hz, next 30 frames (1.0s) are 660 Hz.
        try writeStereoWave(to: wav, segments: [(frequency: 440, seconds: 1.0), (frequency: 660, seconds: 1.0)])
        let corruptAudio = directory.appendingPathComponent("corrupt.m4a")
        try Data("Not valid audio".utf8).write(to: corruptAudio)
        let originalFiles = try [p1, p2, wav].map { try Data(contentsOf: $0) }

        let inputs = [p1, p2].map { PhotoMovieInput(id: MediaID(), url: $0) }
        let twoShots = try template(motions: ["still", "still"], frames: 30)
        let movie = outputs.appendingPathComponent("soundtrack.mp4")
        try await PhotoMovieRenderer.write(photos: inputs, template: twoShots, to: movie)
        let baselineBytes = try Data(contentsOf: movie)

        do {
            try await PhotoMovieRenderer.write(
                photos: inputs,
                template: twoShots,
                music: PhotoMovieMusic(url: corruptAudio),
                to: movie
            )
            XCTFail("Corrupt audio must fail")
        } catch PhotoMovieRenderer.Failure.unreadableAudio {}
        XCTAssertEqual(try Data(contentsOf: movie), baselineBytes)

        do {
            try await PhotoMovieRenderer.write(
                photos: inputs,
                template: twoShots,
                music: PhotoMovieMusic(url: wav, startFrame: 45, excerptFrames: 30),
                to: movie
            )
            XCTFail("Out-of-range music excerpt must fail")
        } catch PhotoMovieRenderer.Failure.audioExcerptOutOfRange {}
        XCTAssertEqual(try Data(contentsOf: movie), baselineBytes)

        try FileManager.default.setAttributes([.posixPermissions: 0o555], ofItemAtPath: outputs.path)
        defer { try? FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: outputs.path) }
        let loopedExcerpt = PhotoMovieMusic(
            url: wav,
            startFrame: 30,
            excerptFrames: 30,
            fadeInFrames: 6,
            fadeOutFrames: 12
        )
        do {
            try await PhotoMovieRenderer.write(photos: inputs, template: twoShots, music: loopedExcerpt, to: movie)
            XCTFail("Read-only directory must fail")
        } catch PhotoMovieRenderer.Failure.invalidDestination {}
        XCTAssertEqual(try Data(contentsOf: movie), baselineBytes)

        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: outputs.path)
        try await PhotoMovieRenderer.write(photos: inputs, template: twoShots, music: loopedExcerpt, to: movie)
        let asset = AVURLAsset(url: movie)
        let duration = try await asset.load(.duration)
        let audioTracks = try await asset.loadTracks(withMediaType: .audio)
        XCTAssertEqual(duration.seconds, 2.0, accuracy: 0.05)
        XCTAssertEqual(audioTracks.count, 1)
        XCTAssertEqual(try [p1, p2, wav].map { try Data(contentsOf: $0) }, originalFiles)
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: outputs.path), ["soundtrack.mp4"])
        try attach(movie, as: "photo-movie-music-loop")
    }

    @MainActor
    func testFailedOrCancelledWritesKeepEarlierMovieAndCanRetry() async throws {
        let directory = try makeDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let photo = directory.appendingPathComponent("photo.jpg")
        let secondPhoto = directory.appendingPathComponent("second.jpg")
        let outputs = directory.appendingPathComponent("Outputs")
        try FileManager.default.createDirectory(at: outputs, withIntermediateDirectories: false)
        try writePhoto(to: photo, background: (0, 1, 0))
        try writePhoto(to: secondPhoto, background: (0, 0, 1))
        let originalFirst = try Data(contentsOf: photo)
        let originalSecond = try Data(contentsOf: secondPhoto)
        let input = PhotoMovieInput(id: MediaID(), url: photo)
        let secondInput = PhotoMovieInput(id: MediaID(), url: secondPhoto)
        let movie = outputs.appendingPathComponent("saved.mp4")
        let still = try template(motions: ["still"], frames: 6)
        let dissolveCaption = try template(scenes: [
            ["motion": "still", "frames": 30, "transitionFrames": 12, "caption": "重试后的祝福"],
            ["motion": "still", "frames": 30, "transitionFrames": 0],
        ])
        try await PhotoMovieRenderer.write(photos: [input], template: still, to: movie)
        let successful = try Data(contentsOf: movie)

        do {
            try await PhotoMovieRenderer.write(photos: [], template: dissolveCaption, to: movie)
            XCTFail("An empty shot sequence must fail")
        } catch PhotoMovieRenderer.Failure.emptyInput {}
        let corrupt = PhotoMovieInput(id: MediaID(), url: directory.appendingPathComponent("corrupt.jpg"))
        try Data("Not a photo".utf8).write(to: corrupt.url)
        do {
            try await PhotoMovieRenderer.write(photos: [input, corrupt], template: dissolveCaption, to: movie)
            XCTFail("An unreadable shot must fail")
        } catch PhotoMovieRenderer.Failure.unreadablePhoto(let id) {
            XCTAssertEqual(id, corrupt.id)
        }

        let long = try template(motions: ["zoomIn"], frames: 180)
        let rendering = Task { try await PhotoMovieRenderer.write(photos: [input], template: long, to: movie) }
        await Task.yield()
        rendering.cancel()
        do {
            try await rendering.value
            XCTFail("A cancelled render must fail")
        } catch is CancellationError {}

        try FileManager.default.setAttributes([.posixPermissions: 0o555], ofItemAtPath: outputs.path)
        defer { try? FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: outputs.path) }
        do {
            try await PhotoMovieRenderer.write(photos: [input, secondInput], template: dissolveCaption, to: movie)
            XCTFail("The destination directory is read-only")
        } catch PhotoMovieRenderer.Failure.invalidDestination {}
        XCTAssertEqual(try Data(contentsOf: movie), successful)

        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: outputs.path)
        try await PhotoMovieRenderer.write(photos: [input, secondInput], template: dissolveCaption, to: movie)
        let duration = try await AVURLAsset(url: movie).load(.duration)
        XCTAssertEqual(duration.seconds, 48.0 / 30.0, accuracy: 0.001)
        XCTAssertEqual(try Data(contentsOf: photo), originalFirst)
        XCTAssertEqual(try Data(contentsOf: secondPhoto), originalSecond)
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: outputs.path), ["saved.mp4"])
        try attach(movie, as: "photo-movie-retry")
    }

    private func makeDirectory() throws -> URL {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: false)
        return directory
    }

    private func template(motions: [String], frames: Int) throws -> MemoryTemplate {
        let scenes: [[String: Any]] = motions.map { ["motion": $0, "frames": frames, "transitionFrames": 0] }
        return try template(scenes: scenes)
    }

    private func template(scenes: [[String: Any]]) throws -> MemoryTemplate {
        let data = try JSONSerialization.data(withJSONObject: ["formatVersion": 1, "id": "synthetic",
                                                                 "name": "Synthetic", "scenes": scenes])
        return try JSONDecoder().decode(MemoryTemplate.self, from: data)
    }

    private func writePhoto(to url: URL, background: (CGFloat, CGFloat, CGFloat),
                            stripe: (CGRect, (CGFloat, CGFloat, CGFloat))? = nil,
                            orientation: CGImagePropertyOrientation = .up) throws {
        let space = try XCTUnwrap(CGColorSpace(name: CGColorSpace.sRGB))
        let context = try XCTUnwrap(CGContext(data: nil, width: 640, height: 360, bitsPerComponent: 8,
                                              bytesPerRow: 0, space: space,
                                              bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue))
        context.setFillColor(red: background.0, green: background.1, blue: background.2, alpha: 1)
        context.fill(CGRect(x: 0, y: 0, width: 640, height: 360))
        if let (rect, color) = stripe {
            context.setFillColor(red: color.0, green: color.1, blue: color.2, alpha: 1)
            context.fill(rect)
        }
        let image = try XCTUnwrap(context.makeImage())
        let file = try XCTUnwrap(CGImageDestinationCreateWithURL(url as CFURL, UTType.jpeg.identifier as CFString, 1, nil))
        CGImageDestinationAddImage(file, image, [kCGImagePropertyOrientation: orientation.rawValue] as CFDictionary)
        XCTAssertTrue(CGImageDestinationFinalize(file))
    }

    private func writeStereoWave(to url: URL, segments: [(frequency: Double, seconds: Double)]) throws {
        let sampleRate = 44_100
        let channels = 2
        let bitsPerSample = 16
        var pcm = Data()
        for segment in segments {
            let count = Int((segment.seconds * Double(sampleRate)).rounded())
            for index in 0..<count {
                let phase = 2.0 * Double.pi * segment.frequency * Double(index) / Double(sampleRate)
                let sample = Int16((sin(phase) * 0.8 * Double(Int16.max)).rounded())
                var little = sample.littleEndian
                withUnsafeBytes(of: &little) { bytes in
                    pcm.append(contentsOf: bytes)
                    pcm.append(contentsOf: bytes)
                }
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

    private func attach(_ movie: URL, as name: String) throws {
        let artifact = XCTAttachment(data: try Data(contentsOf: movie), uniformTypeIdentifier: UTType.mpeg4Movie.identifier)
        artifact.name = name
        artifact.lifetime = .keepAlways
        add(artifact)
    }
}

private final class ProgressRecorder: @unchecked Sendable {
    private let lock = NSLock()
    private var values: [Double] = []

    func record(_ value: Double) {
        lock.lock()
        values.append(value)
        lock.unlock()
    }

    var first: Double? {
        lock.lock()
        defer { lock.unlock() }
        return values.first
    }

    var last: Double? {
        lock.lock()
        defer { lock.unlock() }
        return values.last
    }

    var isNonDecreasing: Bool {
        lock.lock()
        defer { lock.unlock() }
        guard values.count >= 2 else { return true }
        return zip(values, values.dropFirst()).allSatisfy { $0 <= $1 }
    }
}
