import Foundation

/// Represents one saved photo editing work in the local memories timeline.
public struct PhotoMemoryEntry: Equatable, Hashable, Codable, Sendable, Identifiable {
    public let id: ProjectID
    public var title: String
    public var projectPath: String
    public var previewMediaID: MediaID
    public var savedAt: Date
    public var pixelWidth: Int
    public var pixelHeight: Int

    public init(
        id: ProjectID,
        title: String,
        projectPath: String,
        previewMediaID: MediaID,
        savedAt: Date,
        pixelWidth: Int,
        pixelHeight: Int
    ) {
        self.id = id
        self.title = title
        self.projectPath = projectPath
        self.previewMediaID = previewMediaID
        self.savedAt = savedAt
        self.pixelWidth = pixelWidth
        self.pixelHeight = pixelHeight
    }
}

/// Groups timeline entries under one local calendar day while preserving descending order.
public struct PhotoMemoryDayGroup: Equatable, Sendable, Identifiable {
    public let id: String
    public let year: Int
    public let month: Int
    public let day: Int
    public let entries: [PhotoMemoryEntry]

    public init(year: Int, month: Int, day: Int, entries: [PhotoMemoryEntry]) {
        self.year = year
        self.month = month
        self.day = day
        self.entries = entries
        let y = String(format: "%04d", year)
        let m = String(format: "%02d", month)
        let d = String(format: "%02d", day)
        self.id = "\(y)-\(m)-\(d)"
    }
}

/// Pure-logic index of saved photo works ordered by latest save time descending with stable ID tie-breaking.
public struct PhotoMemoryTimeline: Equatable, Codable, Sendable {
    public static let schemaVersion = 1

    public private(set) var entries: [PhotoMemoryEntry]

    private enum CodingKeys: String, CodingKey {
        case schemaVersion
        case entries
    }

    public init(entries: [PhotoMemoryEntry] = []) {
        self.entries = Self.normalize(entries)
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let version = try container.decode(Int.self, forKey: .schemaVersion)
        guard version == Self.schemaVersion else {
            throw DecodingError.dataCorruptedError(
                forKey: .schemaVersion,
                in: container,
                debugDescription: "Unsupported photo memory timeline schema version"
            )
        }
        let decoded = try container.decode([PhotoMemoryEntry].self, forKey: .entries)
        self.entries = Self.normalize(decoded)
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(Self.schemaVersion, forKey: .schemaVersion)
        try container.encode(entries, forKey: .entries)
    }

    /// Inserts or updates a saved photo work idempotently by its stable `ProjectID` and re-sorts canonically.
    public mutating func record(_ entry: PhotoMemoryEntry) {
        entries.removeAll { $0.id == entry.id }
        entries.append(entry)
        entries.sort(by: Self.isOrderedBefore)
    }

    /// Removes the entry with the given stable identifier if present.
    public mutating func remove(id: ProjectID) {
        entries.removeAll { $0.id == id }
    }

    /// Looks up a single entry by stable identifier.
    public func entry(for id: ProjectID) -> PhotoMemoryEntry? {
        entries.first { $0.id == id }
    }

    /// Buckets sorted entries into local calendar days using the supplied time zone.
    public func groupedByDay(in timeZone: TimeZone = .autoupdatingCurrent) -> [PhotoMemoryDayGroup] {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone

        var groups: [PhotoMemoryDayGroup] = []
        var currentKey: (year: Int, month: Int, day: Int)?
        var currentEntries: [PhotoMemoryEntry] = []

        for entry in entries {
            let parts = calendar.dateComponents([.year, .month, .day], from: entry.savedAt)
            let year = parts.year ?? 1970
            let month = parts.month ?? 1
            let day = parts.day ?? 1
            if let key = currentKey, key.year == year && key.month == month && key.day == day {
                currentEntries.append(entry)
            } else {
                if let key = currentKey {
                    groups.append(PhotoMemoryDayGroup(year: key.year, month: key.month, day: key.day, entries: currentEntries))
                }
                currentKey = (year, month, day)
                currentEntries = [entry]
            }
        }
        if let key = currentKey {
            groups.append(PhotoMemoryDayGroup(year: key.year, month: key.month, day: key.day, entries: currentEntries))
        }
        return groups
    }

    private static func normalize(_ raw: [PhotoMemoryEntry]) -> [PhotoMemoryEntry] {
        var byID: [ProjectID: PhotoMemoryEntry] = [:]
        for item in raw {
            if let existing = byID[item.id] {
                if item.savedAt >= existing.savedAt {
                    byID[item.id] = item
                }
            } else {
                byID[item.id] = item
            }
        }
        return byID.values.sorted(by: isOrderedBefore)
    }

    private static func isOrderedBefore(_ lhs: PhotoMemoryEntry, _ rhs: PhotoMemoryEntry) -> Bool {
        if lhs.savedAt != rhs.savedAt {
            return lhs.savedAt > rhs.savedAt
        }
        return lhs.id.rawValue.uuidString < rhs.id.rawValue.uuidString
    }
}
