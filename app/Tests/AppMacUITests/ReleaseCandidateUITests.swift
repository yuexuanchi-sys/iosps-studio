import AppKit
import CryptoKit
import XCTest

final class ReleaseCandidateUITests: XCTestCase {
    private let root = URL(fileURLWithPath: "/tmp/iosps-ci-self-test", isDirectory: true)
    private let releaseExecutableSHA = "344b4461a3646b21de46bef1b217a3def8355aaed6603a905583672311c6d208"

    @MainActor
    func testSignedReleaseLaunchAndReopen() throws {
        continueAfterFailure = false
        let app = try launchSignedRelease()
        attach(app.windows["IOSPS"].screenshot(), named: "release-birthday-first-launch")

        app.typeKey("q", modifierFlags: .command)
        XCTAssertTrue(app.wait(for: .notRunning, timeout: 10))
        let reopened = try launchSignedRelease()
        let menu = reopened.menuBars.menuBarItems["IOSPS"]
        menu.click()
        menu.menuItems["关于 IOSPS"].click()
        let about = reopened.windows["关于 IOSPS"]
        XCTAssertTrue(about.waitForExistence(timeout: 5))
        XCTAssertTrue(about.staticTexts["许可与致谢"].exists)
        attach(about.screenshot(), named: "release-about-after-reopen")
    }

    @MainActor
    func testCopiesDisplayedLicenseText() throws {
        continueAfterFailure = false
        let app = try launchSignedRelease()
        let menu = app.menuBars.menuBarItems["IOSPS"]
        menu.click()
        menu.menuItems["关于 IOSPS"].click()
        let about = app.windows["关于 IOSPS"]
        XCTAssertTrue(about.waitForExistence(timeout: 5))
        let picker = about.popUpButtons["license-picker"]
        picker.click()
        app.typeKey(.downArrow, modifierFlags: [])
        app.typeKey(.return, modifierFlags: [])
        let text = about.staticTexts["license-text"]
        let selectedLicense = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "value CONTAINS %@", "GitHub, Inc. and contributors"),
            object: text
        )
        XCTAssertEqual(XCTWaiter.wait(for: [selectedLicense], timeout: 5), .completed)

        // The bundled checkout notice begins with a blank line followed by its MIT heading.
        let scrollView = about.scrollViews.firstMatch
        XCTAssertTrue(scrollView.exists)
        let origin = scrollView.coordinate(withNormalizedOffset: CGVector(dx: 0, dy: 0))
        let start = origin.withOffset(CGVector(dx: 1, dy: 26))
        let end = origin.withOffset(CGVector(dx: 180, dy: 26))
        start.click(forDuration: 0.1, thenDragTo: end)
        attach(about.screenshot(), named: "release-license-text-selected")

        let pasteboard = NSPasteboard.general
        let beforeCopy = pasteboard.changeCount
        app.typeKey("c", modifierFlags: .command)
        XCTAssertNotEqual(pasteboard.changeCount, beforeCopy)
        let copied = try XCTUnwrap(pasteboard.string(forType: .string))
        let result = XCTAttachment(string: copied)
        result.name = "release-copied-license-text"
        result.lifetime = .keepAlways
        add(result)
        XCTAssertEqual(copied.trimmingCharacters(in: .whitespacesAndNewlines), "The MIT License (MIT)")
    }

    @MainActor
    func testNativePickerCancellationPreservesResultsAndAllowsRetry() throws {
        continueAfterFailure = false
        let fixtures = fixtures(in: "picker-inputs")
        let app = try openMedia()

        let panel = showPicker(in: app)
        goTo(fixtures[0].deletingLastPathComponent(), in: app)
        namedElement("portrait.jpg", in: panel).click()
        panel.buttons["OKButton"].click()
        assertResult("portrait.jpg", "照片已导入", in: app)
        assertRowCount(1, in: app)
        attach(app.windows["IOSPS"].screenshot(), named: "release-picker-first-import")

        _ = showPicker(in: app)
        attach(app.screenshot(), named: "release-native-open-panel")
        app.typeKey(XCUIKeyboardKey.escape.rawValue, modifierFlags: [])
        XCTAssertTrue(panel.waitForNonExistence(timeout: 5))
        assertResult("portrait.jpg", "照片已导入", in: app)
        assertRowCount(1, in: app)
        attach(app.windows["IOSPS"].screenshot(), named: "release-picker-cancel-keeps-result")

        let retry = showPicker(in: app)
        goTo(fixtures[0].deletingLastPathComponent(), in: app)
        namedElement("portrait.jpg", in: retry).click()
        app.typeKey("a", modifierFlags: .command)
        retry.buttons["OKButton"].click()
        for (number, file) in fixtures.enumerated() {
            assertResult(file.lastPathComponent, number < 3 ? "照片已导入" : "视频已导入", in: app)
        }
        assertRowCount(6, in: app)
        attach(app.windows["IOSPS"].screenshot(), named: "release-picker-five-formats")

        let toolbarButton = mediaToolbarButton(in: app)
        toolbarButton.click()
        XCTAssertTrue(app.staticTexts["birthday-title"].waitForExistence(timeout: 5))
        toolbarButton.click()
        assertResult("portrait.jpg", "照片已导入", in: app)
        assertResult("source-b.mp4", "视频已导入", in: app)
        assertRowCount(6, in: app)
    }

    @MainActor
    func testFinderDragWithReadFailureAndRetry() throws {
        continueAfterFailure = false
        let sources = fixtures(in: "finder-inputs")
        let invalid = sources[0].deletingLastPathComponent().appending(path: "broken.png")
        let unsupported = invalid.deletingLastPathComponent().appending(path: "notes.txt")
        let app = try openMedia()

        try dropFromFinder(sources + [invalid, unsupported], into: app, screenshot: "release-finder-selected-files")
        assertResult("broken.png", "无法解码媒体", in: app)
        assertResult("notes.txt", "文件格式不受支持", in: app)
        for (number, file) in sources.enumerated() {
            assertResult(file.lastPathComponent, number < 3 ? "照片已导入" : "视频已导入", in: app)
        }
        assertRowCount(7, in: app)
        app.activate()
        attach(app.windows["IOSPS"].screenshot(), named: "release-drop-mixed-results")

        let denied = root.appending(path: "permission-input/denied.png")
        try dropFromFinder([denied], into: app, screenshot: nil)
        let failed = assertResult("denied.png", "无法读取文件", in: app)
        assertRowCount(8, in: app)
        app.activate()
        revealResult(failed, in: app)
        attach(app.windows["IOSPS"].screenshot(), named: "release-drop-permission-error")

        FileHandle.standardOutput.write(Data("IOSPS_SELF_TEST_RESTORE_PERMISSION\n".utf8))
        let restored = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            let attributes = try? FileManager.default.attributesOfItem(atPath: denied.path)
            return (attributes?[.posixPermissions] as? NSNumber)?.intValue == 0o600
        }, object: nil)
        XCTAssertEqual(XCTWaiter.wait(for: [restored], timeout: 15), .completed)
        try dropFromFinder([denied], into: app, screenshot: nil)
        let imported = assertResult("denied.png", "照片已导入", in: app)
        assertRowCount(9, in: app)
        app.activate()
        revealResult(imported, in: app)
        attach(app.windows["IOSPS"].screenshot(), named: "release-drop-permission-retry")
    }

    @MainActor
    private func launchSignedRelease() throws -> XCUIApplication {
        let bundle = root.appending(path: "IOSPS.app", directoryHint: .isDirectory)
        let app = XCUIApplication(url: bundle)
        app.launch()
        XCTAssertTrue(app.staticTexts["birthday-title"].waitForExistence(timeout: 10))

        let executable = try XCTUnwrap(NSRunningApplication.runningApplications(withBundleIdentifier: "org.iosps.birthday")
            .first?.executableURL)
        XCTAssertEqual(executable.resolvingSymlinksInPath(),
                       bundle.appending(path: "Contents/MacOS/IOSPS").resolvingSymlinksInPath())
        let digest = try SHA256.hash(data: Data(contentsOf: executable))
        XCTAssertEqual(digest.map { String(format: "%02x", $0) }.joined(), releaseExecutableSHA)
        print("Running signed candidate: \(executable.path) SHA-256 \(releaseExecutableSHA)")
        print("Test driver application support: \(URL.applicationSupportDirectory.path)")
        return app
    }

    @MainActor
    private func openMedia() throws -> XCUIApplication {
        let app = try launchSignedRelease()
        mediaToolbarButton(in: app).click()
        XCTAssertTrue(app.buttons["media-finder-picker"].waitForExistence(timeout: 5))
        return app
    }

    @MainActor
    private func mediaToolbarButton(in app: XCUIApplication) -> XCUIElement {
        app.windows["IOSPS"].toolbars.buttons.matching(identifier: "shared-media-entry").firstMatch
    }

    @MainActor
    private func showPicker(in app: XCUIApplication) -> XCUIElement {
        app.typeKey("i", modifierFlags: [.command, .shift])
        let panel = app.sheets["open-panel"]
        XCTAssertTrue(panel.waitForExistence(timeout: 5), app.debugDescription)
        return panel
    }

    @MainActor
    private func goTo(_ directory: URL, in app: XCUIApplication) {
        app.typeKey("g", modifierFlags: [.command, .shift])
        app.typeText(directory.path)
        app.typeKey(XCUIKeyboardKey.return.rawValue, modifierFlags: [])
    }

    @MainActor
    private func namedElement(_ label: String, in root: XCUIElement) -> XCUIElement {
        let element = root.descendants(matching: .any)
            .matching(NSPredicate(format: "label == %@ OR value == %@", label, label)).firstMatch
        XCTAssertTrue(element.waitForExistence(timeout: 5), root.debugDescription)
        return element
    }

    @MainActor
    @discardableResult
    private func assertResult(_ filename: String, _ status: String, in app: XCUIApplication) -> XCUIElement {
        let result = NSPredicate(format: "label CONTAINS %@ AND label CONTAINS %@ OR value CONTAINS %@ AND value CONTAINS %@",
                                 filename, status, filename, status)
        let row = app.staticTexts.matching(result).firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 10), app.debugDescription)
        return row
    }

    @MainActor
    private func revealResult(_ row: XCUIElement, in app: XCUIApplication) {
        let list = app.windows["IOSPS"].scrollViews.firstMatch
        if !list.frame.contains(row.frame) {
            list.scroll(byDeltaX: 0, deltaY: -600)
        }
        XCTAssertTrue(list.frame.contains(row.frame), "The result must be visible in the captured window.")
    }

    @MainActor
    private func assertRowCount(_ count: Int, in app: XCUIApplication) {
        let list = app.descendants(matching: .outline).matching(identifier: "导入结果").firstMatch
        XCTAssertEqual(list.descendants(matching: .outlineRow).count, count)
    }

    @MainActor
    private func dropFromFinder(_ sources: [URL], into app: XCUIApplication, screenshot: String?) throws {
        let source = try XCTUnwrap(sources.first)
        let title = source.deletingLastPathComponent().lastPathComponent
        let target = namedElement("将 Finder 中的照片或视频拖到这里", in: app.windows["IOSPS"])
        let targetFrame = target.frame
        NSWorkspace.shared.activateFileViewerSelecting(sources)
        let finder = XCUIApplication(bundleIdentifier: "com.apple.finder")
        let finderWindow = finder.windows[title]
        XCTAssertTrue(finderWindow.waitForExistence(timeout: 10), finder.debugDescription)
        finder.typeKey("2", modifierFlags: .command)

        if finderWindow.frame.intersects(targetFrame) {
            let titleBar = finderWindow.coordinate(withNormalizedOffset: CGVector(dx: 0.4, dy: 0))
                .withOffset(CGVector(dx: 0, dy: 13))
            let offset = targetFrame.maxY + 20 - finderWindow.frame.minY
            titleBar.click(forDuration: 0.2, thenDragTo: titleBar.withOffset(CGVector(dx: 0, dy: offset)))
        }
        XCTAssertFalse(finderWindow.frame.contains(CGPoint(x: targetFrame.midX, y: targetFrame.midY)))
        let sourceRow = namedElement(source.lastPathComponent, in: finderWindow)
        if let screenshot {
            attach(XCUIScreen.main.screenshot(), named: screenshot)
        }
        let start = sourceRow.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        let end = target.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        start.click(forDuration: 0.2, thenDragTo: end)
    }

    private func fixtures(in name: String) -> [URL] {
        let directory = root.appending(path: name, directoryHint: .isDirectory)
        return ["portrait.jpg", "landscape.png", "landscape.heic", "source-a.mov", "source-b.mp4"]
            .map { directory.appending(path: $0) }
    }

    private func attach(_ screenshot: XCUIScreenshot, named name: String) {
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
