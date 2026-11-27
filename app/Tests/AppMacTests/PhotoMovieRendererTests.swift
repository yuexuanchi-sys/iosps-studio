import AVFoundation
import BirthdayCore
import CoreGraphics
import Foundation
import ImageIO
import TemplateKit
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

    private func attach(_ movie: URL, as name: String) throws {
        let artifact = XCTAttachment(data: try Data(contentsOf: movie), uniformTypeIdentifier: UTType.mpeg4Movie.identifier)
        artifact.name = name
        artifact.lifetime = .keepAlways
        add(artifact)
    }
}
