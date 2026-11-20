import Foundation
import XCTest

final class AppMacTests: XCTestCase {
    func testAppHostContainsDesignSystemResources() throws {
        XCTAssertEqual(Bundle.main.bundleIdentifier, "org.iosps.birthday")
        let resources = try XCTUnwrap(
            Bundle.main.url(forResource: "IOSPSModules_DesignSystem", withExtension: "bundle")
        )
        XCTAssertNotNil(Bundle(url: resources))
    }
}
