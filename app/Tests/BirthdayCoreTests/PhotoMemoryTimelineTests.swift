import BirthdayCore
import Foundation
import XCTest

final class PhotoMemoryTimelineTests: XCTestCase {
    func testOrdersEntriesByLatestSavedAtDescending() {
        var timeline = PhotoMemoryTimeline()
        let t1 = Date(timeIntervalSince1970: 1_795_000_000)
        let t2 = Date(timeIntervalSince1970: 1_795_000_600)
        let first = makeEntry(title: "first", savedAt: t1)
        let second = makeEntry(title: "second", savedAt: t2)

        timeline.record(first)
        timeline.record(second)

        XCTAssertEqual(timeline.entries.map(\.id), [second.id, first.id])
    }

    func testUpdatingExistingProjectMovesItWithoutDuplication() {
        var timeline = PhotoMemoryTimeline()
        let t1 = Date(timeIntervalSince1970: 1_795_000_000)
        let t2 = Date(timeIntervalSince1970: 1_795_000_300)
        let t3 = Date(timeIntervalSince1970: 1_795_000_900)
        let idA = ProjectID()
        let idB = ProjectID()
        let preview1 = MediaID()
        let preview2 = MediaID()

        timeline.record(makeEntry(id: idA, title: "A-v1", preview: preview1, savedAt: t1))
        timeline.record(makeEntry(id: idB, title: "B-v1", savedAt: t2))
        XCTAssertEqual(timeline.entries.map(\.id), [idB, idA])

        timeline.record(makeEntry(id: idA, title: "A-v2", preview: preview2, savedAt: t3))
        XCTAssertEqual(timeline.entries.count, 2)
        XCTAssertEqual(timeline.entries.map(\.id), [idA, idB])
        XCTAssertEqual(timeline.entry(for: idA)?.title, "A-v2")
        XCTAssertEqual(timeline.entry(for: idA)?.previewMediaID, preview2)
    }

    func testEqualTimestampsBreakTiesDeterministicallyByStableProjectID() {
        let sameInstant = Date(timeIntervalSince1970: 1_795_001_000)
        let lowID = ProjectID(rawValue: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!)
        let highID = ProjectID(rawValue: UUID(uuidString: "FFFFFFFF-FFFF-FFFF-FFFF-FFFFFFFFFFFF")!)
        let high = makeEntry(id: highID, title: "High", savedAt: sameInstant)
        let low = makeEntry(id: lowID, title: "Low", savedAt: sameInstant)

        var timelineA = PhotoMemoryTimeline()
        timelineA.record(high)
        timelineA.record(low)

        var timelineB = PhotoMemoryTimeline()
        timelineB.record(low)
        timelineB.record(high)

        XCTAssertEqual(timelineA.entries.map(\.id), [lowID, highID])
        XCTAssertEqual(timelineB.entries.map(\.id), [lowID, highID])
    }

    func testCodableRoundTripNormalizesDuplicatesAndRejectsUnsupportedVersion() throws {
        let t1 = Date(timeIntervalSince1970: 1_795_000_000)
        let t2 = Date(timeIntervalSince1970: 1_795_000_500)
        let sharedID = ProjectID()
        let otherID = ProjectID()
        let raw = PhotoMemoryTimeline(entries: [
            makeEntry(id: sharedID, title: "old", savedAt: t1),
            makeEntry(id: otherID, title: "other", savedAt: t1.addingTimeInterval(100)),
            makeEntry(id: sharedID, title: "new", savedAt: t2),
        ])

        let encoded = try JSONEncoder().encode(raw)
        let decoded = try JSONDecoder().decode(PhotoMemoryTimeline.self, from: encoded)
        XCTAssertEqual(decoded.entries.count, 2)
        XCTAssertEqual(decoded.entries.map(\.id), [sharedID, otherID])
        XCTAssertEqual(decoded.entry(for: sharedID)?.title, "new")

        let unsupported = Data(#"{"schemaVersion":99,"entries":[]}"#.utf8)
        XCTAssertThrowsError(try JSONDecoder().decode(PhotoMemoryTimeline.self, from: unsupported))
    }

    func testGroupedByDayUsesCallerTimeZone() throws {
        // 2026-11-27T20:00:00Z is 2026-11-28 04:00 in Asia/Shanghai (UTC+8) and 2026-11-27 20:00 in UTC.
        let instant = Date(timeIntervalSince1970: 1_795_809_600)
        let earlier = instant.addingTimeInterval(-3600 * 10)
        let timeline = PhotoMemoryTimeline(entries: [
            makeEntry(title: "late", savedAt: instant),
            makeEntry(title: "early", savedAt: earlier),
        ])

        let utcGroups = timeline.groupedByDay(in: try XCTUnwrap(TimeZone(secondsFromGMT: 0)))
        XCTAssertEqual(utcGroups.count, 1)
        XCTAssertEqual(utcGroups[0].entries.count, 2)

        let plusEight = timeline.groupedByDay(in: try XCTUnwrap(TimeZone(secondsFromGMT: 8 * 3600)))
        XCTAssertEqual(plusEight.count, 2)
        XCTAssertEqual(plusEight[0].entries.map(\.title), ["late"])
        XCTAssertEqual(plusEight[1].entries.map(\.title), ["early"])
    }

    private func makeEntry(
        id: ProjectID = ProjectID(),
        title: String,
        preview: MediaID = MediaID(),
        savedAt: Date
    ) -> PhotoMemoryEntry {
        PhotoMemoryEntry(
            id: id,
            title: title,
            projectPath: "/tmp/\(title).comp",
            previewMediaID: preview,
            savedAt: savedAt,
            pixelWidth: 320,
            pixelHeight: 160
        )
    }
}
