import Foundation
import GiftKit
import XCTest
@testable import IOSPS

final class BirthdayHomeSessionTests: XCTestCase {
    @MainActor
    func testLocalGreetingAndLeapDayMetrics() throws {
        let folder = try makeDirectory()
        defer { try? FileManager.default.removeItem(at: folder) }
        let wishes = folder.appendingPathComponent("wishes.txt")
        try Data("这是一份合成祝福。".utf8).write(to: wishes)
        try writeManifest(
            #"{"schemaVersion":1,"birthday":"2000-02-29","metOn":"2025-02-27","wishesPath":"wishes.txt","memories":[]}"#,
            in: folder
        )
        let session = BirthdayHomeSession(directory: folder)
        session.reload()
        let metrics = session.metrics(on: try LocalDay(isoDate: "2025-02-28"))
        XCTAssertEqual(session.wishes, "这是一份合成祝福。")
        XCTAssertEqual(session.birthday, try LocalDay(isoDate: "2000-02-29"))
        XCTAssertEqual(metrics.age, 25)
        XCTAssertEqual(metrics.daysUntilBirthday, 0)
        XCTAssertEqual(metrics.daysSinceMeeting, 1)
        XCTAssertTrue(metrics.isBirthday)
    }

    @MainActor
    func testEmptyConfigAndInvalidReloadPreserveLastGreeting() throws {
        let folder = try makeDirectory()
        defer { try? FileManager.default.removeItem(at: folder) }
        let session = BirthdayHomeSession(directory: folder)
        let today = try LocalDay(isoDate: "2025-02-27")
        session.reload()
        XCTAssertNil(session.wishes)
        XCTAssertNil(session.metrics(on: today).daysUntilBirthday)
        XCTAssertFalse(session.reloadFailed)

        let wishes = folder.appendingPathComponent("local.txt")
        try Data("合成祝福".utf8).write(to: wishes)
        try writeManifest(
            #"{"schemaVersion":1,"birthday":"2000-02-29","wishesPath":"local.txt","memories":[]}"#,
            in: folder
        )
        session.reload()
        XCTAssertEqual(session.wishes, "合成祝福")
        XCTAssertEqual(session.metrics(on: today).daysUntilBirthday, 1)
        XCTAssertNil(session.metrics(on: today).daysSinceMeeting)

        let alias = folder.appendingPathComponent("alias.txt")
        try FileManager.default.createSymbolicLink(at: alias, withDestinationURL: wishes)
        try writeManifest(#"{"schemaVersion":1,"wishesPath":"alias.txt","memories":[]}"#, in: folder)
        session.reload()
        XCTAssertTrue(session.reloadFailed)
        XCTAssertEqual(session.wishes, "合成祝福")

        try writeManifest(#"{"schemaVersion":1,"memories":[]}"#, in: folder)
        session.reload()
        XCTAssertFalse(session.reloadFailed)
        XCTAssertNil(session.wishes)
        XCTAssertNil(session.birthday)
    }

    @MainActor
    func testLocalEggAndPersistedCelebrationDay() throws {
        let folder = try makeDirectory()
        defer { try? FileManager.default.removeItem(at: folder) }
        let domain = "org.iosps.tests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: domain))
        defer { defaults.removePersistentDomain(forName: domain) }
        let day = try LocalDay(isoDate: "2025-02-28")
        let nextAnniversary = try LocalDay(isoDate: "2026-02-28")
        let dayBefore = try LocalDay(isoDate: "2025-02-27")
        let egg = folder.appendingPathComponent("egg.txt")
        try Data(" 合成彩蛋 ".utf8).write(to: egg)
        try writeManifest(#"{"schemaVersion":1,"birthday":"2000-02-29","easterEggPath":"egg.txt","memories":[]}"#, in: folder)

        let first = BirthdayHomeSession(directory: folder, defaults: defaults)
        XCTAssertEqual(first.easterEgg, "合成彩蛋")
        XCTAssertFalse(first.shouldPresentAutomatically(on: dayBefore))
        XCTAssertTrue(first.shouldPresentAutomatically(on: day))
        first.recordAutomaticPresentation(on: day)

        let reopened = BirthdayHomeSession(directory: folder, defaults: defaults)
        XCTAssertFalse(reopened.shouldPresentAutomatically(on: day))
        XCTAssertTrue(reopened.metrics(on: day).isBirthday)
        XCTAssertTrue(reopened.shouldPresentAutomatically(on: nextAnniversary))

        try FileManager.default.removeItem(at: egg)
        reopened.reload()
        XCTAssertNil(reopened.easterEgg)
        XCTAssertFalse(reopened.reloadFailed)
        XCTAssertTrue(reopened.metrics(on: day).isBirthday)
    }

    private func writeManifest(_ text: String, in directory: URL) throws {
        try Data(text.utf8).write(to: directory.appendingPathComponent("memories.json"), options: .atomic)
    }

    private func makeDirectory() throws -> URL {
        let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString, directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: false)
        return directory
    }
}
