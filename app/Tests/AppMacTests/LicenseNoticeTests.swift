import XCTest
@testable import IOSPS

final class LicenseNoticeTests: XCTestCase {
    func testPackagedLicenseNoticesResolveAllTextAndSources() throws {
        let notices = try LicenseNotice.load()
        XCTAssertEqual(notices.map(\.id), [
            "xcodegen",
            "actions-checkout",
            "actions-upload-artifact",
            "novacut",
            "iosps-original-bgm",
        ])
        XCTAssertTrue(notices.allSatisfy { $0.source.scheme == "https" && $0.source.host == "github.com" })
        XCTAssertTrue(notices.allSatisfy { $0.text.contains("Permission is hereby granted") })
        XCTAssertTrue(notices[0].text.contains("Copyright (c) 2018 Yonas Kolb"))
        for notice in notices[1...2] {
            XCTAssertTrue(notice.text.contains("Copyright (c) 2018 GitHub, Inc. and contributors"))
        }
        XCTAssertTrue(notices[3].source.path.contains("722178133bc8d82592ddc093382511e3e8e591b2"))
        XCTAssertTrue(notices[4].source.path.contains("iosps-studio"))
        XCTAssertTrue(notices[4].text.contains("CC0 1.0 Universal"))
        XCTAssertTrue(notices[4].text.contains("warm-piano.m4a"))
    }
}
