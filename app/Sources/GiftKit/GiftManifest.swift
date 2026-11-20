import Foundation

/// Keeps manifest lookups relative to the selected gift folder.
public struct GiftFilePath: Hashable, Decodable, Sendable {
    public let value: String

    /// Rejects path syntax that could resolve outside the gift folder.
    public init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        let path = try container.decode(String.self)
        // Check separators as bytes so Unicode graphemes cannot change path boundaries.
        let bytes = path.utf8
        let parts = bytes.split(separator: 0x2F, omittingEmptySubsequences: false)
        guard !path.isEmpty,
              !bytes.contains(0x5C), !bytes.contains(0x3A),
              bytes.allSatisfy({ $0 >= 0x20 && $0 != 0x7F }),
              parts.allSatisfy({ !$0.isEmpty && $0.last != 0x2E && $0.last != 0x20 }) else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid gift file path")
        }
        value = path
    }

    fileprivate var fileExtension: String {
        guard let name = value.split(separator: "/").last,
              let dot = name.lastIndex(of: "."), dot != name.startIndex else {
            return ""
        }
        return name[name.index(after: dot)...].lowercased()
    }

    fileprivate static let photoExtensions: Set<String> = ["jpg", "jpeg", "png", "heic"]
}

/// Preserves the caption and photo sequence for one memory event.
public struct GiftMemory: Equatable, Decodable, Sendable {
    public let id: String
    public let date: LocalDay
    public let title: String
    public let note: String?
    public let photos: [GiftFilePath]

    private enum CodingKeys: String, CodingKey {
        case id, date, title, note, photos
    }

    /// Requires enough event data to render a timeline card.
    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        date = try container.decode(LocalDay.self, forKey: .date)
        title = try container.decode(String.self, forKey: .title)
        note = try container.decodeIfPresent(String.self, forKey: .note)
        photos = try container.decode([GiftFilePath].self, forKey: .photos)

        guard !id.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw DecodingError.dataCorruptedError(forKey: .id, in: container, debugDescription: "Empty event ID")
        }
        guard !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw DecodingError.dataCorruptedError(forKey: .title, in: container, debugDescription: "Empty event title")
        }
        guard !photos.isEmpty, photos.allSatisfy({ GiftFilePath.photoExtensions.contains($0.fileExtension) }) else {
            throw DecodingError.dataCorruptedError(forKey: .photos, in: container, debugDescription: "Missing or unsupported event photo")
        }
    }
}

/// Validates gift metadata before a platform importer examines the files.
public struct GiftManifest: Equatable, Decodable, Sendable {
    public let birthday: LocalDay?
    public let metOn: LocalDay?
    public let wishesPath: GiftFilePath?
    public let audioPath: GiftFilePath?
    public let easterEggPath: GiftFilePath?
    public let featuredPhoto: GiftFilePath?
    public let memories: [GiftMemory]

    private enum CodingKeys: String, CodingKey {
        case schemaVersion, birthday, metOn, wishesPath, audioPath, easterEggPath, featuredPhoto, memories
    }

    /// Reads v1 and orders events without changing the order within the same day.
    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        guard try container.decode(Int.self, forKey: .schemaVersion) == 1 else {
            throw DecodingError.dataCorruptedError(forKey: .schemaVersion, in: container, debugDescription: "Unsupported gift schema version")
        }

        birthday = try container.decodeIfPresent(LocalDay.self, forKey: .birthday)
        metOn = try container.decodeIfPresent(LocalDay.self, forKey: .metOn)
        wishesPath = try Self.decodePath(.wishesPath, in: container, extensions: ["txt"])
        audioPath = try Self.decodePath(.audioPath, in: container, extensions: ["m4a", "mp3"])
        easterEggPath = try Self.decodePath(.easterEggPath, in: container, extensions: ["txt"])
        featuredPhoto = try Self.decodePath(.featuredPhoto, in: container, extensions: GiftFilePath.photoExtensions)

        let events = try container.decode([GiftMemory].self, forKey: .memories)
        guard Set(events.map(\.id)).count == events.count else {
            throw DecodingError.dataCorruptedError(forKey: .memories, in: container, debugDescription: "Duplicate event ID")
        }
        memories = events.enumerated().sorted { lhs, rhs in
            if lhs.element.date == rhs.element.date {
                return lhs.offset < rhs.offset
            }
            return lhs.element.date > rhs.element.date
        }.map { $0.element }
    }

    private static func decodePath(
        _ key: CodingKeys,
        in container: KeyedDecodingContainer<CodingKeys>,
        extensions: Set<String>
    ) throws -> GiftFilePath? {
        guard let path = try container.decodeIfPresent(GiftFilePath.self, forKey: key) else { return nil }
        guard extensions.contains(path.fileExtension) else {
            throw DecodingError.dataCorruptedError(forKey: key, in: container, debugDescription: "Unsupported gift file type")
        }
        return path
    }
}
