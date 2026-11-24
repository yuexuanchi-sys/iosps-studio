import XCTest
@testable import IOSPS

final class LicenseNoticeTests: XCTestCase {
    func testPackagedLicenseNoticesResolveAllTextAndSources() throws {
        let notices = try LicenseNotice.load()
        XCTAssertEqual(notices.map(\.id), ["xcodegen", "actions-checkout", "actions-upload-artifact"])
        XCTAssertTrue(notices.allSatisfy { $0.source.scheme == "https" && $0.source.host == "github.com" })
        XCTAssertTrue(notices.allSatisfy { $0.text.contains("Permission is hereby granted") })
        XCTAssertTrue(notices[0].text.contains("Copyright (c) 2018 Yonas Kolb"))
        for notice in notices.dropFirst() {
            XCTAssertTrue(notice.text.contains("Copyright (c) 2018 GitHub, Inc. and contributors"))
        }
    }
}
