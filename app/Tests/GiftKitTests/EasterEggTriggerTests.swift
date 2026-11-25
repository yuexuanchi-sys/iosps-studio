import GiftKit
import Testing

struct EasterEggTriggerTests {
    @Test func thirdTapOpensAndClearsTheSequence() {
        let start = ContinuousClock.now
        var trigger = EasterEggTrigger()
        #expect(!trigger.registerTap(at: start))
        #expect(!trigger.registerTap(at: start.advanced(by: .milliseconds(350))))
        #expect(trigger.registerTap(at: start.advanced(by: .seconds(2))))
        #expect(!trigger.registerTap(at: start.advanced(by: .milliseconds(2100))))
    }

    @Test func timeoutStartsANewSequence() {
        let start = ContinuousClock.now
        var trigger = EasterEggTrigger()
        #expect(!trigger.registerTap(at: start))
        #expect(!trigger.registerTap(at: start.advanced(by: .seconds(1))))
        #expect(!trigger.registerTap(at: start.advanced(by: .milliseconds(2001))))
        #expect(!trigger.registerTap(at: start.advanced(by: .milliseconds(2200))))
        #expect(trigger.registerTap(at: start.advanced(by: .milliseconds(2500))))
    }
}
