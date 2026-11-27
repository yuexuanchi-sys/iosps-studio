import Foundation
import UniformTypeIdentifiers
import XCTest

final class VideoEditorUITests: XCTestCase {
    @MainActor
    func testAppToolbarOpensEditor() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launch()
        openEditor(in: app)
        app.typeKey("q", modifierFlags: .command)
        XCTAssertTrue(app.wait(for: .notRunning, timeout: 10))
    }

    @MainActor
    func testFinderImportTrimReorderSaveReopenAndExport() throws {
        continueAfterFailure = false
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let inputs = root.appendingPathComponent("Inputs")
        let outputs = root.appendingPathComponent("Outputs")
        try FileManager.default.createDirectory(at: inputs, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: outputs, withIntermediateDirectories: false)
        defer { try? FileManager.default.removeItem(at: root) }
        let fixtures = Bundle(for: Self.self)
        for (name, ext) in [("source-a", "mov"), ("source-b", "mp4")] {
            let source = try XCTUnwrap(fixtures.url(forResource: name, withExtension: ext,
                                                   subdirectory: "VideoEditorFixtures"))
            try FileManager.default.copyItem(at: source, to: inputs.appendingPathComponent(source.lastPathComponent))
        }
        try Data("Synthetic unreadable movie".utf8).write(to: inputs.appendingPathComponent("corrupt.mov"))
        let app = XCUIApplication()
        app.launchEnvironment["IOSPS_TEST_VIDEO_DIRECTORY"] = root.appendingPathComponent("Local").path
        app.launch()
        defer { app.terminate() }
        openEditor(in: app)

        let first = app.buttons["video-clip-0"]
        let second = app.buttons["video-clip-1"]
        app.buttons["video-import"].click()
        let picker = app.sheets["open-panel"]
        XCTAssertTrue(picker.waitForExistence(timeout: 5))
        app.typeKey(.escape, modifierFlags: [])
        XCTAssertTrue(picker.waitForNonExistence(timeout: 5))
        XCTAssertFalse(first.exists)

        app.buttons["video-import"].click()
        choose(inputs.appendingPathComponent("source-a.mov"), in: app)
        XCTAssertTrue(first.waitForExistence(timeout: 15))
        app.buttons["video-import"].click()
        choose(inputs.appendingPathComponent("source-b.mp4"), in: app)
        XCTAssertTrue(second.waitForExistence(timeout: 15))
        XCTAssertTrue(first.label.contains("source-a.mov"), first.debugDescription)
        XCTAssertTrue(second.label.contains("source-b.mp4"), second.debugDescription)
        app.buttons["video-import"].click()
        choose(inputs.appendingPathComponent("corrupt.mov"), in: app)
        let issue = app.staticTexts.matching(NSPredicate(
            format: "label CONTAINS %@ OR value CONTAINS %@", "corrupt.mov", "corrupt.mov"
        )).firstMatch
        XCTAssertTrue(issue.waitForExistence(timeout: 10))
        XCTAssertTrue(second.exists)
        app.buttons["video-import"].click()
        XCTAssertTrue(picker.waitForExistence(timeout: 5))
        app.typeKey(.escape, modifierFlags: [])
        XCTAssertTrue(picker.waitForNonExistence(timeout: 5))
        XCTAssertTrue(first.exists && second.exists)

        first.click()
        replaceText(in: app.textFields["video-trim-end"], with: "30", app: app)
        app.buttons["video-trim"].click()
        second.click()
        replaceText(in: app.textFields["video-trim-start"], with: "30", app: app)
        app.buttons["video-trim"].click()
        app.buttons["video-move-up"].click()
        XCTAssertTrue(first.label.contains("source-b.mp4"), first.debugDescription)
        app.buttons["video-undo"].click()
        XCTAssertTrue(first.label.contains("source-a.mov"))
        app.buttons["video-redo"].click()
        XCTAssertTrue(first.label.contains("source-b.mp4"))

        let project = outputs.appendingPathComponent("edited.iosps.json")
        app.buttons["video-save"].click()
        save(project, in: app)
        let previousProject = try Data(contentsOf: project)
        app.buttons["video-save"].click()
        let cancelledSave = app.sheets.firstMatch
        XCTAssertTrue(cancelledSave.waitForExistence(timeout: 5))
        app.typeKey(.escape, modifierFlags: [])
        XCTAssertTrue(cancelledSave.waitForNonExistence(timeout: 5))
        XCTAssertEqual(try Data(contentsOf: project), previousProject)

        app.typeKey("q", modifierFlags: .command)
        XCTAssertTrue(app.wait(for: .notRunning, timeout: 10))
        app.launch()
        let window = app.windows["IOSPS"]
        if !window.waitForExistence(timeout: 3) {
            app.typeKey("n", modifierFlags: .command)
        }
        XCTAssertTrue(window.waitForExistence(timeout: 5), app.debugDescription)
        if !app.buttons["video-import"].exists {
            openEditor(in: app)
        }
        XCTAssertFalse(first.exists)
        app.buttons["video-open"].click()
        choose(project, in: app)
        XCTAssertTrue(second.waitForExistence(timeout: 15))
        XCTAssertTrue(first.label.contains("source-b.mp4"))
        XCTAssertTrue(second.label.contains("source-a.mov"))
        let previewPrompt = app.staticTexts["预览当前顺序与裁切"]
        XCTAssertTrue(previewPrompt.exists)
        app.buttons["video-preview"].click()
        XCTAssertTrue(previewPrompt.waitForNonExistence(timeout: 5), "The preview must replace its prompt.")
        XCTAssertEqual(app.state, .runningForeground, "The App must keep running after playback starts.")
        attach(XCTAttachment(screenshot: window.screenshot()), named: "video-editor-reopened")

        let movie = outputs.appendingPathComponent("edited.mp4")
        app.buttons["video-export"].click()
        save(movie, in: app)
        let exported = app.staticTexts.matching(NSPredicate(
            format: "identifier == %@ AND (label CONTAINS %@ OR value CONTAINS %@)",
            "video-status", "MP4 已导出", "MP4 已导出"
        )).firstMatch
        XCTAssertTrue(exported.waitForExistence(timeout: 20))
        attach(XCTAttachment(data: try Data(contentsOf: movie), uniformTypeIdentifier: UTType.mpeg4Movie.identifier),
               named: "video-editor-exported")
        attach(XCTAttachment(data: previousProject, uniformTypeIdentifier: UTType.json.identifier),
               named: "video-editor-project")
    }

    @MainActor
    private func openEditor(in app: XCUIApplication) {
        XCTAssertTrue(app.staticTexts["birthday-title"].waitForExistence(timeout: 10), app.debugDescription)
        let entry = app.windows["IOSPS"].toolbars.buttons.matching(identifier: "video-editor-entry").firstMatch
        XCTAssertTrue(entry.waitForExistence(timeout: 3), "The normal App window should provide a video editor entry.")
        entry.click()
        XCTAssertTrue(app.buttons["video-import"].waitForExistence(timeout: 5))
    }

    @MainActor
    private func goTo(_ url: URL, in app: XCUIApplication) {
        app.typeKey("g", modifierFlags: [.command, .shift])
        app.typeText(url.path)
        app.typeKey(.return, modifierFlags: [])
    }

    @MainActor
    private func choose(_ url: URL, in app: XCUIApplication) {
        let panel = app.sheets["open-panel"]
        XCTAssertTrue(panel.waitForExistence(timeout: 15))
        goTo(url, in: app)
        confirm(panel)
        XCTAssertTrue(panel.waitForNonExistence(timeout: 15))
    }

    @MainActor
    private func replaceText(in element: XCUIElement, with text: String, app: XCUIApplication) {
        XCTAssertTrue(element.waitForExistence(timeout: 10))
        element.click()
        app.typeKey("a", modifierFlags: .command)
        app.typeText(text)
    }

    @MainActor
    private func save(_ url: URL, in app: XCUIApplication) {
        let panel = app.sheets.firstMatch
        XCTAssertTrue(panel.waitForExistence(timeout: 15))
        goTo(url.deletingLastPathComponent(), in: app)
        replaceText(in: panel.textFields.firstMatch, with: url.lastPathComponent, app: app)
        confirm(panel)
        let written = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            FileManager.default.fileExists(atPath: url.path)
        }, object: nil)
        XCTAssertEqual(XCTWaiter.wait(for: [written], timeout: 25), .completed)
    }

    @MainActor
    private func confirm(_ panel: XCUIElement) {
        let button = panel.buttons["OKButton"]
        let enabled = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == true AND enabled == true"), object: button)
        XCTAssertEqual(XCTWaiter.wait(for: [enabled], timeout: 20), .completed, panel.debugDescription)
        button.click()
    }

    @MainActor
    private func attach(_ attachment: XCTAttachment, named name: String) {
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
