import Foundation
import BirthdayCore
import XCTest
@testable import TimelineKit

final class TimelineTests: XCTestCase {
    func testEmptyTimelineIsAValidDraft() throws {
        let timeline = try Timeline(clips: [], overlaps: [])
        XCTAssertEqual(timeline.durationFrames, 0)
        XCTAssertEqual(timeline.clipStartFrames, [])
    }

    func testCutsUseExactFrameBoundariesAndAllowRepeatedSources() throws {
        let source = MediaID()
        let first = try TimelineClip(media: source, startFrame: 15, frameCount: 31)
        let next = try TimelineClip(media: source, startFrame: 0, frameCount: 29)
        let timeline = try Timeline(clips: [first, next], overlaps: [0])
        XCTAssertEqual(timeline.clipStartFrames, [0, 31])
        XCTAssertEqual(timeline.durationFrames, 60)
        XCTAssertEqual(timeline.clips.first?.startFrame, 15)
        XCTAssertEqual(timeline.clips.last?.media, source)
    }

    func testDissolvesShiftClipStartsAndSurviveCoding() throws {
        let first = try clip(30)
        let middle = try clip(60)
        let last = try clip(90)
        let timeline = try Timeline(clips: [first, middle, last], overlaps: [10, 15])
        XCTAssertEqual(timeline.clipStartFrames, [0, 20, 65])
        XCTAssertEqual(timeline.durationFrames, 155)
        let encoded = try JSONEncoder().encode(timeline)
        XCTAssertEqual(try JSONDecoder().decode(Timeline.self, from: encoded), timeline)
    }

    func testInvalidTransitionsAreRejected() throws {
        let clips = try [clip(10), clip(10), clip(10)]
        XCTAssertThrowsError(try Timeline(clips: clips, overlaps: [0]))
        XCTAssertThrowsError(try Timeline(clips: clips, overlaps: [-1, 0]))
        XCTAssertThrowsError(try Timeline(clips: clips, overlaps: [10, 0]))
        XCTAssertThrowsError(try Timeline(clips: clips, overlaps: [6, 5]))
    }

    func testOutputLimitAndSourceOverflowAreRejected() throws {
        let full = try clip(VideoTiming.maxOutputFrames)
        let valid = try Timeline(clips: [full], overlaps: [])
        XCTAssertEqual(valid.durationFrames, VideoTiming.maxOutputFrames)
        XCTAssertThrowsError(try Timeline(clips: [full, clip(1)], overlaps: [0]))
        XCTAssertThrowsError(try TimelineClip(media: MediaID(), startFrame: .max, frameCount: 1))
        XCTAssertThrowsError(try clip(0))
    }

    func testInvalidDecodedTimelineUsesSameValidation() throws {
        let timeline = try Timeline(clips: [clip(2), clip(2)], overlaps: [0])
        let encoded = try JSONEncoder().encode(timeline)
        let object = try JSONSerialization.jsonObject(with: encoded)
        var json = try XCTUnwrap(object as? [String: Any])
        json["overlaps"] = [3]
        let invalid = try JSONSerialization.data(withJSONObject: json)
        XCTAssertThrowsError(try JSONDecoder().decode(Timeline.self, from: invalid))
    }

    private func clip(_ frameCount: Int) throws -> TimelineClip {
        try TimelineClip(media: MediaID(), startFrame: 0, frameCount: frameCount)
    }
}
