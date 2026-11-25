import Foundation
import GiftKit
import Observation

@MainActor
@Observable
final class BirthdayHomeSession {
    private static let celebrationDayKey = "lastAutomaticBirthdayCelebration"
    private let directory: URL
    private let defaults: UserDefaults
    private let fixedDay: LocalDay?
    private var manifest: GiftManifest?
    private(set) var wishes: String?
    private(set) var easterEgg: String?
    private(set) var reloadFailed = false

    var birthday: LocalDay? { manifest?.birthday }

    init(directory: URL, defaults: UserDefaults = .standard, fixedDay: LocalDay? = nil) {
        self.directory = directory
        self.defaults = defaults
        self.fixedDay = fixedDay
        reload()
    }

    func day(at date: Date = .now) -> LocalDay? {
        fixedDay ?? (try? LocalDay(containing: date, timeZone: .autoupdatingCurrent))
    }

    func metrics(on today: LocalDay) -> GiftMetrics {
        GiftCalendar.metrics(on: today, birthday: birthday, metOn: manifest?.metOn)
    }

    func shouldPresentAutomatically(on day: LocalDay) -> Bool {
        guard metrics(on: day).isBirthday else { return false }
        let previous = defaults.data(forKey: Self.celebrationDayKey)
            .flatMap { try? JSONDecoder().decode(LocalDay.self, from: $0) }
        return previous != day
    }

    func recordAutomaticPresentation(on day: LocalDay) {
        if let value = try? JSONEncoder().encode(day) {
            defaults.set(value, forKey: Self.celebrationDayKey)
        }
    }

    func reload() {
        do {
            let configuration = try loadManifest()
            let message = try configuration?.wishesPath.flatMap(readText)
            let egg = configuration?.easterEggPath.flatMap { try? readText($0) }
            manifest = configuration
            wishes = message
            easterEgg = egg
            reloadFailed = false
        } catch {
            reloadFailed = true
        }
    }

    private func readText(_ path: GiftFilePath) throws -> String? {
        let text = try String(contentsOf: checkedFile(path.value), encoding: .utf8)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return text.isEmpty ? nil : text
    }

    private func loadManifest() throws -> GiftManifest? {
        let url: URL
        do {
            url = try checkedFile("memories.json")
        } catch let error as CocoaError where error.code == .fileReadNoSuchFile || error.code == .fileNoSuchFile {
            return nil
        }
        return try JSONDecoder().decode(GiftManifest.self, from: Data(contentsOf: url))
    }

    private func checkedFile(_ relativePath: String) throws -> URL {
        var url = directory
        let keys: Set<URLResourceKey> = [.isDirectoryKey, .isRegularFileKey, .isSymbolicLinkKey]
        let components = relativePath.split(separator: "/")
        for (index, name) in components.enumerated() {
            let parent = try url.resourceValues(forKeys: keys)
            guard parent.isDirectory == true, parent.isSymbolicLink != true else {
                throw CocoaError(.fileReadCorruptFile)
            }
            url.append(path: String(name), directoryHint: index == components.count - 1 ? .notDirectory : .isDirectory)
        }
        let properties = try url.resourceValues(forKeys: keys)
        guard properties.isRegularFile == true, properties.isSymbolicLink != true else {
            throw CocoaError(.fileReadCorruptFile)
        }
        return url
    }
}
