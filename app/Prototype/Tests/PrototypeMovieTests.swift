import AVFoundation
import CoreGraphics
import CoreVideo
import Darwin
import Foundation
import ImageIO
import MediaIO
import Testing
import UniformTypeIdentifiers
@testable import IOSPSCompositorPrototype

@MainActor
struct PrototypeMovieTests {
    @Test
    func twelveMegapixelProjectAndMovieRoundTrip() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: false)
        defer { try? FileManager.default.removeItem(at: directory) }
        let photo = directory.appendingPathComponent("landscape-12mp.jpg")
        try makePhoto(at: photo)
        let clock = ContinuousClock()

        let session = EditorSession()
        let importStart = clock.now
        await session.importImages([photo])
        let importTime = importStart.duration(to: clock.now)
        #expect(session.document?.size == CGSize(width: 4000, height: 3000))
        session.rotateCanvas(clockwise: true)
        let snapshot = try #require(session.projectSnapshot())
        let project = directory.appendingPathComponent("round-trip.comp", isDirectory: true)
        let saveStart = clock.now
        try await ProjectStore.shared.save(snapshot, to: project)
        let saveTime = saveStart.duration(to: clock.now)

        let libraryURL = directory.appendingPathComponent("media", isDirectory: true)
        let library = MediaLibrary(directory: libraryURL)
        let movie = directory.appendingPathComponent("memory.mp4")
        let exportStart = clock.now
        let mediaID = try await GiftMovieExport.render(snapshot, library: library, to: movie)
        let exportTime = exportStart.duration(to: clock.now)

        let reopenStart = clock.now
        let reopened = try await ProjectStore.shared.load(from: project)
        let reopenedSession = EditorSession()
        reopenedSession.installProject(reopened, from: project)
        let reopenTime = reopenStart.duration(to: clock.now)
        #expect(reopenedSession.document?.size == CGSize(width: 3000, height: 4000))
        let reopenedLibrary = MediaLibrary(directory: libraryURL)
        let media = try await reopenedLibrary.load(id: mediaID)
        let photoInLibrary = try #require(media)
        #expect(photoInLibrary.kind == .photo)
        let source = try #require(CGImageSourceCreateWithURL(photoInLibrary.sourceURL as CFURL, nil))
        let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any]
        #expect(properties?[kCGImagePropertyPixelWidth] as? Int == 3000)
        #expect(properties?[kCGImagePropertyPixelHeight] as? Int == 4000)

        let asset = AVURLAsset(url: movie, options: [AVURLAssetPreferPreciseDurationAndTimingKey: true])
        let videoTracks = try await asset.loadTracks(withMediaType: .video)
        let audioTracks = try await asset.loadTracks(withMediaType: .audio)
        let duration = try await asset.load(.duration)
        let playable = try await asset.load(.isPlayable)
        #expect(videoTracks.count == 1)
        #expect(audioTracks.isEmpty)
        #expect(playable)
        #expect(abs(duration.seconds - 3.0) < 0.0001)
        let track = try #require(videoTracks.first)
        let frameRate = try await track.load(.nominalFrameRate)
        #expect(frameRate == 30)

        let reader = try AVAssetReader(asset: asset)
        let output = AVAssetReaderTrackOutput(track: track, outputSettings: [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA])
        try #require(reader.canAdd(output))
        reader.add(output)
        try #require(reader.startReading())
        var frames = 0
        while autoreleasepool(invoking: { output.copyNextSampleBuffer() != nil }) {
            frames += 1
        }
        #expect(reader.status == .completed)
        #expect(frames == 90)
        print("IOSPS_MOVIE duration=\(duration.seconds) fps=\(frameRate) decodedFrames=\(frames) audioTracks=\(audioTracks.count) playable=\(playable)")

        var usage = rusage()
        try #require(getrusage(RUSAGE_SELF, &usage) == 0)
        print("IOSPS_12MP import=\(importTime) save=\(saveTime) export=\(exportTime) reopen=\(reopenTime) peakRSSBytes=\(usage.ru_maxrss)")
    }

    private func makePhoto(at url: URL) throws {
        let colorSpace = try #require(CGColorSpace(name: CGColorSpace.sRGB))
        let context = try #require(CGContext(data: nil, width: 4000, height: 3000, bitsPerComponent: 8,
                                            bytesPerRow: 0, space: colorSpace,
                                            bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue))
        let sunrise = [CGColor(red: 0.14, green: 0.27, blue: 0.48, alpha: 1),
                       CGColor(red: 0.94, green: 0.66, blue: 0.38, alpha: 1)]
        let gradient = try #require(CGGradient(colorsSpace: colorSpace, colors: sunrise as CFArray, locations: [0, 1]))
        context.drawLinearGradient(gradient, start: .zero, end: CGPoint(x: 1200, y: 3000), options: [.drawsAfterEndLocation])
        context.setFillColor(red: 0.96, green: 0.81, blue: 0.52, alpha: 1)
        context.fillEllipse(in: CGRect(x: 2600, y: 1800, width: 600, height: 600))
        let image = try #require(context.makeImage())
        let destination = try #require(CGImageDestinationCreateWithURL(url as CFURL, UTType.jpeg.identifier as CFString, 1, nil))
        CGImageDestinationAddImage(destination, image, nil)
        try #require(CGImageDestinationFinalize(destination))
    }
}
