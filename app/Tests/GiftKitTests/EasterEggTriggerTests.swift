import GiftKit
import Testing

struct EasterEggTriggerTests {
    @Test func thirdTapOpensAndClearsTheSequence() {
        let start = ContinuousClock.now
        var trigger = EasterEggTrigger()
        let results = [0, 350, 2000, 2100].map { offset in
            trigger.registerTap(at: start.advanced(by: .milliseconds(offset)))
        }
        #expect(results == [false, false, true, false])
    }

    @Test func timeoutStartsANewSequence() {
        let start = ContinuousClock.now
        var trigger = EasterEggTrigger()
        let results = [0, 1000, 2001, 2200, 2500].map { offset in
            trigger.registerTap(at: start.advanced(by: .milliseconds(offset)))
        }
        #expect(results == [false, false, false, false, true])
    }
}
