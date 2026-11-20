import Foundation
import XCTest
@testable import BirthdayCore

final class ProjectIDTests: XCTestCase {
    func testStableStringCoding() throws {
        let raw = try XCTUnwrap(UUID(uuidString: "00000000-0000-0000-0000-000000000000"))
        let id = ProjectID(rawValue: raw)
        let encoded = try JSONEncoder().encode(id)
        XCTAssertEqual(try JSONDecoder().decode(String.self, from: encoded), raw.uuidString)
        XCTAssertEqual(try JSONDecoder().decode(ProjectID.self, from: encoded), id)
    }

    func testInvalidIDIsRejected() {
        XCTAssertThrowsError(try JSONDecoder().decode(ProjectID.self, from: Data(#""not-an-id""#.utf8)))
    }

    func testEmptyIDIsRejected() {
        XCTAssertThrowsError(try JSONDecoder().decode(ProjectID.self, from: Data(#""""#.utf8)))
    }
}
