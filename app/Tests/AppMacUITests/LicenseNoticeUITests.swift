import XCTest

final class LicenseNoticeUITests: XCTestCase {
    @MainActor
    func testAboutMenuShowsLocalLicenseAndKeyboardChangesSelection() {
        let app = XCUIApplication()
        app.launch()
        app.menuBars.menuBarItems["IOSPS"].click()
        app.menuItems["about-iosps"].click()
        let text = app.staticTexts["license-text"]
        XCTAssertTrue(text.waitForExistence(timeout: 5))
        XCTAssertTrue(text.label.contains("Yonas Kolb"))

        let picker = app.descendants(matching: .any).matching(identifier: "license-picker").firstMatch
        picker.click()
        app.typeKey(.downArrow, modifierFlags: [])
        app.typeKey(.return, modifierFlags: [])
        let updated = NSPredicate(format: "label CONTAINS %@", "GitHub, Inc. and contributors")
        let expectation = XCTNSPredicateExpectation(predicate: updated, object: text)
        XCTAssertEqual(XCTWaiter.wait(for: [expectation], timeout: 5), .completed)
    }
}
