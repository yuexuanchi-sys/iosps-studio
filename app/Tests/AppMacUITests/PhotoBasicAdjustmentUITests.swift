import AppKit
import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers
import XCTest

final class PhotoBasicAdjustmentUITests: XCTestCase {
    @MainActor
    func testBasicAdjustmentsSlidersCompareResetApplySaveAndAppearances() throws {
        continueAfterFailure = false
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let inputs = root.appendingPathComponent("Inputs", isDirectory: true)
        let outputs = root.appendingPathComponent("Outputs", isDirectory: true)
        let localData = root.appendingPathComponent("Local", isDirectory: true)
        try FileManager.default.createDirectory(at: inputs, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: outputs, withIntermediateDirectories: false)
        defer { try? FileManager.default.removeItem(at: root) }

        let source = inputs.appendingPathComponent("scene.png")
        try writeSyntheticScene(to: source, width: 360, height: 240)
        let originalBytes = try Data(contentsOf: source)

        let app = XCUIApplication()
        app.launchEnvironment["IOSPS_TEST_VIDEO_DIRECTORY"] = localData.path
        app.launchEnvironment["IOSPS_TEST_APPEARANCE"] = "light"
        app.launch()
        defer {
            if app.state != .notRunning {
                app.typeKey("q", modifierFlags: .command)
                _ = app.wait(for: .notRunning, timeout: 5)
            }
        }

        let window = openPhotoEditor(in: app)
        app.buttons["photo-editor-select"].click()
        chooseFile(source, in: app)
        expectEditorSize(app, width: 360, height: 240)

        // 1. Open unified 8-item Basic Adjustments panel and adjust brightness, temperature, vignette.
        let basicButton = app.buttons["photo-editor-basic-adjust"]
        waitUntilEnabled(basicButton)
        basicButton.click()

        let brightnessSlider = app.sliders["photo-editor-slider-brightness"]
        let temperatureSlider = app.sliders["photo-editor-slider-temperature"]
        let vignetteSlider = app.sliders["photo-editor-slider-vignette"]
        XCTAssertTrue(brightnessSlider.waitForExistence(timeout: 10))
        brightnessSlider.adjust(toNormalizedSliderPosition: 0.75)
        temperatureSlider.adjust(toNormalizedSliderPosition: 0.85)
        vignetteSlider.adjust(toNormalizedSliderPosition: 0.70)

        let tempValue = app.staticTexts["photo-editor-value-temperature"]
        XCTAssertTrue(tempValue.waitForExistence(timeout: 5))
        XCTAssertFalse(textEquals("0", in: tempValue), tempValue.debugDescription)
        attach(XCTAttachment(screenshot: window.screenshot()), named: "adjust-panel-light")

        // 2. Toggle compare-original on/off and test one-click reset-all.
        let compareToggle = app.checkBoxes["photo-editor-compare-original"].exists
            ? app.checkBoxes["photo-editor-compare-original"]
            : app.buttons["photo-editor-compare-original"]
        XCTAssertTrue(compareToggle.waitForExistence(timeout: 5))
        compareToggle.click()
        compareToggle.click()

        let resetAll = app.buttons["photo-editor-reset-all-adjustments"]
        waitUntilEnabled(resetAll)
        resetAll.click()
        let resetExpectation = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "label == '0' OR value == '0'"),
            object: tempValue
        )
        XCTAssertEqual(XCTWaiter.wait(for: [resetExpectation], timeout: 8), .completed, tempValue.debugDescription)

        // 3. Re-adjust temperature, contrast, shadows, and vignette, then apply as a single undoable step.
        temperatureSlider.adjust(toNormalizedSliderPosition: 0.85)
        app.sliders["photo-editor-slider-contrast"].adjust(toNormalizedSliderPosition: 0.70)
        app.sliders["photo-editor-slider-shadows"].adjust(toNormalizedSliderPosition: 0.75)
        vignetteSlider.adjust(toNormalizedSliderPosition: 0.65)
        app.buttons["photo-editor-apply-adjustment"].click()

        expectHistoryCount(app, undo: 1, redo: 0)
        let undoButton = app.buttons["photo-editor-undo"]
        waitUntilEnabled(undoButton)
        undoButton.click()
        expectHistoryCount(app, undo: 0, redo: 1)
        let redoButton = app.buttons["photo-editor-redo"]
        waitUntilEnabled(redoButton)
        redoButton.click()
        expectHistoryCount(app, undo: 1, redo: 0)

        // 4. Save project, graceful quit, and relaunch in dark mode to capture applied dark screenshot.
        let savedProject = outputs.appendingPathComponent("graded.comp", isDirectory: true)
        app.buttons["photo-editor-save"].click()
        saveFile(savedProject, in: app)
        waitForEditorSaved(app)

        app.typeKey("q", modifierFlags: .command)
        XCTAssertTrue(app.wait(for: .notRunning, timeout: 10))

        app.launchEnvironment["IOSPS_TEST_APPEARANCE"] = "dark"
        app.launch()
        let darkWindow = openPhotoEditor(in: app)
        expectEditorSize(app, width: 360, height: 240)
        attach(XCTAttachment(screenshot: darkWindow.screenshot()), named: "adjust-applied-dark")

        XCTAssertEqual(try Data(contentsOf: source), originalBytes)
        app.typeKey("q", modifierFlags: .command)
        XCTAssertTrue(app.wait(for: .notRunning, timeout: 10))
    }

    @MainActor
    private func openPhotoEditor(in app: XCUIApplication) -> XCUIElement {
        let window = app.windows["IOSPS"]
        if !window.waitForExistence(timeout: 5) {
            app.typeKey("n", modifierFlags: .command)
        }
        XCTAssertTrue(app.staticTexts["birthday-title"].waitForExistence(timeout: 15), app.debugDescription)
        let entry = window.toolbars.buttons.matching(identifier: "photo-editor-entry").firstMatch
        XCTAssertTrue(entry.waitForExistence(timeout: 5))
        entry.click()
        XCTAssertTrue(app.staticTexts["photo-editor-title"].waitForExistence(timeout: 10))
        return window
    }

    @MainActor
    private func expectEditorSize(_ app: XCUIApplication, width: Int, height: Int) {
        let label = app.staticTexts["photo-editor-pixel-size"]
        let expected = "\(width) × \(height) 像素"
        XCTAssertTrue(label.waitForExistence(timeout: 12), "Missing size \(expected)")
        let match = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "label == %@ OR value == %@", expected, expected),
            object: label
        )
        XCTAssertEqual(XCTWaiter.wait(for: [match], timeout: 10), .completed, label.debugDescription)
    }

    @MainActor
    private func expectHistoryCount(_ app: XCUIApplication, undo: Int, redo: Int) {
        let label = app.staticTexts["photo-editor-history-count"]
        let expected = "可撤销 \(undo) 步 · 可重做 \(redo) 步"
        XCTAssertTrue(label.waitForExistence(timeout: 12))
        let match = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "label == %@ OR value == %@", expected, expected),
            object: label
        )
        XCTAssertEqual(XCTWaiter.wait(for: [match], timeout: 10), .completed, label.debugDescription)
    }

    @MainActor
    private func textEquals(_ expected: String, in element: XCUIElement) -> Bool {
        element.label == expected || (element.value as? String) == expected
    }

    @MainActor
    private func waitUntilEnabled(_ element: XCUIElement, timeout: TimeInterval = 15) {
        let ready = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "exists == true AND enabled == true"),
            object: element
        )
        XCTAssertEqual(XCTWaiter.wait(for: [ready], timeout: timeout), .completed, element.debugDescription)
    }

    @MainActor
    private func waitForEditorSaved(_ app: XCUIApplication) {
        let saved = app.staticTexts.matching(NSPredicate(
            format: "identifier == %@ AND (label CONTAINS %@ OR value CONTAINS %@)",
            "photo-editor-status", "工程已保存", "工程已保存"
        )).firstMatch
        XCTAssertTrue(saved.waitForExistence(timeout: 15))
    }

    @MainActor
    private func goTo(_ url: URL, in app: XCUIApplication) {
        app.typeKey("g", modifierFlags: [.command, .shift])
        app.typeText(url.path)
        app.typeKey(.return, modifierFlags: [])
    }

    @MainActor
    private func chooseFile(_ url: URL, in app: XCUIApplication) {
        let panel = app.sheets.firstMatch
        XCTAssertTrue(panel.waitForExistence(timeout: 15))
        goTo(url, in: app)
        confirm(panel, fallbackTitle: "打开")
        XCTAssertTrue(panel.waitForNonExistence(timeout: 15))
    }

    @MainActor
    private func saveFile(_ url: URL, in app: XCUIApplication) {
        let panel = app.sheets.firstMatch
        XCTAssertTrue(panel.waitForExistence(timeout: 15))
        goTo(url.deletingLastPathComponent(), in: app)
        let field = panel.textFields.firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: 10))
        field.click()
        app.typeKey("a", modifierFlags: .command)
        app.typeText(url.lastPathComponent)
        confirm(panel, fallbackTitle: "保存")
        let written = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            FileManager.default.fileExists(atPath: url.path)
        }, object: nil)
        XCTAssertEqual(XCTWaiter.wait(for: [written], timeout: 25), .completed)
    }

    @MainActor
    private func confirm(_ panel: XCUIElement, fallbackTitle: String) {
        let predicate = NSPredicate(format: "(identifier == 'OKButton' OR label == %@) AND enabled == true", fallbackTitle)
        let button = panel.buttons.matching(predicate).firstMatch
        XCTAssertTrue(button.waitForExistence(timeout: 20), panel.debugDescription)
        button.click()
    }

    @MainActor
    private func attach(_ attachment: XCTAttachment, named name: String) {
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private func writeSyntheticScene(to url: URL, width: Int, height: Int) throws {
        let space = try XCTUnwrap(CGColorSpace(name: CGColorSpace.sRGB))
        let context = try XCTUnwrap(CGContext(
            data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
            space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ))
        // Sky, sun, meadow, warm cabin bands for clear visual grading evaluation.
        context.setFillColor(red: 0.48, green: 0.68, blue: 0.86, alpha: 1)
        context.fill(CGRect(x: 0, y: height / 2, width: width, height: height / 2))
        context.setFillColor(red: 0.96, green: 0.84, blue: 0.42, alpha: 1)
        context.fillEllipse(in: CGRect(x: width / 6, y: (height * 2) / 3, width: 56, height: 56))
        context.setFillColor(red: 0.28, green: 0.56, blue: 0.34, alpha: 1)
        context.fill(CGRect(x: 0, y: 0, width: width, height: height / 2))
        context.setFillColor(red: 0.68, green: 0.36, blue: 0.24, alpha: 1)
        context.fill(CGRect(x: width / 2, y: height / 5, width: width / 3, height: height / 3))
        let image = try XCTUnwrap(context.makeImage())
        let destination = try XCTUnwrap(CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil))
        CGImageDestinationAddImage(destination, image, nil)
        XCTAssertTrue(CGImageDestinationFinalize(destination))
    }
}
