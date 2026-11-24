import XCTest

final class BirthdayHomeUITests: XCTestCase {
    @MainActor
    func testAppStartsOnBirthdayHomeAndKeyboardOpensEasterEggEntry() {
        let app = XCUIApplication()
        app.launch()
        XCTAssertTrue(app.staticTexts["birthday-title"].waitForExistence(timeout: 10))
        let egg = app.buttons["birthday-easter-egg"]
        XCTAssertTrue(egg.exists && egg.isEnabled && egg.isHittable)
        let control = XCTAttachment(screenshot: egg.screenshot())
        control.name = "birthday-egg-control"
        control.lifetime = .keepAlways
        add(control)

        app.typeKey("e", modifierFlags: [.command, .shift])
        XCTAssertTrue(app.staticTexts["birthday-easter-egg-notice"].waitForExistence(timeout: 5))
        app.buttons["birthday-easter-egg-dismiss"].click()
        // macOS 15 exposes the toolbar item and its button with the same identifier.
        let mediaEntry = app.windows["IOSPS"].toolbars.buttons.matching(identifier: "shared-media-entry").firstMatch
        XCTAssertTrue(mediaEntry.isHittable)
        mediaEntry.click()
        XCTAssertTrue(app.buttons["media-finder-picker"].waitForExistence(timeout: 5))
    }
}
