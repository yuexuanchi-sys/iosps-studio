import BirthdayCore
import CoreGraphics
import Foundation
import ImageIO
import MediaIO
import UniformTypeIdentifiers
import XCTest
@testable import IOSPS

@MainActor
private final class CropTestEventRecorder {
    var events: [PhotoProjectSavedEvent] = []
    func record(_ event: PhotoProjectSavedEvent) { events.append(event) }
}

final class PhotoCropOrientationTests: XCTestCase {
    @MainActor
    func testAllAspectRatiosCustomRatioValidationAndCancelCommit() async throws {
        let root = try makeDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let source = root.appendingPathComponent("canvas.png")
        try writeFourQuadrantPNG(to: source, width: 400, height: 300)

        let session = PhotoEditingSession(
            draftStore: PhotoDraftRecoveryStore(directory: root.appendingPathComponent("Drafts", isDirectory: true))
        )
        let imported = await session.importPhoto(from: source)
        XCTAssertTrue(imported)
        XCTAssertEqual(session.pixelWidth, 400)
        XCTAssertEqual(session.pixelHeight, 300)

        let expectedSizes: [(PhotoCropAspect, Int, Int)] = [
            (.free, 400, 300),
            (.original, 400, 300),
            (.square, 300, 300),
            (.fourThree, 400, 300),
            (.threeFour, 225, 300),
            (.threeTwo, 400, 266),
            (.sixteenNine, 400, 225),
            (.nineSixteen, 168, 300),
            (.twoOne, 400, 200),
        ]

        for (aspect, expectedW, expectedH) in expectedSizes {
            session.beginCrop(aspect)
            XCTAssertTrue(session.isCropping, "Must stay in crop mode for \(aspect.rawValue)")
            XCTAssertEqual(session.activeCropAspect, aspect)
            let rect = try XCTUnwrap(session.editor.cropRect)
            XCTAssertGreaterThanOrEqual(rect.minX, 0)
            XCTAssertGreaterThanOrEqual(rect.minY, 0)
            XCTAssertLessThanOrEqual(rect.maxX, 400)
            XCTAssertLessThanOrEqual(rect.maxY, 300)
            XCTAssertEqual(session.cropPixelWidth, expectedW, "Width mismatch for \(aspect.rawValue)")
            XCTAssertEqual(session.cropPixelHeight, expectedH, "Height mismatch for \(aspect.rawValue)")
        }

        // Valid custom ratio 5:4 on 400x300 -> 375x300.
        XCTAssertTrue(session.applyCustomCropRatio(" 5 : 4 "))
        XCTAssertEqual(session.activeCropChoice, "5:4")
        XCTAssertEqual(session.cropPixelWidth, 375)
        XCTAssertEqual(session.cropPixelHeight, 300)
        XCTAssertNil(session.errorMessage)

        // Invalid custom ratios must be rejected without losing current valid 5:4 crop frame.
        for bad in ["", "0:4", "-3:2", "abc", "1:2:3", "5:0"] {
            XCTAssertFalse(session.applyCustomCropRatio(bad), "Should reject invalid ratio: \(bad)")
            XCTAssertNotNil(session.errorMessage)
            XCTAssertEqual(session.activeCropChoice, "5:4")
            XCTAssertEqual(session.cropPixelWidth, 375)
            XCTAssertEqual(session.cropPixelHeight, 300)
        }

        // Reset restores full canvas free crop frame; cancel leaves canvas untouched with zero undo entries.
        session.resetCropRect()
        XCTAssertEqual(session.activeCropAspect, .free)
        XCTAssertEqual(session.cropPixelWidth, 400)
        XCTAssertEqual(session.cropPixelHeight, 300)

        session.cancelCrop()
        XCTAssertFalse(session.isCropping)
        XCTAssertEqual(session.pixelWidth, 400)
        XCTAssertEqual(session.pixelHeight, 300)
        XCTAssertEqual(session.undoCount, 0)

        // Custom free-crop rectangle commit, undo, and redo.
        session.setCropRect(CGRect(x: 40, y: 30, width: 200, height: 150))
        await session.commitCrop()
        XCTAssertFalse(session.isCropping)
        XCTAssertEqual(session.pixelWidth, 200)
        XCTAssertEqual(session.pixelHeight, 150)
        XCTAssertEqual(session.undoCount, 1)

        session.undo()
        XCTAssertEqual(session.pixelWidth, 400)
        XCTAssertEqual(session.pixelHeight, 300)
        session.redo()
        XCTAssertEqual(session.pixelWidth, 200)
        XCTAssertEqual(session.pixelHeight, 150)
    }

    @MainActor
    func testFourWayLosslessRotationAndFlipPixelQuadrantsAndProjectPersistence() async throws {
        let root = try makeDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let source = root.appendingPathComponent("quadrants.png")
        try writeFourQuadrantPNG(to: source, width: 160, height: 120)
        let originalBytes = try Data(contentsOf: source)

        let recorder = CropTestEventRecorder()
        let session = PhotoEditingSession(
            draftStore: PhotoDraftRecoveryStore(directory: root.appendingPathComponent("Drafts", isDirectory: true))
        )
        session.onSubstantiveProjectSaved = { event in recorder.record(event) }

        let imported = await session.importPhoto(from: source)
        XCTAssertTrue(imported)

        let baselineImage = try await renderCurrentImage(of: session)
        let baselineRGBA = try rgbaBytes(of: baselineImage)
        XCTAssertEqual(try quadrantColors(of: baselineImage), [.red, .green, .blue, .yellow])

        // 1x Rotate CW 90°: 160x120 -> 120x160; TL=blue, TR=red, BL=yellow, BR=green.
        session.rotateClockwise()
        XCTAssertEqual(session.pixelWidth, 120)
        XCTAssertEqual(session.pixelHeight, 160)
        let cwImage = try await renderCurrentImage(of: session)
        XCTAssertEqual(try quadrantColors(of: cwImage), [.blue, .red, .yellow, .green])

        // 1x Rotate CCW 90° immediately reverses CW back to exact original pixels.
        session.rotateCounterclockwise()
        XCTAssertEqual(session.pixelWidth, 160)
        XCTAssertEqual(session.pixelHeight, 120)
        let afterCCW = try await renderCurrentImage(of: session)
        XCTAssertEqual(try rgbaBytes(of: afterCCW), baselineRGBA)

        // 4x Rotate CW 90° round-trip equals exact original pixels and dimensions.
        for _ in 0..<4 { session.rotateClockwise() }
        XCTAssertEqual(session.pixelWidth, 160)
        XCTAssertEqual(session.pixelHeight, 120)
        let afterFourCW = try await renderCurrentImage(of: session)
        XCTAssertEqual(try rgbaBytes(of: afterFourCW), baselineRGBA)

        // 1x Horizontal flip swaps left/right: TL=green, TR=red, BL=yellow, BR=blue; 2x restores exact original.
        session.flipHorizontal()
        let afterFlipH1 = try await renderCurrentImage(of: session)
        XCTAssertEqual(try quadrantColors(of: afterFlipH1), [.green, .red, .yellow, .blue])
        session.flipHorizontal()
        let afterFlipH2 = try await renderCurrentImage(of: session)
        XCTAssertEqual(try rgbaBytes(of: afterFlipH2), baselineRGBA)

        // 1x Vertical flip swaps top/bottom: TL=blue, TR=yellow, BL=red, BR=green; 2x restores exact original.
        session.flipVertical()
        let afterFlipV1 = try await renderCurrentImage(of: session)
        XCTAssertEqual(try quadrantColors(of: afterFlipV1), [.blue, .yellow, .red, .green])
        session.flipVertical()
        let afterFlipV2 = try await renderCurrentImage(of: session)
        XCTAssertEqual(try rgbaBytes(of: afterFlipV2), baselineRGBA)

        // Compound chain: 16:9 crop (160x90) -> CCW (90x160) -> Flip H -> Flip V; undo 4x, redo 4x, save & reopen.
        let undoBeforeChain = session.undoCount
        session.beginCrop(.sixteenNine)
        await session.commitCrop()
        XCTAssertEqual(session.pixelWidth, 160)
        XCTAssertEqual(session.pixelHeight, 90)
        session.rotateCounterclockwise()
        XCTAssertEqual(session.pixelWidth, 90)
        XCTAssertEqual(session.pixelHeight, 160)
        session.flipHorizontal()
        session.flipVertical()
        XCTAssertEqual(session.undoCount, undoBeforeChain + 4)

        let finalImage = try await renderCurrentImage(of: session)
        let expectedFinalRGBA = try rgbaBytes(of: finalImage)

        for _ in 0..<4 { session.undo() }
        XCTAssertEqual(session.pixelWidth, 160)
        XCTAssertEqual(session.pixelHeight, 120)
        let afterUndoChain = try await renderCurrentImage(of: session)
        XCTAssertEqual(try rgbaBytes(of: afterUndoChain), baselineRGBA)

        for _ in 0..<4 { session.redo() }
        XCTAssertEqual(session.pixelWidth, 90)
        XCTAssertEqual(session.pixelHeight, 160)
        let afterRedoChain = try await renderCurrentImage(of: session)
        XCTAssertEqual(try rgbaBytes(of: afterRedoChain), expectedFinalRGBA)

        let savedProject = root.appendingPathComponent("oriented.comp", isDirectory: true)
        let saved = await session.saveProject(to: savedProject)
        XCTAssertTrue(saved)
        XCTAssertEqual(recorder.events.count, 1)
        XCTAssertEqual(recorder.events[0].pixelWidth, 90)
        XCTAssertEqual(recorder.events[0].pixelHeight, 160)

        let reopenedSession = PhotoEditingSession(
            draftStore: PhotoDraftRecoveryStore(directory: root.appendingPathComponent("DraftsReopen", isDirectory: true))
        )
        let reopened = await reopenedSession.openProject(at: savedProject)
        XCTAssertTrue(reopened)
        XCTAssertEqual(reopenedSession.pixelWidth, 90)
        XCTAssertEqual(reopenedSession.pixelHeight, 160)
        let reopenedImage = try await renderCurrentImage(of: reopenedSession)
        XCTAssertEqual(try rgbaBytes(of: reopenedImage), expectedFinalRGBA)
        XCTAssertEqual(try Data(contentsOf: source), originalBytes)
    }

    // MARK: - Helpers

    private enum QuadrantColor: Equatable {
        case red, green, blue, yellow, other
    }

    @MainActor
    private func renderCurrentImage(of session: PhotoEditingSession) async throws -> CGImage {
        let snapshot = try XCTUnwrap(session.editor.projectSnapshot())
        return try await ImageExporter.shared.render(snapshot).image
    }

    private func rgbaBytes(of image: CGImage) throws -> Data {
        let width = image.width
        let height = image.height
        let bytesPerRow = width * 4
        var buffer = Data(count: bytesPerRow * height)
        let space = try XCTUnwrap(CGColorSpace(name: CGColorSpace.sRGB))
        try buffer.withUnsafeMutableBytes { raw in
            guard let base = raw.baseAddress,
                  let context = CGContext(
                    data: base, width: width, height: height, bitsPerComponent: 8, bytesPerRow: bytesPerRow,
                    space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
                  ) else {
                throw ExportError.render
            }
            context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        }
        return buffer
    }

    /// Returns dominant colors for `[topLeft, topRight, bottomLeft, bottomRight]` in visual top-down coordinates.
    private func quadrantColors(of image: CGImage) throws -> [QuadrantColor] {
        let data = try rgbaBytes(of: image)
        let width = image.width
        let height = image.height
        let points = [
            (width / 4, height / 4),
            ((width * 3) / 4, height / 4),
            (width / 4, (height * 3) / 4),
            ((width * 3) / 4, (height * 3) / 4),
        ]
        return points.map { x, y in
            let offset = (y * width + x) * 4
            let r = Int(data[offset])
            let g = Int(data[offset + 1])
            let b = Int(data[offset + 2])
            if r > 180 && g > 170 && b < 100 { return .yellow }
            if r > 180 && g < 100 && b < 100 { return .red }
            if g > 160 && r < 100 && b < 110 { return .green }
            if b > 180 && r < 100 && g < 130 { return .blue }
            return .other
        }
    }

    private func makeDirectory() throws -> URL {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: false)
        return dir
    }

    /// Writes an asymmetric 4-quadrant PNG: visual TL=Red, TR=Green, BL=Blue, BR=Yellow.
    private func writeFourQuadrantPNG(to url: URL, width: Int, height: Int) throws {
        let space = try XCTUnwrap(CGColorSpace(name: CGColorSpace.sRGB))
        let context = try XCTUnwrap(CGContext(
            data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
            space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ))
        let halfW = width / 2
        let halfH = height / 2
        // CGContext origin is bottom-left: y = halfH is visual TOP, y = 0 is visual BOTTOM.
        context.setFillColor(red: 220.0 / 255.0, green: 40.0 / 255.0, blue: 40.0 / 255.0, alpha: 1)
        context.fill(CGRect(x: 0, y: halfH, width: halfW, height: height - halfH)) // Visual Top-Left (Red)
        context.setFillColor(red: 40.0 / 255.0, green: 200.0 / 255.0, blue: 60.0 / 255.0, alpha: 1)
        context.fill(CGRect(x: halfW, y: halfH, width: width - halfW, height: height - halfH)) // Visual Top-Right (Green)
        context.setFillColor(red: 40.0 / 255.0, green: 80.0 / 255.0, blue: 220.0 / 255.0, alpha: 1)
        context.fill(CGRect(x: 0, y: 0, width: halfW, height: halfH)) // Visual Bottom-Left (Blue)
        context.setFillColor(red: 230.0 / 255.0, green: 210.0 / 255.0, blue: 40.0 / 255.0, alpha: 1)
        context.fill(CGRect(x: halfW, y: 0, width: width - halfW, height: halfH)) // Visual Bottom-Right (Yellow)

        let image = try XCTUnwrap(context.makeImage())
        let destination = try XCTUnwrap(CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil))
        CGImageDestinationAddImage(destination, image, nil)
        XCTAssertTrue(CGImageDestinationFinalize(destination))
    }
}
