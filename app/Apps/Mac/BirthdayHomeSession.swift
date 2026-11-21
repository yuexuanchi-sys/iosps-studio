import Foundation
import GiftKit
import Observation

@MainActor
@Observable
final class BirthdayHomeSession {
    private let directory: URL
    private var manifest: GiftManifest?
    private(set) var wishes: String?
    private(set) var reloadFailed = false

    var birthday: LocalDay? { manifest?.birthday }

    init(directory: URL) {
        self.directory = directory
        reload()
    }

    func metrics(on today: LocalDay) -> GiftMetrics {
        GiftCalendar.metrics(on: today, birthday: birthday, metOn: manifest?.metOn)
    }

    func reload() {
        do {
            let configuration = try loadManifest()
            let message = try configuration?.wishesPath.map { path in
                try String(contentsOf: checkedFile(path.value), encoding: .utf8)
            }
            manifest = configuration
            wishes = message?.trimmingCharacters(in: .whitespacesAndNewlines)
            reloadFailed = false
        } catch {
            reloadFailed = true
        }
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
