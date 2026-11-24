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
        XCTAssertTrue(contains("Yonas Kolb", in: text), text.debugDescription)

        let picker = app.popUpButtons["license-picker"]
        picker.click()
        app.typeKey(.downArrow, modifierFlags: [])
        app.typeKey(.return, modifierFlags: [])
        XCTAssertTrue(contains("GitHub, Inc. and contributors", in: text),
                      "\(text.debugDescription)\n\(picker.debugDescription)")

        let attachment = XCTAttachment(screenshot: app.windows["关于 IOSPS"].screenshot())
        attachment.name = "about-licenses"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    @MainActor
    private func contains(_ expected: String, in element: XCUIElement) -> Bool {
        element.label.contains(expected) || (element.value as? String)?.contains(expected) == true
    }
}
