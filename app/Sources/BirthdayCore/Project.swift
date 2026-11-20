import Foundation

/// Identifies media in the local library without storing a machine-specific URL.
public struct MediaID: Hashable, Codable, Sendable {
    public let rawValue: UUID

    /// Keeps references stable when the media library is moved.
    public init(rawValue: UUID = UUID()) {
        self.rawValue = rawValue
    }
}

/// Describes the source of a non-destructive photo edit.
public struct PhotoEditDocument: Equatable, Codable, Sendable {
    public let source: MediaID

    /// References the imported original by its library identity.
    public init(source: MediaID) {
        self.source = source
    }
}

/// Preserves video source order and permits repeated uses of one original.
public struct VideoProject: Equatable, Codable, Sendable {
    public var sources: [MediaID]

    /// Accepts an empty sequence for drafts created before import.
    public init(sources: [MediaID]) {
        self.sources = sources
    }
}

/// Distinguishes the payloads behind the same project storage format.
public enum ProjectContent: Equatable, Sendable {
    case photo(PhotoEditDocument)
    case video(VideoProject)
}

/// Stores a stable project identity and an explicitly versioned payload.
public struct Project: Equatable, Codable, Sendable {
    public let id: ProjectID
    public var content: ProjectContent

    private static let schemaVersion = 1

    private enum CodingKeys: String, CodingKey {
        case schemaVersion, id, kind, payload
    }

    private enum Kind: String, Codable {
        case photo, video
    }

    /// Lets a caller preserve identity when reconstructing a draft.
    public init(id: ProjectID = ProjectID(), content: ProjectContent) {
        self.id = id
        self.content = content
    }

    /// Rejects versions it cannot safely interpret.
    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let version = try container.decode(Int.self, forKey: .schemaVersion)
        guard version == Self.schemaVersion else {
            throw DecodingError.dataCorruptedError(
                forKey: .schemaVersion,
                in: container,
                debugDescription: "Unsupported project schema version"
            )
        }

        let id = try container.decode(ProjectID.self, forKey: .id)
        let content: ProjectContent
        switch try container.decode(Kind.self, forKey: .kind) {
        case .photo:
            content = .photo(try container.decode(PhotoEditDocument.self, forKey: .payload))
        case .video:
            content = .video(try container.decode(VideoProject.self, forKey: .payload))
        }
        self.init(id: id, content: content)
    }

    /// Writes an explicit kind so future Swift type changes preserve the file format.
    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(Self.schemaVersion, forKey: .schemaVersion)
        try container.encode(id, forKey: .id)
        switch content {
        case .photo(let document):
            try container.encode(Kind.photo, forKey: .kind)
            try container.encode(document, forKey: .payload)
        case .video(let project):
            try container.encode(Kind.video, forKey: .kind)
            try container.encode(project, forKey: .payload)
        }
    }
}
