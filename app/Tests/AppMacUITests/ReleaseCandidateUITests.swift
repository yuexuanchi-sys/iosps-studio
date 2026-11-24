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
    func testNativePickerCancellationPreservesResultsAndAllowsRetry() throws {
        continueAfterFailure = false
        let fixtures = fixtures(in: "picker-inputs")
        let before = libraryFolders()
        let app = try openMedia()

        let panel = showPicker(in: app)
        goTo(fixtures[0].deletingLastPathComponent(), in: app)
        namedElement("portrait.jpg", in: panel).click()
        panel.buttons["OKButton"].click()
        assertResult("portrait.jpg", "照片已导入", in: app)
        let afterOne = libraryFolders().subtracting(before)
        XCTAssertEqual(afterOne.count, 1)
        attach(app.windows["IOSPS"].screenshot(), named: "release-picker-first-import")

        _ = showPicker(in: app)
        attach(app.screenshot(), named: "release-native-open-panel")
        app.typeKey(XCUIKeyboardKey.escape.rawValue, modifierFlags: [])
        XCTAssertTrue(panel.waitForNonExistence(timeout: 5))
        assertResult("portrait.jpg", "照片已导入", in: app)
        XCTAssertEqual(libraryFolders().subtracting(before), afterOne)
        attach(app.windows["IOSPS"].screenshot(), named: "release-picker-cancel-keeps-result")

        let retry = showPicker(in: app)
        goTo(fixtures[0].deletingLastPathComponent(), in: app)
        namedElement("portrait.jpg", in: retry).click()
        app.typeKey("a", modifierFlags: .command)
        retry.buttons["OKButton"].click()
        for (number, file) in fixtures.enumerated() {
            assertResult(file.lastPathComponent, number < 3 ? "照片已导入" : "视频已导入", in: app)
        }
        try assertPublishedCopies(of: fixtures, excluding: before.union(afterOne))
        attach(app.windows["IOSPS"].screenshot(), named: "release-picker-five-formats")

        let toolbarButton = mediaToolbarButton(in: app)
        toolbarButton.click()
        XCTAssertTrue(app.staticTexts["birthday-title"].waitForExistence(timeout: 5))
        toolbarButton.click()
        assertResult("portrait.jpg", "照片已导入", in: app)
        assertResult("source-b.mp4", "视频已导入", in: app)
    }

    @MainActor
    func testFinderDragWithReadFailureAndRetry() throws {
        continueAfterFailure = false
        let sources = fixtures(in: "finder-inputs")
        let invalid = sources[0].deletingLastPathComponent().appending(path: "broken.png")
        let unsupported = invalid.deletingLastPathComponent().appending(path: "notes.txt")
        let before = libraryFolders()
        let app = try openMedia()

        try dropFromFinder(sources + [invalid, unsupported], into: app, screenshot: "release-finder-selected-files")
        assertResult("broken.png", "无法解码媒体", in: app)
        assertResult("notes.txt", "文件格式不受支持", in: app)
        for (number, file) in sources.enumerated() {
            assertResult(file.lastPathComponent, number < 3 ? "照片已导入" : "视频已导入", in: app)
        }
        try assertPublishedCopies(of: sources, excluding: before)
        app.activate()
        attach(app.windows["IOSPS"].screenshot(), named: "release-drop-mixed-results")

        let permissionDirectory = root.appending(path: "permission-input", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: permissionDirectory, withIntermediateDirectories: false)
        let denied = permissionDirectory.appending(path: "denied.png")
        try FileManager.default.copyItem(at: sources[1], to: denied)
        try FileManager.default.setAttributes([.posixPermissions: 0o000], ofItemAtPath: denied.path)
        defer { try? FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: denied.path) }
        let beforeDenied = libraryFolders()
        try dropFromFinder([denied], into: app, screenshot: nil)
        assertResult("denied.png", "无法读取文件", in: app)
        XCTAssertEqual(libraryFolders(), beforeDenied)
        app.activate()
        attach(app.windows["IOSPS"].screenshot(), named: "release-drop-permission-error")

        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: denied.path)
        try dropFromFinder([denied], into: app, screenshot: nil)
        assertResult("denied.png", "照片已导入", in: app)
        try assertPublishedCopies(of: [denied], excluding: beforeDenied)
        app.activate()
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
    private func assertResult(_ filename: String, _ status: String, in app: XCUIApplication) {
        let row = app.descendants(matching: .any)
            .matching(NSPredicate(format: "label CONTAINS %@ AND label CONTAINS %@", filename, status)).firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 10), app.debugDescription)
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

    private func libraryFolders() -> Set<URL> {
        let directory = FileManager.default.homeDirectoryForCurrentUser
            .appending(path: "Library/Application Support/org.iosps.birthday/Media", directoryHint: .isDirectory)
        let contents = (try? FileManager.default.contentsOfDirectory(at: directory,
                                                                    includingPropertiesForKeys: nil,
                                                                    options: .skipsHiddenFiles)) ?? []
        return Set(contents.filter { UUID(uuidString: $0.lastPathComponent) != nil })
    }

    private func assertPublishedCopies(of sources: [URL], excluding previous: Set<URL>) throws {
        let newFolders = libraryFolders().subtracting(previous)
        XCTAssertEqual(newFolders.count, sources.count)
        for source in sources {
            let data = try Data(contentsOf: source)
            let original = "original." + source.pathExtension
            let matching = newFolders.filter { folder in
                (try? Data(contentsOf: folder.appending(path: original))) == data
            }
            let folder = try XCTUnwrap(matching.first)
            XCTAssertEqual(matching.count, 1)
            XCTAssertTrue(FileManager.default.fileExists(atPath: folder.appending(path: "preview.png").path))
        }
    }

    private func attach(_ screenshot: XCUIScreenshot, named name: String) {
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
