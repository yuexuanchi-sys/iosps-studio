import Foundation
import XCTest
@testable import BirthdayCore

final class ProjectTests: XCTestCase {
    func testPhotoProjectRoundTrips() throws {
        let project = Project(content: .photo(PhotoEditDocument(source: MediaID())))
        let encoded = try JSONEncoder().encode(project)
        XCTAssertEqual(try JSONDecoder().decode(Project.self, from: encoded), project)
    }

    func testVideoProjectPreservesSourceOrderAndDuplicates() throws {
        let first = MediaID()
        let second = MediaID()
        let project = Project(content: .video(VideoProject(sources: [second, first, second])))
        let encoded = try JSONEncoder().encode(project)
        XCTAssertEqual(try JSONDecoder().decode(Project.self, from: encoded), project)
    }

    func testEmptyVideoDraftRoundTrips() throws {
        let project = Project(content: .video(VideoProject(sources: [])))
        let encoded = try JSONEncoder().encode(project)
        XCTAssertEqual(try JSONDecoder().decode(Project.self, from: encoded), project)
    }

    func testUnknownSchemaIsRejected() throws {
        let project = Project(content: .video(VideoProject(sources: [])))
        let encoded = try JSONEncoder().encode(project)
        let object = try JSONSerialization.jsonObject(with: encoded)
        var envelope = try XCTUnwrap(object as? [String: Any])
        envelope["schemaVersion"] = Int.max
        let changed = try JSONSerialization.data(withJSONObject: envelope)
        XCTAssertThrowsError(try JSONDecoder().decode(Project.self, from: changed))
    }
}
