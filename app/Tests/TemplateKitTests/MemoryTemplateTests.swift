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

    func testBuiltInCatalogLoadsAllEightValidTemplates() throws {
        let catalog = try BuiltInMemoryTemplateCatalog.load()
        XCTAssertEqual(catalog.count, 8)
        XCTAssertEqual(Set(catalog.map(\.template.id)).count, 8)
        XCTAssertTrue(catalog[0].isRecommended)
        let motions = Set(catalog.flatMap { $0.template.scenes.map(\.motion) })
        XCTAssertEqual(motions, [.still, .zoomIn, .zoomOut, .panLeft, .panRight])
        let allowedMusicIDs: Set<String> = ["warm-piano", "music-box", "sunny-acoustic", "starry-nocturne"]
        for item in catalog {
            let music = try XCTUnwrap(item.template.music)
            XCTAssertTrue(allowedMusicIDs.contains(music.assetID))
            XCTAssertLessThanOrEqual(music.startFrame + music.frames, 480)
            XCTAssertFalse(item.subtitle.isEmpty)
            XCTAssertFalse(item.musicTitle.isEmpty)
        }
    }

    func testWithOpeningCaptionOverridesFirstSceneOnly() throws {
        let catalog = try BuiltInMemoryTemplateCatalog.load()
        let base = try XCTUnwrap(catalog.first?.template)
        let untouched = base.withOpeningCaption("   ")
        XCTAssertEqual(untouched, base)

        let customized = base.withOpeningCaption("  给最好的朋友  ")
        XCTAssertEqual(customized.scenes.first?.caption, "给最好的朋友")
        XCTAssertEqual(Array(customized.scenes.dropFirst()), Array(base.scenes.dropFirst()))
        XCTAssertEqual(customized.music, base.music)
    }

    private func decode(_ json: String) throws -> MemoryTemplate {
        try JSONDecoder().decode(MemoryTemplate.self, from: Data(json.utf8))
    }
}
