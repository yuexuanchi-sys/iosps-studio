import Foundation
import XCTest
@testable import TemplateKit

final class MemoryTemplateTests: XCTestCase {
    func testTemplateRepeatsScenesAndRetainsReferences() throws {
        let template = try decode(#"""
        {
          "formatVersion":1,"id":"example","name":"Example",
          "scenes":[
            {"frames":90,"transitionFrames":12,"motion":"zoomIn","caption":"Hello","filterID":"warm"},
            {"frames":60,"transitionFrames":0,"motion":"still"}
          ],
          "music":{"assetID":"piano","startFrame":30,"frames":120}
        }
        """#)
        XCTAssertEqual(template.scene(at: 2)?.frames, 90)
        XCTAssertEqual(template.scene(at: Int.max)?.motion, .still)
        XCTAssertNil(template.scene(at: -1))
        XCTAssertEqual(template.scenes.first?.caption, "Hello")
        XCTAssertEqual(template.scenes.first?.filterID, "warm")
        XCTAssertEqual(template.music?.startFrame, 30)
    }

    func testEmptyScenesAndUnknownVersionAreRejected() {
        XCTAssertThrowsError(try decode(#"{"formatVersion":1,"id":"example","name":"Example","scenes":[]}"#))
        XCTAssertThrowsError(try decode(#"""
        {"formatVersion":2,"id":"example","name":"Example",
         "scenes":[{"frames":90,"transitionFrames":0,"motion":"still"}]}
        """#))
    }

    func testInvalidDurationsAndTransitionOverlapAreRejected() {
        XCTAssertThrowsError(try decode(#"""
        {"formatVersion":1,"id":"example","name":"Example",
         "scenes":[{"frames":0,"transitionFrames":0,"motion":"still"}]}
        """#))
        XCTAssertThrowsError(try decode(#"""
        {"formatVersion":1,"id":"example","name":"Example",
         "scenes":[{"frames":10,"transitionFrames":6,"motion":"still"}]}
        """#))
    }

    func testInvalidMusicRangeIsRejected() {
        XCTAssertThrowsError(try decode(#"""
        {"formatVersion":1,"id":"example","name":"Example",
         "scenes":[{"frames":90,"transitionFrames":0,"motion":"still"}],
         "music":{"assetID":"piano","startFrame":9223372036854775807,"frames":1}}
        """#))
    }

    private func decode(_ json: String) throws -> MemoryTemplate {
        try JSONDecoder().decode(MemoryTemplate.self, from: Data(json.utf8))
    }
}
