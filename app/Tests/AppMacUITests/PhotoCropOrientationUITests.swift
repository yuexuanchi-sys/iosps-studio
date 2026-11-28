import AppKit
import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers
import XCTest

final class PhotoCropOrientationUITests: XCTestCase {
    @MainActor
    func testCropAspectPresetsCustomRatioCancelCommitAndFourWayOrientationWithScreenshots() throws {
        continueAfterFailure = false
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let inputs = root.appendingPathComponent("Inputs", isDirectory: true)
        let outputs = root.appendingPathComponent("Outputs", isDirectory: true)
        let localData = root.appendingPathComponent("Local", isDirectory: true)
        try FileManager.default.createDirectory(at: inputs, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: outputs, withIntermediateDirectories: false)
        defer { try? FileManager.default.removeItem(at: root) }

        let source = inputs.appendingPathComponent("quadrants.png")
        try writeFourQuadrantPNG(to: source, width: 400, height: 300)
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
        expectEditorSize(app, width: 400, height: 300)

        // 1. Live crop aspect switching: 4:3 -> 16:9 (400 x 225), capture crop overlay in light mode, then cancel.
        app.buttons["photo-editor-crop-4-3"].click()
        expectCropPreviewSize(app, width: 400, height: 300)
        app.buttons["photo-editor-crop-16-9"].click()
        expectCropPreviewSize(app, width: 400, height: 225)
        attach(XCTAttachment(screenshot: window.screenshot()), named: "crop-overlay-light")

        app.buttons["photo-editor-cancel-crop"].click()
        expectEditorSize(app, width: 400, height: 300)
        expectHistoryCount(app, undo: 0, redo: 0)

        // 2. Custom ratio 5:4 (375 x 300) and apply crop.
        app.buttons["photo-editor-crop-3-4"].click()
        expectCropPreviewSize(app, width: 225, height: 300)
        let customField = app.textFields["photo-editor-crop-custom-input"]
        XCTAssertTrue(customField.waitForExistence(timeout: 8))
        customField.click()
        app.typeKey("a", modifierFlags: .command)
        app.typeText("5:4")
        app.buttons["photo-editor-crop-custom-apply"].click()
        expectCropPreviewSize(app, width: 375, height: 300)

        app.buttons["photo-editor-apply-crop"].click()
        expectEditorSize(app, width: 375, height: 300)

        // 3. Four-way orientation controls: rotate left 90° (300 x 375), flip vertical, flip horizontal, undo & redo.
        let rotateLeft = app.buttons["photo-editor-rotate-left"]
        waitUntilEnabled(rotateLeft)
        rotateLeft.click()
        expectEditorSize(app, width: 300, height: 375)

        let flipV = app.buttons["photo-editor-flip-v"]
        waitUntilEnabled(flipV)
        flipV.click()
        let flipH = app.buttons["photo-editor-flip-h"]
        waitUntilEnabled(flipH)
        flipH.click()
        expectHistoryCount(app, undo: 4, redo: 0)

        app.buttons["photo-editor-undo"].click()
        expectHistoryCount(app, undo: 3, redo: 1)
        app.buttons["photo-editor-redo"].click()
        expectHistoryCount(app, undo: 4, redo: 0)

        // 4. Save project, graceful quit, and relaunch in dark mode to verify draft/orientation screenshot.
        let savedProject = outputs.appendingPathComponent("cropped-oriented.comp", isDirectory: true)
        app.buttons["photo-editor-save"].click()
        saveFile(savedProject, in: app)
        waitForEditorSaved(app)

        app.typeKey("q", modifierFlags: .command)
        XCTAssertTrue(app.wait(for: .notRunning, timeout: 10))

        app.launchEnvironment["IOSPS_TEST_APPEARANCE"] = "dark"
        app.launch()
        let darkWindow = openPhotoEditor(in: app)
        expectEditorSize(app, width: 300, height: 375)
        attach(XCTAttachment(screenshot: darkWindow.screenshot()), named: "crop-oriented-dark")

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
        XCTAssertTrue(label.waitForExistence(timeout: 12), "Missing pixel size \(expected)")
        let match = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "label == %@ OR value == %@", expected, expected),
            object: label
        )
        XCTAssertEqual(XCTWaiter.wait(for: [match], timeout: 10), .completed, label.debugDescription)
    }

    @MainActor
    private func expectCropPreviewSize(_ app: XCUIApplication, width: Int, height: Int) {
        let label = app.staticTexts["photo-editor-crop-size"]
        let expected = "裁剪区域 \(width) × \(height) 像素"
        XCTAssertTrue(label.waitForExistence(timeout: 10), "Missing crop size \(expected)")
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
        XCTAssertTrue(label.waitForExistence(timeout: 10))
        let match = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "label == %@ OR value == %@", expected, expected),
            object: label
        )
        XCTAssertEqual(XCTWaiter.wait(for: [match], timeout: 10), .completed, label.debugDescription)
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

    private func writeFourQuadrantPNG(to url: URL, width: Int, height: Int) throws {
        let space = try XCTUnwrap(CGColorSpace(name: CGColorSpace.sRGB))
        let context = try XCTUnwrap(CGContext(
            data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
            space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ))
        let halfW = width / 2
        let halfH = height / 2
        context.setFillColor(red: 0.86, green: 0.20, blue: 0.20, alpha: 1)
        context.fill(CGRect(x: 0, y: halfH, width: halfW, height: height - halfH))
        context.setFillColor(red: 0.18, green: 0.72, blue: 0.30, alpha: 1)
        context.fill(CGRect(x: halfW, y: halfH, width: width - halfW, height: height - halfH))
        context.setFillColor(red: 0.18, green: 0.36, blue: 0.86, alpha: 1)
        context.fill(CGRect(x: 0, y: 0, width: halfW, height: halfH))
        context.setFillColor(red: 0.92, green: 0.82, blue: 0.20, alpha: 1)
        context.fill(CGRect(x: halfW, y: 0, width: width - halfW, height: halfH))
        let image = try XCTUnwrap(context.makeImage())
        let destination = try XCTUnwrap(CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil))
        CGImageDestinationAddImage(destination, image, nil)
        XCTAssertTrue(CGImageDestinationFinalize(destination))
    }
}
