import Foundation
import XCTest
@testable import GiftKit

final class GiftCalendarTests: XCTestCase {
    func testLocalDayRejectsInvalidAndVariableWidthDates() throws {
        for value in ["", "2026-2-01", "0000-01-01", "1900-02-29", "2026-04-31", "10000-01-01"] {
            XCTAssertThrowsError(try LocalDay(isoDate: value), value)
        }
        let leap = try LocalDay(isoDate: "2000-02-29")
        XCTAssertEqual(try JSONDecoder().decode(LocalDay.self, from: JSONEncoder().encode(leap)), leap)
    }

    func testLeapDayBirthdayFallsOnFebruaryEnd() throws {
        let birthday = try LocalDay(isoDate: "2000-02-29")
        let today = try LocalDay(isoDate: "2025-02-28")
        let result = GiftCalendar.metrics(on: today, birthday: birthday)
        XCTAssertTrue(result.isBirthday)
        XCTAssertEqual(result.daysUntilBirthday, 0)
        XCTAssertEqual(result.age, 25)
    }

    func testLeapYearRetainsFebruary29() throws {
        let result = GiftCalendar.metrics(
            on: try LocalDay(isoDate: "2024-02-28"),
            birthday: try LocalDay(isoDate: "2000-02-29")
        )
        XCTAssertFalse(result.isBirthday)
        XCTAssertEqual(result.daysUntilBirthday, 1)
        XCTAssertEqual(result.age, 23)
    }

    func testCountdownCrossesNewYear() throws {
        let result = GiftCalendar.metrics(
            on: try LocalDay(isoDate: "2026-12-31"),
            birthday: try LocalDay(isoDate: "2000-01-01")
        )
        XCTAssertEqual(result.daysUntilBirthday, 1)
        XCTAssertEqual(result.age, 26)
    }

    func testSameInstantUsesRequestedTimeZone() throws {
        let instant = Date(timeIntervalSince1970: 1_709_165_600)
        let west = try XCTUnwrap(TimeZone(secondsFromGMT: -8 * 3600))
        let east = try XCTUnwrap(TimeZone(secondsFromGMT: 8 * 3600))
        XCTAssertEqual(try LocalDay(containing: instant, timeZone: west), try LocalDay(isoDate: "2024-02-28"))
        XCTAssertEqual(try LocalDay(containing: instant, timeZone: east), try LocalDay(isoDate: "2024-02-29"))
    }

    func testElapsedDaysAreCalendarDaysAcrossDaylightSaving() throws {
        let zone = try XCTUnwrap(TimeZone(identifier: "America/Los_Angeles"))
        let now = try XCTUnwrap(ISO8601DateFormatter().date(from: "2024-03-11T07:00:00Z"))
        let today = try LocalDay(containing: now, timeZone: zone)
        let result = GiftCalendar.metrics(on: today, metOn: try LocalDay(isoDate: "2024-03-10"))
        XCTAssertEqual(result.daysSinceMeeting, 1)
    }

    func testMissingAndFutureDatesHideMetrics() throws {
        let today = try LocalDay(isoDate: "2026-01-01")
        let future = try LocalDay(isoDate: "2027-01-01")
        for date in [nil, future] as [LocalDay?] {
            let result = GiftCalendar.metrics(on: today, birthday: date, metOn: date)
            XCTAssertNil(result.daysUntilBirthday)
            XCTAssertNil(result.age)
            XCTAssertNil(result.daysSinceMeeting)
            XCTAssertFalse(result.isBirthday)
        }
    }

    func testLastSupportedYearDoesNotOverflow() throws {
        let result = GiftCalendar.metrics(
            on: try LocalDay(isoDate: "9999-12-31"),
            birthday: try LocalDay(isoDate: "0001-01-01")
        )
        XCTAssertEqual(result.age, 9_998)
        XCTAssertNil(result.daysUntilBirthday)
    }
}
