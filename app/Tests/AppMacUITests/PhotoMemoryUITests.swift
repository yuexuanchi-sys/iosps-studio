import AppKit
import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers
import XCTest

final class PhotoMemoryUITests: XCTestCase {
    @MainActor
    func testEmptyStateSaveTwoMemoriesReorderContinueEditMovieHandoffRestartAndAppearances() throws {
        continueAfterFailure = false
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let inputs = root.appendingPathComponent("Inputs", isDirectory: true)
        let outputs = root.appendingPathComponent("Outputs", isDirectory: true)
        let localData = root.appendingPathComponent("Local", isDirectory: true)
        try FileManager.default.createDirectory(at: inputs, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: outputs, withIntermediateDirectories: false)
        defer { try? FileManager.default.removeItem(at: root) }

        let photoA = inputs.appendingPathComponent("sunset.png")
        let photoB = inputs.appendingPathComponent("garden.png")
        try writeSyntheticPNG(to: photoA, width: 320, height: 240, primary: (0.85, 0.36, 0.22), accent: (0.96, 0.78, 0.28))
        try writeSyntheticPNG(to: photoB, width: 320, height: 240, primary: (0.20, 0.56, 0.38), accent: (0.30, 0.76, 0.85))
        let originalBytes = try [photoA, photoB].map { try Data(contentsOf: $0) }

        let app = XCUIApplication()
        app.launchEnvironment["IOSPS_TEST_VIDEO_DIRECTORY"] = localData.path
        app.launchEnvironment["IOSPS_TEST_APPEARANCE"] = "light"
        app.launchEnvironment["IOSPS_TEST_LARGE_TEXT"] = "0"
        app.launch()
        defer {
            if app.state != .notRunning {
                app.typeKey("q", modifierFlags: .command)
                _ = app.wait(for: .notRunning, timeout: 5)
            }
        }

        // 1. Empty state in Memories offers "去修图" and routes directly to Photo Editor.
        let window = openMemories(in: app)
        let goEdit = app.buttons["memories-go-edit"]
        XCTAssertTrue(goEdit.waitForExistence(timeout: 10))
        attach(XCTAttachment(screenshot: window.screenshot()), named: "memories-empty")
        goEdit.click()
        XCTAssertTrue(app.staticTexts["photo-editor-title"].waitForExistence(timeout: 10))

        // 2. Edit and save Photo A (2:1 crop -> 320 x 160).
        app.buttons["photo-editor-select"].click()
        chooseFile(photoA, in: app)
        expectEditorSize(app, width: 320, height: 240)
        app.buttons["photo-editor-crop-wide"].click()
        let applyCrop = app.buttons["photo-editor-apply-crop"]
        XCTAssertTrue(applyCrop.waitForExistence(timeout: 8))
        applyCrop.click()
        expectEditorSize(app, width: 320, height: 160)
        let projectA = outputs.appendingPathComponent("memory-a.comp", isDirectory: true)
        app.buttons["photo-editor-save"].click()
        saveFile(projectA, in: app)
        waitForEditorSaved(app)

        // 3. Edit and save Photo B (1:1 crop -> 240 x 240).
        app.buttons["photo-editor-select"].click()
        chooseFile(photoB, in: app)
        expectEditorSize(app, width: 320, height: 240)
        app.buttons["photo-editor-crop-square"].click()
        XCTAssertTrue(applyCrop.waitForExistence(timeout: 8))
        applyCrop.click()
        expectEditorSize(app, width: 240, height: 240)
        let projectB = outputs.appendingPathComponent("memory-b.comp", isDirectory: true)
        app.buttons["photo-editor-save"].click()
        saveFile(projectB, in: app)
        waitForEditorSaved(app)

        // 4. Open Memories -> verify 2 entries in reverse chronological order (memory-b before memory-a).
        switchToMemories(in: window, app: app)
        let card0 = app.buttons["memory-card-0"]
        let card1 = app.buttons["memory-card-1"]
        XCTAssertTrue(card0.waitForExistence(timeout: 15))
        XCTAssertTrue(card1.waitForExistence(timeout: 10))
        XCTAssertTrue(card0.label.contains("memory-b"), card0.debugDescription)
        XCTAssertTrue(card1.label.contains("memory-a"), card1.debugDescription)
        attach(XCTAttachment(screenshot: window.screenshot()), named: "memories-light")

        // 5. Open detail for memory-a, capture detail, press Esc to return, then open again to continue editing.
        card1.click()
        let detailTitle = app.staticTexts["memories-detail-title"]
        XCTAssertTrue(detailTitle.waitForExistence(timeout: 10))
        XCTAssertTrue(textContains("memory-a", in: detailTitle), detailTitle.debugDescription)
        attach(XCTAttachment(screenshot: window.screenshot()), named: "memories-detail")

        app.typeKey(.escape, modifierFlags: [])
        XCTAssertTrue(card1.waitForExistence(timeout: 10))

        card1.click()
        let continueEdit = app.buttons["memories-continue-edit"]
        XCTAssertTrue(continueEdit.waitForExistence(timeout: 10))
        continueEdit.click()
        expectEditorSize(app, width: 320, height: 160)

        // 6. Re-edit memory-a (rotate 90 -> 160 x 320) and save -> moves memory-a to top without duplicate.
        let rotateButton = app.buttons["photo-editor-rotate"]
        waitUntilEnabled(rotateButton)
        rotateButton.click()
        expectEditorSize(app, width: 160, height: 320)
        let saveButton = app.buttons["photo-editor-save"]
        waitUntilEnabled(saveButton)
        saveButton.click()
        waitForEditorSaved(app)

        switchToMemories(in: window, app: app)
        let movedPredicate = NSPredicate(format: "label CONTAINS %@", "memory-a")
        let movedExpectation = XCTNSPredicateExpectation(predicate: movedPredicate, object: card0)
        XCTAssertEqual(XCTWaiter.wait(for: [movedExpectation], timeout: 15), .completed, card0.debugDescription)
        XCTAssertTrue(card1.label.contains("memory-b"), card1.debugDescription)
        XCTAssertFalse(app.buttons["memory-card-2"].exists)

        // 7. Select memory-a and hand off to Photo Movie ("做短片").
        card0.click()
        let makeMovie = app.buttons["memories-make-movie"]
        XCTAssertTrue(makeMovie.waitForExistence(timeout: 10))
        makeMovie.click()
        XCTAssertTrue(app.staticTexts["photo-movie-title"].waitForExistence(timeout: 10))
        let moviePhoto0 = app.buttons["photo-movie-photo-0"]
        XCTAssertTrue(moviePhoto0.waitForExistence(timeout: 10))
        XCTAssertTrue(moviePhoto0.label.contains("memory-a"), moviePhoto0.debugDescription)

        // 8. Graceful quit and relaunch in dark mode -> verify persisted timeline order.
        app.typeKey("q", modifierFlags: .command)
        XCTAssertTrue(app.wait(for: .notRunning, timeout: 10))

        app.launchEnvironment["IOSPS_TEST_APPEARANCE"] = "dark"
        app.launchEnvironment["IOSPS_TEST_LARGE_TEXT"] = "0"
        app.launch()
        let darkWindow = openMemories(in: app)
        XCTAssertTrue(app.buttons["memory-card-0"].waitForExistence(timeout: 15))
        XCTAssertTrue(app.buttons["memory-card-0"].label.contains("memory-a"))
        XCTAssertTrue(app.buttons["memory-card-1"].label.contains("memory-b"))
        attach(XCTAttachment(screenshot: darkWindow.screenshot()), named: "memories-dark")
        app.typeKey("q", modifierFlags: .command)
        XCTAssertTrue(app.wait(for: .notRunning, timeout: 10))

        // 9. Relaunch in large-text light mode -> capture large-text appearance screenshot.
        app.launchEnvironment["IOSPS_TEST_APPEARANCE"] = "light"
        app.launchEnvironment["IOSPS_TEST_LARGE_TEXT"] = "1"
        app.launch()
        let largeWindow = openMemories(in: app)
        XCTAssertTrue(app.buttons["memory-card-0"].waitForExistence(timeout: 15))
        attach(XCTAttachment(screenshot: largeWindow.screenshot()), named: "memories-large")

        XCTAssertEqual(try [photoA, photoB].map { try Data(contentsOf: $0) }, originalBytes)
        app.typeKey("q", modifierFlags: .command)
        XCTAssertTrue(app.wait(for: .notRunning, timeout: 10))
    }

    @MainActor
    private func openMemories(in app: XCUIApplication) -> XCUIElement {
        let window = app.windows["IOSPS"]
        if !window.waitForExistence(timeout: 5) {
            app.typeKey("n", modifierFlags: .command)
        }
        XCTAssertTrue(app.staticTexts["birthday-title"].waitForExistence(timeout: 15), app.debugDescription)
        switchToMemories(in: window, app: app)
        return window
    }

    @MainActor
    private func switchToMemories(in window: XCUIElement, app: XCUIApplication) {
        let entry = window.toolbars.buttons.matching(identifier: "memories-entry").firstMatch
        XCTAssertTrue(entry.waitForExistence(timeout: 5), "Main toolbar must expose memories-entry.")
        entry.click()
        XCTAssertTrue(app.staticTexts["memories-title"].waitForExistence(timeout: 10))
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
    private func textContains(_ expected: String, in element: XCUIElement) -> Bool {
        element.label.contains(expected) || (element.value as? String)?.contains(expected) == true
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

    private func writeSyntheticPNG(
        to url: URL,
        width: Int,
        height: Int,
        primary: (CGFloat, CGFloat, CGFloat),
        accent: (CGFloat, CGFloat, CGFloat)
    ) throws {
        let space = try XCTUnwrap(CGColorSpace(name: CGColorSpace.sRGB))
        let context = try XCTUnwrap(CGContext(
            data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
            space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ))
        context.setFillColor(red: primary.0, green: primary.1, blue: primary.2, alpha: 1)
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        context.setFillColor(red: accent.0, green: accent.1, blue: accent.2, alpha: 1)
        context.fill(CGRect(x: width / 3, y: height / 4, width: width / 2, height: height / 2))
        let image = try XCTUnwrap(context.makeImage())
        let destination = try XCTUnwrap(CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil))
        CGImageDestinationAddImage(destination, image, nil)
        XCTAssertTrue(CGImageDestinationFinalize(destination))
    }
}
