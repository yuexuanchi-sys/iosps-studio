import Foundation
import XCTest

final class BirthdayCelebrationUITests: XCTestCase {
    @MainActor
    func testBirthdayFirstLaunchSkipReopenAndReplay() throws {
        continueAfterFailure = false
        let fixture = try makeFixture()
        defer { try? FileManager.default.removeItem(at: fixture) }
        let app = launch(fixture, on: "2025-02-28", reduceMotion: true)
        let celebration = app.windows["生日祝福"]
        let skip = app.buttons["birthday-celebration-static-close"]
        XCTAssertTrue(skip.waitForExistence(timeout: 10), "A leap-day birthday should open a static greeting on February 28.")
        XCTAssertTrue(celebration.exists)
        XCTAssertGreaterThan(celebration.frame.width, 720)
        capture(celebration, named: "birthday-celebration-static")
        skip.click()
        XCTAssertTrue(skip.waitForNonExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["birthday-title"].exists)

        app.terminate()
        app.launchEnvironment["IOSPS_TEST_GIFT_REDUCE_MOTION"] = "0"
        app.launch()
        let replay = app.buttons["birthday-celebration-replay"]
        let animatedClose = app.buttons["birthday-celebration-close"]
        XCTAssertTrue(replay.waitForExistence(timeout: 10))
        XCTAssertFalse(animatedClose.waitForExistence(timeout: 1))
        replay.click()
        XCTAssertTrue(animatedClose.waitForExistence(timeout: 5))
        capture(celebration, named: "birthday-celebration-replay")
        app.typeKey(.escape, modifierFlags: [])
        XCTAssertTrue(animatedClose.waitForNonExistence(timeout: 5))
        XCTAssertTrue(replay.isHittable)
    }

    @MainActor
    func testEggRequiresThreeClicksAndKeyboardCanOpenIt() throws {
        continueAfterFailure = false
        let fixture = try makeFixture()
        defer { try? FileManager.default.removeItem(at: fixture) }
        let app = launch(fixture, on: "2025-02-27")
        let egg = app.buttons["birthday-easter-egg"]
        let message = app.staticTexts["birthday-easter-egg-message"]
        XCTAssertTrue(egg.waitForExistence(timeout: 10))
        XCTAssertFalse(app.buttons["birthday-celebration-replay"].exists)
        egg.doubleClick()
        XCTAssertFalse(message.waitForExistence(timeout: 2.1))
        egg.click()
        XCTAssertFalse(message.exists)
        egg.doubleClick()
        XCTAssertTrue(message.waitForExistence(timeout: 5))
        let value = message.value as? String ?? message.label
        XCTAssertTrue(value.contains("这是一条合成彩蛋。"))
        capture(app.windows["IOSPS"], named: "birthday-easter-egg-open")
        app.typeKey(.escape, modifierFlags: [])
        XCTAssertTrue(message.waitForNonExistence(timeout: 5))
        XCTAssertTrue(egg.isHittable)
        app.typeKey(" ", modifierFlags: [])
        XCTAssertTrue(message.waitForExistence(timeout: 5), "Space should activate the restored focus.")
        app.typeKey(.escape, modifierFlags: [])
        XCTAssertTrue(message.waitForNonExistence(timeout: 5))
        app.typeKey("e", modifierFlags: [.command, .shift])
        XCTAssertTrue(message.waitForExistence(timeout: 5))
    }

    private func makeFixture() throws -> URL {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: false)
        let manifest = #"{"schemaVersion":1,"birthday":"2000-02-29","wishesPath":"wishes.txt","easterEggPath":"easter-egg.txt","memories":[]}"#
        try Data(manifest.utf8).write(to: directory.appendingPathComponent("memories.json"))
        try Data("这是一份合成生日祝福。".utf8).write(to: directory.appendingPathComponent("wishes.txt"))
        try Data("这是一条合成彩蛋。".utf8).write(to: directory.appendingPathComponent("easter-egg.txt"))
        return directory
    }

    @MainActor
    private func launch(_ directory: URL, on date: String, reduceMotion: Bool = false) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchEnvironment = [
            "IOSPS_TEST_GIFT_DIRECTORY": directory.path,
            "IOSPS_TEST_GIFT_DATE": date,
            "IOSPS_TEST_GIFT_DEFAULTS": "org.iosps.birthday.tests.\(directory.lastPathComponent)",
            "IOSPS_TEST_GIFT_REDUCE_MOTION": reduceMotion ? "1" : "0",
        ]
        app.launch()
        return app
    }

    @MainActor
    private func capture(_ element: XCUIElement, named name: String) {
        let attachment = XCTAttachment(screenshot: element.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
