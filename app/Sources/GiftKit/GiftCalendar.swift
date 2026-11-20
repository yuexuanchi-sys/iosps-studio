/// Groups the values shown together on the birthday page.
public struct GiftMetrics: Equatable, Sendable {
    public let daysUntilBirthday: Int?
    public let age: Int?
    public let daysSinceMeeting: Int?
    public let isBirthday: Bool
}

/// Calculates gift metrics by civil day to avoid daylight saving gaps.
public enum GiftCalendar {
    /// Omits metrics for missing or future dates and observes leap birthdays on February's last day.
    public static func metrics(
        on today: LocalDay,
        birthday: LocalDay? = nil,
        metOn: LocalDay? = nil
    ) -> GiftMetrics {
        let elapsed: Int? = metOn.flatMap { $0 <= today ? today.ordinal - $0.ordinal : nil }

        guard let birthday, birthday <= today,
              let anniversary = try? birthday.anniversary(in: today.year) else {
            return GiftMetrics(daysUntilBirthday: nil, age: nil, daysSinceMeeting: elapsed, isBirthday: false)
        }

        let hasPassed = anniversary < today
        let next: LocalDay? = hasPassed ? (try? birthday.anniversary(in: today.year + 1)) : anniversary
        return GiftMetrics(
            daysUntilBirthday: next.map { $0.ordinal - today.ordinal },
            age: today.year - birthday.year - (today < anniversary ? 1 : 0),
            daysSinceMeeting: elapsed,
            isBirthday: today == anniversary
        )
    }
}
