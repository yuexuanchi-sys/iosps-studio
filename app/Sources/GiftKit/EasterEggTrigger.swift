/// Counts consecutive activations within a short, monotonic interval.
public struct EasterEggTrigger {
    private var start: ContinuousClock.Instant?
    private var taps = 0

    public init() {}

    /// Returns true on the third tap, then begins a new sequence.
    public mutating func registerTap(at now: ContinuousClock.Instant) -> Bool {
        if let first = start, now >= first, first.duration(to: now) <= .seconds(2) {
            taps += 1
        } else {
            start = now
            taps = 1
        }
        guard taps == 3 else { return false }
        self = Self()
        return true
    }
}
