import XCTest

final class LicenseNoticeUITests: XCTestCase {
    @MainActor
    func testAboutMenuShowsLocalLicenseAndKeyboardChangesSelection() {
        let app = XCUIApplication()
        app.launch()
        let menu = app.menuBars.menuBarItems["IOSPS"]
        menu.click()
        let about = menu.menuItems["关于 IOSPS"]
        XCTAssertTrue(about.exists, menu.debugDescription)
        about.click()
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

        let attachment = XCTAttachment(screenshot: app.windows["关于 IOSPS"].screenshot())
        attachment.name = "about-licenses"
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
