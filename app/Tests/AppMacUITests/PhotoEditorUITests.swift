import AppKit
import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers
import XCTest

final class PhotoEditorUITests: XCTestCase {
    @MainActor
    func testToolbarEntryEditCrossModulePersistSaveRestartAndAppearanceScreenshots() throws {
        continueAfterFailure = false
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let inputs = root.appendingPathComponent("Inputs", isDirectory: true)
        let outputs = root.appendingPathComponent("Outputs", isDirectory: true)
        let localData = root.appendingPathComponent("Local", isDirectory: true)
        try FileManager.default.createDirectory(at: inputs, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: outputs, withIntermediateDirectories: false)
        defer { try? FileManager.default.removeItem(at: root) }

        let source = inputs.appendingPathComponent("portrait.png")
        try writeSyntheticPNG(to: source, width: 320, height: 240)
        let originalBytes = try Data(contentsOf: source)

        // Phase 1: Launch in light mode, open Photo Editor, import, crop, rotate, undo/redo, switch module, save project.
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
        expectSize(app, width: 320, height: 240)

        // 2:1 crop -> 320 x 160, then 90-degree rotate -> 160 x 320, then undo/redo.
        app.buttons["photo-editor-crop-wide"].click()
        let applyCrop = app.buttons["photo-editor-apply-crop"]
        XCTAssertTrue(applyCrop.waitForExistence(timeout: 8))
        applyCrop.click()
        expectSize(app, width: 320, height: 160)

        app.buttons["photo-editor-rotate"].click()
        expectSize(app, width: 160, height: 320)

        app.buttons["photo-editor-undo"].click()
        expectSize(app, width: 320, height: 160)
        app.buttons["photo-editor-redo"].click()
        expectSize(app, width: 160, height: 320)

        attach(XCTAttachment(screenshot: window.screenshot()), named: "photo-editor-light")

        // Switch away to Birthday Home and return; live editing session must be preserved.
        let entry = window.toolbars.buttons.matching(identifier: "photo-editor-entry").firstMatch
        entry.click()
        XCTAssertTrue(app.staticTexts["birthday-title"].waitForExistence(timeout: 10))
        entry.click()
        expectSize(app, width: 160, height: 320)

        // Save project package (.comp) via NSSavePanel.
        let savedProject = outputs.appendingPathComponent("retouched.comp", isDirectory: true)
        app.buttons["photo-editor-save"].click()
        saveFile(savedProject, in: app)
        let savedStatus = app.staticTexts.matching(NSPredicate(
            format: "identifier == %@ AND (label CONTAINS %@ OR value CONTAINS %@)",
            "photo-editor-status", "工程已保存", "工程已保存"
        )).firstMatch
        XCTAssertTrue(savedStatus.waitForExistence(timeout: 15))

        // Perform one extra unsaved rotation (320 x 160), then gracefully quit with Cmd+Q so auto-draft flushes.
        app.buttons["photo-editor-rotate"].click()
        expectSize(app, width: 320, height: 160)
        app.typeKey("q", modifierFlags: .command)
        XCTAssertTrue(app.wait(for: .notRunning, timeout: 10))

        // Phase 2: Relaunch in dark mode; verify auto-draft restored (320 x 160) and reopening saved project restores 160 x 320.
        app.launchEnvironment["IOSPS_TEST_APPEARANCE"] = "dark"
        app.launch()
        let reopenedWindow = openPhotoEditor(in: app)
        expectSize(app, width: 320, height: 160)
        XCTAssertTrue(app.staticTexts["photo-editor-draft-badge"].waitForExistence(timeout: 8))
        attach(XCTAttachment(screenshot: reopenedWindow.screenshot()), named: "photo-editor-dark-draft")

        app.buttons["photo-editor-open"].click()
        chooseFile(savedProject, in: app)
        expectSize(app, width: 160, height: 320)
        attach(XCTAttachment(screenshot: reopenedWindow.screenshot()), named: "photo-editor-reopened")

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
        XCTAssertTrue(entry.waitForExistence(timeout: 5), "Main window toolbar must provide photo-editor-entry.")
        entry.click()
        XCTAssertTrue(app.staticTexts["photo-editor-title"].waitForExistence(timeout: 10))
        return window
    }

    @MainActor
    private func expectSize(_ app: XCUIApplication, width: Int, height: Int) {
        let label = app.staticTexts["photo-editor-pixel-size"]
        let expected = "\(width) × \(height) 像素"
        XCTAssertTrue(label.waitForExistence(timeout: 12), "Missing pixel size \(expected)")
        let match = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "label == %@ OR value == %@", expected, expected),
            object: label
        )
        XCTAssertEqual(XCTWaiter.wait(for: [match], timeout: 10), .completed, "Expected \(expected), got \(label.debugDescription)")
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

    private func writeSyntheticPNG(to url: URL, width: Int, height: Int) throws {
        let space = try XCTUnwrap(CGColorSpace(name: CGColorSpace.sRGB))
        let context = try XCTUnwrap(CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: space,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ))
        context.clear(CGRect(x: 0, y: 0, width: width, height: height))
        context.setFillColor(red: 0.25, green: 0.48, blue: 0.80, alpha: 1)
        context.fill(CGRect(x: 16, y: 16, width: width - 32, height: height - 32))
        context.setFillColor(red: 0.90, green: 0.56, blue: 0.24, alpha: 1)
        context.fill(CGRect(x: width / 2, y: 24, width: width / 3, height: height / 2))
        let image = try XCTUnwrap(context.makeImage())
        let destination = try XCTUnwrap(CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil))
        CGImageDestinationAddImage(destination, image, nil)
        XCTAssertTrue(CGImageDestinationFinalize(destination))
    }
}
