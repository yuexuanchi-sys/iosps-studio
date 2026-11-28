import BirthdayCore
import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers
import XCTest
@testable import IOSPS

@MainActor
private final class AdjustEventRecorder {
    var events: [PhotoProjectSavedEvent] = []
    func record(_ event: PhotoProjectSavedEvent) { events.append(event) }
}

final class PhotoBasicAdjustmentTests: XCTestCase {
    func testAllEightBasicAdjustmentsZeroIdentityAndDirectionalPixelEffects() throws {
        // Test fixture 1: multi-tone color chart (dark patch, mid-gray, bright patch, soft red, vertical soft edge).
        let chart = try makeMultiToneChart(width: 160, height: 120)
        let baselineData = try rgbaBytes(of: chart)

        // 0. Identity (all zeros) must be exact bit-for-bit identical.
        let identity = try PhotoBasicAdjustments().apply(to: chart)
        XCTAssertEqual(try rgbaBytes(of: identity), baselineData)

        let baseMid = try meanRGB(of: chart, in: CGRect(x: 45, y: 15, width: 30, height: 30))
        let baseDark = try meanRGB(of: chart, in: CGRect(x: 5, y: 15, width: 30, height: 30))
        let baseBright = try meanRGB(of: chart, in: CGRect(x: 85, y: 15, width: 30, height: 30))
        let baseRed = try meanRGB(of: chart, in: CGRect(x: 125, y: 15, width: 30, height: 30))

        // 1. Brightness (+60 lifts mid-gray significantly; -60 lowers it).
        let brightUp = try PhotoBasicAdjustments(brightness: 60).apply(to: chart)
        let brightDown = try PhotoBasicAdjustments(brightness: -60).apply(to: chart)
        XCTAssertGreaterThan(try meanRGB(of: brightUp, in: CGRect(x: 45, y: 15, width: 30, height: 30)).luma, baseMid.luma + 35)
        XCTAssertLessThan(try meanRGB(of: brightDown, in: CGRect(x: 45, y: 15, width: 30, height: 30)).luma, baseMid.luma - 35)

        // 2. Contrast (+75 increases bright-minus-dark spread; -75 compresses spread).
        let baseSpread = baseBright.luma - baseDark.luma
        let contrastUp = try PhotoBasicAdjustments(contrast: 75).apply(to: chart)
        let contrastDown = try PhotoBasicAdjustments(contrast: -75).apply(to: chart)
        let upSpread = try meanRGB(of: contrastUp, in: CGRect(x: 85, y: 15, width: 30, height: 30)).luma
            - meanRGB(of: contrastUp, in: CGRect(x: 5, y: 15, width: 30, height: 30)).luma
        let downSpread = try meanRGB(of: contrastDown, in: CGRect(x: 85, y: 15, width: 30, height: 30)).luma
            - meanRGB(of: contrastDown, in: CGRect(x: 5, y: 15, width: 30, height: 30)).luma
        XCTAssertGreaterThan(upSpread, baseSpread + 20)
        XCTAssertLessThan(downSpread, baseSpread - 20)

        // 3. Saturation (-100 desaturates red to neutral gray; +80 boosts red-green separation).
        let desat = try PhotoBasicAdjustments(saturation: -100).apply(to: chart)
        let desatRed = try meanRGB(of: desat, in: CGRect(x: 125, y: 15, width: 30, height: 30))
        XCTAssertLessThanOrEqual(abs(desatRed.r - desatRed.g), 3.0)
        XCTAssertLessThanOrEqual(abs(desatRed.r - desatRed.b), 3.0)
        let boostSat = try PhotoBasicAdjustments(saturation: 80).apply(to: chart)
        let boostedRed = try meanRGB(of: boostSat, in: CGRect(x: 125, y: 15, width: 30, height: 30))
        XCTAssertGreaterThan(boostedRed.r - boostedRed.g, (baseRed.r - baseRed.g) + 20)

        // 4. Exposure (+1.0 EV brightens mid-gray; -1.0 EV darkens mid-gray).
        let expUp = try PhotoBasicAdjustments(exposure: 1.0).apply(to: chart)
        let expDown = try PhotoBasicAdjustments(exposure: -1.0).apply(to: chart)
        XCTAssertGreaterThan(try meanRGB(of: expUp, in: CGRect(x: 45, y: 15, width: 30, height: 30)).luma, baseMid.luma + 30)
        XCTAssertLessThan(try meanRGB(of: expDown, in: CGRect(x: 45, y: 15, width: 30, height: 30)).luma, baseMid.luma - 30)

        // 5. Temperature (+70 warms neutral gray so R > B; -70 cools neutral gray so B > R).
        let warm = try PhotoBasicAdjustments(temperature: 70).apply(to: chart)
        let warmMid = try meanRGB(of: warm, in: CGRect(x: 45, y: 15, width: 30, height: 30))
        XCTAssertGreaterThan(warmMid.r - warmMid.b, 20)
        let cool = try PhotoBasicAdjustments(temperature: -70).apply(to: chart)
        let coolMid = try meanRGB(of: cool, in: CGRect(x: 45, y: 15, width: 30, height: 30))
        XCTAssertGreaterThan(coolMid.b - coolMid.r, 20)

        // 6. Highlights & Shadows (highlights -80 pulls down bright patch; shadows +80 lifts dark patch).
        let hiRecover = try PhotoBasicAdjustments(highlights: -80).apply(to: chart)
        XCTAssertLessThan(try meanRGB(of: hiRecover, in: CGRect(x: 85, y: 15, width: 30, height: 30)).luma, baseBright.luma - 18)
        let shLift = try PhotoBasicAdjustments(shadows: 80).apply(to: chart)
        XCTAssertGreaterThan(try meanRGB(of: shLift, in: CGRect(x: 5, y: 15, width: 30, height: 30)).luma, baseDark.luma + 18)

        // 7. Sharpen (80 strictly increases local edge contrast across the vertical boundary at x=80 in the lower half).
        let baseEdge = try maxHorizontalGradient(of: chart, y: 90, xRange: 74...86)
        let sharpened = try PhotoBasicAdjustments(sharpen: 80).apply(to: chart)
        let sharpEdge = try maxHorizontalGradient(of: sharpened, y: 90, xRange: 74...86)
        XCTAssertGreaterThan(sharpEdge, baseEdge + 8)

        // 8. Vignette (80 darkens corners relative to center on a uniform mid-gray canvas).
        let uniform = try makeUniformImage(width: 160, height: 120, gray: 165)
        let vignetted = try PhotoBasicAdjustments(vignette: 80).apply(to: uniform)
        let centerLuma = try meanRGB(of: vignetted, in: CGRect(x: 70, y: 50, width: 20, height: 20)).luma
        let cornerLuma = try meanRGB(of: vignetted, in: CGRect(x: 2, y: 2, width: 12, height: 12)).luma
        XCTAssertGreaterThan(centerLuma, 145)
        XCTAssertLessThan(cornerLuma, centerLuma - 30)
    }

    @MainActor
    func testSessionLivePreviewCompareOriginalResetCancelUndoRedoAndProjectSave() async throws {
        let root = try makeDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let source = root.appendingPathComponent("portrait.png")
        let chart = try makeMultiToneChart(width: 160, height: 120)
        try writePNG(chart, to: source)
        let originalBytes = try Data(contentsOf: source)

        let recorder = AdjustEventRecorder()
        let session = PhotoEditingSession(
            draftStore: PhotoDraftRecoveryStore(directory: root.appendingPathComponent("Drafts", isDirectory: true))
        )
        session.onSubstantiveProjectSaved = { event in recorder.record(event) }

        let imported = await session.importPhoto(from: source)
        XCTAssertTrue(imported)
        let baselineRGBA = try rgbaBytes(of: try await renderCurrentImage(of: session))

        // Open basic adjustments, modify multiple sliders, verify compare-original toggle preserves values.
        session.beginBasicAdjustments()
        XCTAssertTrue(session.isAdjustingBasic)
        XCTAssertTrue(session.isAdjustingColor)
        session.updateBasicAdjustments {
            $0.brightness = 25
            $0.temperature = 40
            $0.vignette = 50
        }
        XCTAssertEqual(session.basicAdjustments.brightness, 25)
        XCTAssertEqual(session.basicAdjustments.temperature, 40)
        XCTAssertEqual(session.basicAdjustments.vignette, 50)

        session.setComparingOriginal(true)
        XCTAssertTrue(session.isComparingOriginal)
        XCTAssertEqual(session.basicAdjustments.temperature, 40)
        session.setComparingOriginal(false)
        XCTAssertFalse(session.isComparingOriginal)

        // Single-item reset & reset-all work cleanly.
        session.resetBasicAdjustment(\.temperature)
        XCTAssertEqual(session.basicAdjustments.temperature, 0)
        XCTAssertEqual(session.basicAdjustments.brightness, 25)
        session.resetAllBasicAdjustments()
        XCTAssertTrue(session.basicAdjustments.isIdentity)

        // Cancel leaves canvas identical and adds zero undo entries.
        session.updateBasicAdjustments { $0.exposure = 1.0 }
        session.cancelActiveAdjustment()
        XCTAssertFalse(session.isAdjustingBasic)
        XCTAssertEqual(session.undoCount, 0)
        let afterCancel = try await renderCurrentImage(of: session)
        XCTAssertEqual(try rgbaBytes(of: afterCancel), baselineRGBA)

        // Committing all-zero adjustments adds zero undo entries.
        session.beginBasicAdjustments()
        await session.commitActiveAdjustment()
        XCTAssertFalse(session.isAdjustingBasic)
        XCTAssertEqual(session.undoCount, 0)

        // Committing non-zero adjustments produces exactly 1 undo step, supports undo/redo, and notifies memories on save.
        session.beginBasicAdjustments()
        session.updateBasicAdjustments {
            $0.brightness = 30
            $0.contrast = 25
            $0.saturation = 20
            $0.temperature = 45
            $0.shadows = 30
            $0.vignette = 40
        }
        await session.commitActiveAdjustment()
        XCTAssertFalse(session.isAdjustingBasic)
        XCTAssertEqual(session.undoCount, 1)

        let adjustedImage = try await renderCurrentImage(of: session)
        let adjustedRGBA = try rgbaBytes(of: adjustedImage)
        XCTAssertNotEqual(adjustedRGBA, baselineRGBA)

        session.undo()
        let afterUndo = try await renderCurrentImage(of: session)
        XCTAssertEqual(try rgbaBytes(of: afterUndo), baselineRGBA)

        session.redo()
        let afterRedo = try await renderCurrentImage(of: session)
        XCTAssertEqual(try rgbaBytes(of: afterRedo), adjustedRGBA)

        let savedProject = root.appendingPathComponent("adjusted.comp", isDirectory: true)
        let saved = await session.saveProject(to: savedProject)
        XCTAssertTrue(saved)
        XCTAssertEqual(recorder.events.count, 1)

        let reopenedSession = PhotoEditingSession(
            draftStore: PhotoDraftRecoveryStore(directory: root.appendingPathComponent("DraftsReopen", isDirectory: true))
        )
        let reopened = await reopenedSession.openProject(at: savedProject)
        XCTAssertTrue(reopened)
        let reopenedImage = try await renderCurrentImage(of: reopenedSession)
        XCTAssertEqual(try rgbaBytes(of: reopenedImage), adjustedRGBA)
        XCTAssertEqual(try Data(contentsOf: source), originalBytes)
    }

    // MARK: - Helpers

    private struct RGBMean {
        let r: Double
        let g: Double
        let b: Double
        var luma: Double { 0.2126 * r + 0.7152 * g + 0.0722 * b }
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

    private func meanRGB(of image: CGImage, in rect: CGRect) throws -> RGBMean {
        let data = try rgbaBytes(of: image)
        let width = image.width
        let minX = max(0, Int(rect.minX))
        let maxX = min(width, Int(rect.maxX))
        let minY = max(0, Int(rect.minY))
        let maxY = min(image.height, Int(rect.maxY))
        var rSum = 0.0, gSum = 0.0, bSum = 0.0, count = 0.0
        for y in minY..<maxY {
            for x in minX..<maxX {
                let offset = (y * width + x) * 4
                rSum += Double(data[offset])
                gSum += Double(data[offset + 1])
                bSum += Double(data[offset + 2])
                count += 1
            }
        }
        return RGBMean(r: rSum / max(1, count), g: gSum / max(1, count), b: bSum / max(1, count))
    }

    private func maxHorizontalGradient(of image: CGImage, y: Int, xRange: ClosedRange<Int>) throws -> Double {
        let data = try rgbaBytes(of: image)
        let width = image.width
        var maxGrad = 0.0
        for x in xRange.lowerBound..<xRange.upperBound {
            let left = Double(data[(y * width + x) * 4])
            let right = Double(data[(y * width + x + 1) * 4])
            maxGrad = max(maxGrad, abs(right - left))
        }
        return maxGrad
    }

    private func makeMultiToneChart(width: Int, height: Int) throws -> CGImage {
        let space = try XCTUnwrap(CGColorSpace(name: CGColorSpace.sRGB))
        let context = try XCTUnwrap(CGContext(
            data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
            space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ))
        // Top half (visual y in 0..<60 -> CG y in 60..<120): 4 bands: dark(64), mid(128), bright(192), soft red(190,105,105).
        let bandW = width / 4
        let halfH = height / 2
        context.setFillColor(red: 64.0 / 255.0, green: 64.0 / 255.0, blue: 64.0 / 255.0, alpha: 1)
        context.fill(CGRect(x: 0, y: halfH, width: bandW, height: height - halfH))
        context.setFillColor(red: 128.0 / 255.0, green: 128.0 / 255.0, blue: 128.0 / 255.0, alpha: 1)
        context.fill(CGRect(x: bandW, y: halfH, width: bandW, height: height - halfH))
        context.setFillColor(red: 192.0 / 255.0, green: 192.0 / 255.0, blue: 192.0 / 255.0, alpha: 1)
        context.fill(CGRect(x: bandW * 2, y: halfH, width: bandW, height: height - halfH))
        context.setFillColor(red: 190.0 / 255.0, green: 105.0 / 255.0, blue: 105.0 / 255.0, alpha: 1)
        context.fill(CGRect(x: bandW * 3, y: halfH, width: width - bandW * 3, height: height - halfH))

        // Bottom half (visual y in 60..<120 -> CG y in 0..<60): soft step edge across x=80 (100 -> 160 over 4px).
        context.setFillColor(red: 100.0 / 255.0, green: 100.0 / 255.0, blue: 100.0 / 255.0, alpha: 1)
        context.fill(CGRect(x: 0, y: 0, width: width / 2 - 2, height: halfH))
        context.setFillColor(red: 115.0 / 255.0, green: 115.0 / 255.0, blue: 115.0 / 255.0, alpha: 1)
        context.fill(CGRect(x: width / 2 - 2, y: 0, width: 2, height: halfH))
        context.setFillColor(red: 145.0 / 255.0, green: 145.0 / 255.0, blue: 145.0 / 255.0, alpha: 1)
        context.fill(CGRect(x: width / 2, y: 0, width: 2, height: halfH))
        context.setFillColor(red: 160.0 / 255.0, green: 160.0 / 255.0, blue: 160.0 / 255.0, alpha: 1)
        context.fill(CGRect(x: width / 2 + 2, y: 0, width: width - (width / 2 + 2), height: halfH))

        return try XCTUnwrap(context.makeImage())
    }

    private func makeUniformImage(width: Int, height: Int, gray: Int) throws -> CGImage {
        let space = try XCTUnwrap(CGColorSpace(name: CGColorSpace.sRGB))
        let context = try XCTUnwrap(CGContext(
            data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
            space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ))
        let v = CGFloat(gray) / 255.0
        context.setFillColor(red: v, green: v, blue: v, alpha: 1)
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        return try XCTUnwrap(context.makeImage())
    }

    private func writePNG(_ image: CGImage, to url: URL) throws {
        let dest = try XCTUnwrap(CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil))
        CGImageDestinationAddImage(dest, image, nil)
        XCTAssertTrue(CGImageDestinationFinalize(dest))
    }

    private func makeDirectory() throws -> URL {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: false)
        return dir
    }
}
