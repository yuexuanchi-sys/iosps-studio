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
        let alert = app.alerts.firstMatch
        XCTAssertTrue(alert.waitForExistence(timeout: 5))
        alert.buttons.firstMatch.click()
        app.buttons["shared-media-entry"].click()
        XCTAssertTrue(app.buttons["media-finder-picker"].waitForExistence(timeout: 5))
    }
}
