import XCTest

final class VideoEditorUITests: XCTestCase {
    @MainActor
    func testOpensEditorFromTheAppToolbar() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launch()
        XCTAssertTrue(app.staticTexts["birthday-title"].waitForExistence(timeout: 10))
        let entry = app.windows["IOSPS"].toolbars.buttons.matching(identifier: "video-editor-entry").firstMatch
        XCTAssertTrue(entry.waitForExistence(timeout: 3), "The normal App window should provide a video editor entry.")
        entry.click()
        XCTAssertTrue(app.buttons["video-import"].waitForExistence(timeout: 5))
    }
}
