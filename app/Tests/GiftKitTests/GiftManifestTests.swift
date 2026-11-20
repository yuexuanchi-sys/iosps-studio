import Foundation
import XCTest
@testable import GiftKit

final class GiftManifestTests: XCTestCase {
    func testEmptyManifestCanBeImported() throws {
        let manifest = try decode(#"{"schemaVersion":1,"memories":[]}"#)
        XCTAssertTrue(manifest.memories.isEmpty)
        XCTAssertNil(manifest.birthday)
        XCTAssertNil(manifest.audioPath)
        XCTAssertNil(manifest.wishesPath)
    }

    func testFullManifestSortsEventsAndPreservesPhotoOrder() throws {
        let manifest = try decode(#"""
        {
          "schemaVersion": 1,
          "birthday": "2000-02-29",
          "metOn": "2024-01-05",
          "wishesPath": "wishes.txt",
          "audioPath": "audio/hello.m4a",
          "easterEggPath": "easter-egg.txt",
          "featuredPhoto": "memories/cover.HEIC",
          "memories": [
            {"id":"first", "date":"2024-01-05", "title":"Example A", "photos":["z.jpg","a.png"]},
            {"id":"old", "date":"2023-12-01", "title":"Example B", "photos":["b.jpg"]},
            {"id":"tie", "date":"2024-01-05", "title":"Example C", "photos":["c.jpg"]}
          ]
        }
        """#)
        XCTAssertEqual(manifest.memories.map(\.id), ["first", "tie", "old"])
        XCTAssertEqual(manifest.memories[0].photos.map(\.value), ["z.jpg", "a.png"])
        XCTAssertEqual(manifest.birthday, try LocalDay(isoDate: "2000-02-29"))
        XCTAssertEqual(manifest.metOn, try LocalDay(isoDate: "2024-01-05"))
        XCTAssertEqual(manifest.featuredPhoto?.value, "memories/cover.HEIC")
        XCTAssertEqual(manifest.easterEggPath?.value, "easter-egg.txt")
    }

    func testUnknownVersionIsRejected() {
        XCTAssertThrowsError(try decode(#"{"schemaVersion":2,"memories":[]}"#))
    }

    func testDuplicateEventIDsAreRejected() {
        XCTAssertThrowsError(try decode(#"""
        {"schemaVersion":1,"memories":[
          {"id":"event","date":"2024-03-10","title":"A","photos":["a.jpg"]},
          {"id":"event","date":"2024-03-11","title":"B","photos":["b.jpg"]}
        ]}
        """#))
    }

    func testInvalidDatesAndEmptyPhotosAreRejected() {
        XCTAssertThrowsError(try decode(#"{"schemaVersion":1,"birthday":"1900-02-29","memories":[]}"#))
        XCTAssertThrowsError(try decode(#"""
        {"schemaVersion":1,"memories":[{"id":"event","date":"2024-06-15","title":"A","photos":[]}]}
        """#))
    }

    func testPathsRejectTraversalAndNonportableSyntax() throws {
        for path in ["", "../a.jpg", "/a.jpg", "C:/a.jpg", "a//b.jpg", "a/./b.jpg", #"a\b.jpg"#] {
            let data = try JSONEncoder().encode(path)
            XCTAssertThrowsError(try JSONDecoder().decode(GiftFilePath.self, from: data), path)
        }
        let path = try JSONDecoder().decode(GiftFilePath.self, from: JSONEncoder().encode("memories/合照 1.jpg"))
        XCTAssertEqual(path.value, "memories/合照 1.jpg")
    }

    func testWrongMediaExtensionsAreRejected() {
        XCTAssertThrowsError(try decode(#"{"schemaVersion":1,"wishesPath":"wishes.mp3","memories":[]}"#))
        XCTAssertThrowsError(try decode(#"{"schemaVersion":1,"audioPath":"cover.png","memories":[]}"#))
        XCTAssertThrowsError(try decode(#"{"schemaVersion":1,"featuredPhoto":"cover.mp3","memories":[]}"#))
    }

    private func decode(_ json: String) throws -> GiftManifest {
        try JSONDecoder().decode(GiftManifest.self, from: Data(json.utf8))
    }
}
