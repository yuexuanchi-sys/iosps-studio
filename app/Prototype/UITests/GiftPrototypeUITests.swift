import XCTest

final class GiftPrototypeUITests: XCTestCase {
    @MainActor
    func testChineseEntryAndAppearanceVariants() {
        continueAfterFailure = false
        let app = XCUIApplication()
        for variant in ["light", "dark", "large"] {
            app.launchArguments = ["--gift-ui-appearance", variant]
            app.launch()
            XCTAssertTrue(app.staticTexts["生日快乐"].waitForExistence(timeout: 10))
            capture(app, name: "\(variant)-birthday")
            app.typeKey("2", modifierFlags: .command)
            XCTAssertTrue(app.staticTexts["湖畔散步"].waitForExistence(timeout: 5))
            capture(app, name: "\(variant)-memories")
            app.buttons["gift-edit-sample"].firstMatch.click()
            XCTAssertTrue(app.buttons["gift-rotate"].waitForExistence(timeout: 15))
            capture(app, name: "\(variant)-editor")
            app.typeKey("1", modifierFlags: .command)
            XCTAssertTrue(app.staticTexts["生日快乐"].waitForExistence(timeout: 5))
            app.typeKey("3", modifierFlags: .command)
            XCTAssertTrue(app.buttons["gift-rotate"].waitForExistence(timeout: 5))
            app.terminate()
        }
    }

    @MainActor
    private func capture(_ app: XCUIApplication, name: String) {
        let attachment = XCTAttachment(screenshot: app.windows.firstMatch.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
