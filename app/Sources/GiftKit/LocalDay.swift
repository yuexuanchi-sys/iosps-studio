import Foundation

/// Stores a civil day without allowing timezone or timestamp drift in saved data.
public struct LocalDay: Hashable, Comparable, Codable, Sendable {
    public let year: Int
    public let month: Int
    public let day: Int

    public enum ValidationError: Error {
        case invalidDate
    }

    /// Accepts exactly four ASCII year digits and two digits each for month and day.
    public init(isoDate: String) throws {
        let fields = isoDate.split(separator: "-", omittingEmptySubsequences: false)
        guard fields.count == 3,
              fields[0].utf8.count == 4,
              fields[1].utf8.count == 2,
              fields[2].utf8.count == 2,
              fields.allSatisfy({ $0.utf8.allSatisfy { (48...57).contains($0) } }),
              let year = Int(fields[0]), let month = Int(fields[1]), let day = Int(fields[2]) else {
            throw ValidationError.invalidDate
        }
        try self.init(year: year, month: month, day: day)
    }

    /// Converts an instant using the caller's chosen local timezone.
    public init(containing instant: Date, timeZone: TimeZone) throws {
        guard instant.timeIntervalSinceReferenceDate.isFinite else {
            throw ValidationError.invalidDate
        }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let components = calendar.dateComponents([.era, .year, .month, .day], from: instant)
        guard components.era == 1,
              let year = components.year, let month = components.month, let day = components.day else {
            throw ValidationError.invalidDate
        }
        try self.init(year: year, month: month, day: day)
    }

    init(year: Int, month: Int, day: Int) throws {
        guard (1...9999).contains(year), (1...12).contains(month),
              (1...Self.daysInMonth(year: year, month: month)).contains(day) else {
            throw ValidationError.invalidDate
        }
        self.year = year
        self.month = month
        self.day = day
    }

    /// Keeps dates ordered independently of the time of day.
    public static func < (lhs: Self, rhs: Self) -> Bool {
        lhs.ordinal < rhs.ordinal
    }

    /// Reads the same date-only representation used by the gift manifest.
    public init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        try self.init(isoDate: container.decode(String.self))
    }

    /// Writes a locale-independent date string.
    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode([Self.pad(year, to: 4), Self.pad(month, to: 2), Self.pad(day, to: 2)].joined(separator: "-"))
    }

    var ordinal: Int {
        let priorYears = year - 1
        let yearStart = priorYears * 365 + priorYears / 4 - priorYears / 100 + priorYears / 400
        let priorMonths = Self.monthStarts[month - 1]
        let leapDay = month > 2 && Self.isLeapYear(year) ? 1 : 0
        return yearStart + priorMonths + leapDay + day
    }

    func anniversary(in year: Int) throws -> Self {
        try Self(year: year, month: month, day: min(day, Self.daysInMonth(year: year, month: month)))
    }

    private static let monthStarts = [0, 31, 59, 90, 120, 151, 181, 212, 243, 273, 304, 334]
    private static let monthLengths = [31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31]

    private static func daysInMonth(year: Int, month: Int) -> Int {
        month == 2 && isLeapYear(year) ? 29 : monthLengths[month - 1]
    }

    private static func isLeapYear(_ year: Int) -> Bool {
        year.isMultiple(of: 4) && (!year.isMultiple(of: 100) || year.isMultiple(of: 400))
    }

    private static func pad(_ value: Int, to width: Int) -> String {
        let digits = String(value)
        return String(repeating: "0", count: width - digits.count) + digits
    }
}
