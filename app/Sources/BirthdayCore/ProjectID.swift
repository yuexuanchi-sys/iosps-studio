import Foundation

/// Preserves project identity across file moves and draft reloads.
public struct ProjectID: Hashable, Codable, Sendable {
    public let rawValue: UUID

    /// Uses a generated identity unless the caller is restoring one.
    public init(rawValue: UUID = UUID()) {
        self.rawValue = rawValue
    }

    /// Reads a single UUID string to keep the saved representation stable.
    public init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        let string = try container.decode(String.self)
        guard let value = UUID(uuidString: string) else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid project UUID")
        }
        self.init(rawValue: value)
    }

    /// Encodes the identity independent of the platform's UUID representation.
    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue.uuidString)
    }
}
