import CoreGraphics
import ImageIO
import UniformTypeIdentifiers
import XCTest

final class GiftPrototypeUITests: XCTestCase {
    @MainActor
    func testChineseEntryAndAppearanceVariants() {
        continueAfterFailure = false
        let app = XCUIApplication()
        var lightTitleHeight: CGFloat = 0
        for variant in ["light", "dark", "large"] {
            app.launchArguments = ["--gift-ui-appearance", variant]
            app.launch()
            let title = app.staticTexts["生日快乐"]
            XCTAssertTrue(title.waitForExistence(timeout: 10))
            if variant == "light" { lightTitleHeight = title.frame.height }
            if variant == "large" { XCTAssertGreaterThan(title.frame.height, lightTitleHeight) }
            capture(app, name: "\(variant)-birthday")
            app.typeKey("2", modifierFlags: .command)
            XCTAssertTrue(app.staticTexts["湖畔散步"].waitForExistence(timeout: 5))
            capture(app, name: "\(variant)-memories")
            app.buttons["gift-edit-sample"].firstMatch.click()
            XCTAssertTrue(app.buttons["gift-rotate"].waitForExistence(timeout: 15))
            capture(app, name: "\(variant)-editor")
            app.typeKey("1", modifierFlags: .command)
            XCTAssertTrue(app.staticTexts["生日快乐"].waitForExistence(timeout: 5))
            app.typeKey("3", modifierFlags: .command)
            XCTAssertTrue(app.buttons["gift-rotate"].waitForExistence(timeout: 5))
            app.terminate()
        }
    }

    @MainActor
    func testPhotoWorkflowThroughCommandsAndFilePanels() throws {
        continueAfterFailure = false
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("iosps-ui-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: false)
        defer { try? FileManager.default.removeItem(at: directory) }
        let png = directory.appendingPathComponent("source.png")
        let jpeg = directory.appendingPathComponent("source.jpg")
        try writeFixture(png, type: .png)
        try writeFixture(jpeg, type: .jpeg)
        let originalPNG = try Data(contentsOf: png)
        let originalJPEG = try Data(contentsOf: jpeg)
        let app = XCUIApplication()
        app.launch()

        for source in [jpeg, png] {
            app.typeKey("i", modifierFlags: [.command, .shift])
            chooseFile(source, in: app)
            expectSize(app, width: 320, height: 240)
        }

        let zoomValue = app.staticTexts["gift-zoom-value"]
        let initialZoom = try XCTUnwrap(zoomValue.value as? String)
        app.typeKey("=", modifierFlags: .command)
        waitForLabelChange(zoomValue, from: initialZoom)
        app.typeKey("h", modifierFlags: [.command, .shift])
        let window = app.windows.firstMatch
        let start = window.coordinate(withNormalizedOffset: CGVector(dx: 0.35, dy: 0.55))
        let end = window.coordinate(withNormalizedOffset: CGVector(dx: 0.43, dy: 0.58))
        let beforePan = window.screenshot().pngRepresentation
        start.click(forDuration: 0.15, thenDragTo: end)
        XCTAssertNotEqual(window.screenshot().pngRepresentation, beforePan)
        app.typeKey("0", modifierFlags: .command)

        app.typeKey("k", modifierFlags: .command)
        XCTAssertTrue(app.buttons["gift-apply-crop"].waitForExistence(timeout: 5))
        app.typeKey(.return, modifierFlags: [])
        expectSize(app, width: 320, height: 160)
        app.typeKey("r", modifierFlags: .command)
        expectSize(app, width: 160, height: 320)
        app.typeKey("z", modifierFlags: .command)
        expectSize(app, width: 320, height: 160)
        app.typeKey("z", modifierFlags: [.command, .shift])
        expectSize(app, width: 160, height: 320)

        app.typeKey("l", modifierFlags: [.command, .shift])
        adjust(app, slider: "gift-exposure-slider", to: 0.75)
        app.typeKey("u", modifierFlags: .command)
        adjust(app, slider: "gift-saturation-slider", to: 0.25)

        app.typeKey("s", modifierFlags: .command)
        let project = directory.appendingPathComponent("retouched.comp", isDirectory: true)
        saveFile(project, in: app)
        XCTAssertTrue(FileManager.default.fileExists(atPath: project.path))
        app.terminate()
        app.launch()
        app.typeKey("o", modifierFlags: .command)
        chooseFile(project, in: app)
        expectSize(app, width: 160, height: 320)

        let exportedPNG = directory.appendingPathComponent("retouched.png")
        app.typeKey("e", modifierFlags: .command)
        saveFile(exportedPNG, in: app)
        let exportedJPEG = directory.appendingPathComponent("retouched.jpg")
        app.typeKey("e", modifierFlags: [.command, .shift])
        saveFile(exportedJPEG, in: app)
        let outputPNG = try readImage(exportedPNG)
        let outputJPEG = try readImage(exportedJPEG)
        for image in [outputPNG, outputJPEG] {
            XCTAssertEqual(image.width, 160)
            XCTAssertEqual(image.height, 320)
            XCTAssertEqual(image.colorSpace?.name, CGColorSpace.sRGB)
        }
        XCTAssertTrue([.first, .last, .premultipliedFirst, .premultipliedLast].contains(outputPNG.alphaInfo))
        XCTAssertTrue([.none, .noneSkipFirst, .noneSkipLast].contains(outputJPEG.alphaInfo))
        XCTAssertEqual(try Data(contentsOf: png), originalPNG)
        XCTAssertEqual(try Data(contentsOf: jpeg), originalJPEG)
    }

    @MainActor
    private func expectSize(_ app: XCUIApplication, width: Int, height: Int) {
        let size = app.staticTexts["gift-pixel-size"]
        let expected = "\(width) × \(height) 像素"
        XCTAssertTrue(size.waitForExistence(timeout: 12), "Missing canvas size \(expected)")
        let matching = XCTNSPredicateExpectation(predicate: NSPredicate(format: "label == %@ OR value == %@", expected, expected), object: size)
        XCTAssertEqual(XCTWaiter.wait(for: [matching], timeout: 8), .completed, "Expected \(expected), got \(size.label)")
    }

    @MainActor
    private func waitForLabelChange(_ element: XCUIElement, from oldValue: String) {
        let matching = XCTNSPredicateExpectation(predicate: NSPredicate(format: "value != %@", oldValue), object: element)
        XCTAssertEqual(XCTWaiter.wait(for: [matching], timeout: 5), .completed)
    }

    @MainActor
    private func goTo(_ url: URL, in app: XCUIApplication) {
        app.typeKey("g", modifierFlags: [.command, .shift])
        app.typeText(url.path)
        app.typeKey(.return, modifierFlags: [])
    }

    @MainActor
    private func chooseFile(_ url: URL, in app: XCUIApplication) {
        let sheet = app.sheets.firstMatch
        XCTAssertTrue(sheet.waitForExistence(timeout: 6))
        goTo(url, in: app)
        confirm(sheet.buttons["打开"])
        XCTAssertTrue(sheet.waitForNonExistence(timeout: 8))
    }

    @MainActor
    private func saveFile(_ url: URL, in app: XCUIApplication) {
        let sheet = app.sheets.firstMatch
        XCTAssertTrue(sheet.waitForExistence(timeout: 6))
        goTo(url.deletingLastPathComponent(), in: app)
        let name = sheet.textFields.firstMatch
        XCTAssertTrue(name.waitForExistence(timeout: 5))
        name.click()
        app.typeKey("a", modifierFlags: .command)
        app.typeText(url.lastPathComponent)
        confirm(sheet.buttons["保存"])
        let written = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            FileManager.default.fileExists(atPath: url.path)
        }, object: nil)
        XCTAssertEqual(XCTWaiter.wait(for: [written], timeout: 15), .completed)
    }

    @MainActor
    private func confirm(_ button: XCUIElement) {
        XCTAssertTrue(button.waitForExistence(timeout: 5))
        let enabled = XCTNSPredicateExpectation(predicate: NSPredicate(format: "enabled == true"), object: button)
        XCTAssertEqual(XCTWaiter.wait(for: [enabled], timeout: 6), .completed)
        button.click()
    }

    @MainActor
    private func adjust(_ app: XCUIApplication, slider identifier: String, to position: CGFloat) {
        let slider = app.sliders[identifier]
        XCTAssertTrue(slider.waitForExistence(timeout: 5))
        slider.adjust(toNormalizedSliderPosition: position)
        XCTAssertEqual(slider.normalizedSliderPosition, position, accuracy: 0.05)
        app.typeKey(.return, modifierFlags: .command)
        XCTAssertTrue(app.buttons["gift-rotate"].waitForExistence(timeout: 12))
    }

    private func writeFixture(_ url: URL, type: UTType) throws {
        let space = try XCTUnwrap(CGColorSpace(name: CGColorSpace.sRGB))
        let alpha: CGImageAlphaInfo = type == .png ? .premultipliedLast : .noneSkipLast
        let bitmap = try XCTUnwrap(CGContext(data: nil, width: 320, height: 240, bitsPerComponent: 8, bytesPerRow: 0,
                                            space: space, bitmapInfo: alpha.rawValue))
        bitmap.setFillColor(red: 0.3, green: 0.4, blue: 0.8, alpha: 1)
        bitmap.fill(CGRect(x: 18, y: 18, width: 284, height: 204))
        bitmap.setFillColor(red: 0.8, green: 0.3, blue: 0.2, alpha: 1)
        bitmap.fill(CGRect(x: 216, y: 148, width: 82, height: 56))
        let image = try XCTUnwrap(bitmap.makeImage())
        let destination = try XCTUnwrap(CGImageDestinationCreateWithURL(url as CFURL, type.identifier as CFString, 1, nil))
        CGImageDestinationAddImage(destination, image, nil)
        XCTAssertTrue(CGImageDestinationFinalize(destination))
    }

    private func readImage(_ url: URL) throws -> CGImage {
        let source = try XCTUnwrap(CGImageSourceCreateWithURL(url as CFURL, nil))
        return try XCTUnwrap(CGImageSourceCreateImageAtIndex(source, 0, nil))
    }

    @MainActor
    private func capture(_ app: XCUIApplication, name: String) {
        let attachment = XCTAttachment(screenshot: app.windows.firstMatch.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
