import XCTest

final class BirthdayHomeUITests: XCTestCase {
    @MainActor
    func testAppStartsOnBirthdayHomeAndKeyboardOpensEasterEggEntry() {
        let app = XCUIApplication()
        app.launch()
        XCTAssertTrue(app.staticTexts["birthday-title"].waitForExistence(timeout: 10))
        let egg = app.buttons["birthday-easter-egg"]
        XCTAssertTrue(egg.exists && egg.isEnabled && egg.isHittable)

        app.typeKey("e", modifierFlags: [.command, .shift])
        XCTAssertTrue(app.staticTexts["birthday-easter-egg-notice"].waitForExistence(timeout: 5))
        app.buttons["birthday-easter-egg-dismiss"].click()
        app.buttons["shared-media-entry"].click()
        XCTAssertTrue(app.buttons["media-finder-picker"].waitForExistence(timeout: 5))
    }
}
