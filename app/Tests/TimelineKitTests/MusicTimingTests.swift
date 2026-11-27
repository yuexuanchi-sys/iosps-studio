import BirthdayCore
import XCTest
@testable import TimelineKit

final class MusicTimingTests: XCTestCase {
    func testEqualDurationPacingDistributesRemainderAndBuildsValidTimeline() throws {
        let plan = try MusicBeatAllocator.allocate(
            photoCount: 3,
            targetDurationFrames: 100,
            preferredOverlaps: [10, 10]
        )
        // Net frames: 34, 33, 33 -> sceneFrames with outgoing overlaps: 44, 43, 33
        XCTAssertEqual(plan.sceneFrames, [44, 43, 33])
        XCTAssertEqual(plan.overlaps, [10, 10])
        XCTAssertEqual(plan.totalFrames, 100)
        XCTAssertEqual(plan.fadeInFrames, 15)
        XCTAssertEqual(plan.fadeOutFrames, 30)

        let media = [MediaID(), MediaID(), MediaID()]
        let timeline = try plan.timeline(for: media)
        XCTAssertEqual(timeline.durationFrames, 100)
        XCTAssertEqual(timeline.clipStartFrames, [0, 34, 67])
    }

    func testBeatPacingSnapsCutsToBeatGridAndPreservesExactDuration() throws {
        // 120 BPM => 15 frames per beat; 3 photos in 90 frames snap cleanly to beats 30 and 60.
        let plan = try MusicBeatAllocator.allocate(
            photoCount: 3,
            targetDurationFrames: 90,
            beatsPerMinute: 120,
            preferredOverlaps: [12, 12]
        )
        XCTAssertEqual(plan.sceneFrames, [42, 42, 30])
        XCTAssertEqual(plan.overlaps, [12, 12])
        let timeline = try plan.timeline(for: [MediaID(), MediaID(), MediaID()])
        XCTAssertEqual(timeline.clipStartFrames, [0, 30, 60])
        XCTAssertEqual(timeline.durationFrames, 90)

        // Non-integer beat spacing (128 BPM => 14.0625 frames/beat) still sums exactly to 120 frames.
        let nonInteger = try MusicBeatAllocator.allocate(
            photoCount: 4,
            targetDurationFrames: 120,
            beatsPerMinute: 128,
            preferredOverlaps: [6, 6, 6]
        )
        let nonIntegerTimeline = try nonInteger.timeline(for: (0..<4).map { _ in MediaID() })
        XCTAssertEqual(nonIntegerTimeline.durationFrames, 120)
        // Cuts should align with nearest rounded 128 BPM beat frames: 28 (2 beats), 56 (4 beats), 84 (6 beats).
        XCTAssertEqual(nonIntegerTimeline.clipStartFrames, [0, 28, 56, 84])
    }

    func testHighOverlapRequestsAreClampedForValidTimeline() throws {
        let plan = try MusicBeatAllocator.allocate(
            photoCount: 3,
            targetDurationFrames: 15,
            preferredOverlaps: [20, 20],
            defaultFadeInFrames: 15,
            defaultFadeOutFrames: 30
        )
        // Net frames are [5, 5, 5], so max safe overlap is min(5, 5 - 1) = 4.
        XCTAssertEqual(plan.overlaps, [4, 4])
        XCTAssertEqual(plan.sceneFrames, [9, 9, 5])
        XCTAssertEqual(plan.fadeInFrames + plan.fadeOutFrames, 15)
        XCTAssertEqual(plan.fadeInFrames, 5)
        XCTAssertEqual(plan.fadeOutFrames, 10)
        let timeline = try plan.timeline(for: [MediaID(), MediaID(), MediaID()])
        XCTAssertEqual(timeline.durationFrames, 15)
        XCTAssertEqual(timeline.clipStartFrames, [0, 5, 10])
    }

    func testExtremeBPMAndInvalidInputsAreHandledDeterministically() throws {
        let ultraSlow = try MusicBeatAllocator.allocate(
            photoCount: 2,
            targetDurationFrames: 30,
            beatsPerMinute: 1
        )
        XCTAssertEqual(ultraSlow.sceneFrames, [15, 15])

        let ultraFast = try MusicBeatAllocator.allocate(
            photoCount: 2,
            targetDurationFrames: 30,
            beatsPerMinute: 10_000
        )
        XCTAssertEqual(ultraFast.sceneFrames, [15, 15])

        let maxLimit = try MusicBeatAllocator.allocate(
            photoCount: 1,
            targetDurationFrames: VideoTiming.maxOutputFrames
        )
        XCTAssertEqual(maxLimit.totalFrames, VideoTiming.maxOutputFrames)

        XCTAssertThrowsError(try MusicBeatAllocator.allocate(photoCount: 0, targetDurationFrames: 30))
        XCTAssertThrowsError(try MusicBeatAllocator.allocate(photoCount: 5, targetDurationFrames: 4))
        XCTAssertThrowsError(try MusicBeatAllocator.allocate(photoCount: 1, targetDurationFrames: VideoTiming.maxOutputFrames + 1))
        XCTAssertThrowsError(try MusicBeatAllocator.allocate(photoCount: 2, targetDurationFrames: 30, beatsPerMinute: 0))
        XCTAssertThrowsError(try MusicBeatAllocator.allocate(photoCount: 2, targetDurationFrames: 30, beatsPerMinute: .nan))
        XCTAssertThrowsError(try MusicBeatAllocator.allocate(photoCount: 2, targetDurationFrames: 30, preferredOverlaps: [5, 5]))
        XCTAssertThrowsError(try MusicBeatAllocator.allocate(photoCount: 2, targetDurationFrames: 30, preferredOverlaps: [-1]))
    }

    func testAudioPlanValidatesExcerptBoundsScalesShortFadesAndLoopsSamples() throws {
        let plan = try MusicAudioPlan(
            sourceStartFrame: 30,
            requestedExcerptFrames: 30,
            availableSourceFrames: 60,
            outputFrames: 90,
            fadeInFrames: 15,
            fadeOutFrames: 30
        )
        let sampleRate = 44_100
        let totalSamples = 90 * 1_470
        // Fade-in strictly rises across [0, 0.5s), plateau stays 1.0, fade-out falls across [2.0s, 3.0s).
        XCTAssertEqual(plan.gain(atSample: 0, totalSamples: totalSamples, sampleRate: sampleRate), 0.0, accuracy: 0.0001)
        XCTAssertEqual(plan.gain(atSample: 11_025, totalSamples: totalSamples, sampleRate: sampleRate), 0.5, accuracy: 0.001)
        XCTAssertEqual(plan.gain(atSample: 44_100, totalSamples: totalSamples, sampleRate: sampleRate), 1.0, accuracy: 0.0001)
        XCTAssertLessThan(
            plan.gain(atSample: totalSamples - 10_000, totalSamples: totalSamples, sampleRate: sampleRate),
            plan.gain(atSample: totalSamples - 30_000, totalSamples: totalSamples, sampleRate: sampleRate)
        )
        XCTAssertEqual(plan.gain(atSample: totalSamples - 1, totalSamples: totalSamples, sampleRate: sampleRate), 0.0, accuracy: 0.0001)

        // Excerpt starts at sample 44,100 and wraps every 44,100 samples.
        XCTAssertEqual(plan.sourceSampleOffset(forOutputSample: 0, sampleRate: sampleRate), 44_100)
        XCTAssertEqual(plan.sourceSampleOffset(forOutputSample: 44_100, sampleRate: sampleRate), 44_100)
        XCTAssertEqual(plan.sourceSampleOffset(forOutputSample: 44_105, sampleRate: sampleRate), 44_105)

        // Short movie scales fades proportionally so their sum fits inside outputFrames.
        let shortPlan = try MusicAudioPlan(
            sourceStartFrame: 0,
            requestedExcerptFrames: nil,
            availableSourceFrames: 60,
            outputFrames: 12,
            fadeInFrames: 15,
            fadeOutFrames: 30
        )
        XCTAssertEqual(shortPlan.excerptFrames, 60)
        XCTAssertEqual(shortPlan.fadeInFrames, 4)
        XCTAssertEqual(shortPlan.fadeOutFrames, 8)

        // Reject out-of-range excerpts and invalid source durations.
        XCTAssertThrowsError(try MusicAudioPlan(sourceStartFrame: 31, requestedExcerptFrames: 30, availableSourceFrames: 60, outputFrames: 60))
        XCTAssertThrowsError(try MusicAudioPlan(sourceStartFrame: 60, requestedExcerptFrames: nil, availableSourceFrames: 60, outputFrames: 60))
        XCTAssertThrowsError(try MusicAudioPlan(sourceStartFrame: -1, requestedExcerptFrames: 10, availableSourceFrames: 60, outputFrames: 60))
        XCTAssertThrowsError(try MusicAudioPlan(sourceStartFrame: 0, requestedExcerptFrames: 0, availableSourceFrames: 60, outputFrames: 60))
        XCTAssertThrowsError(try MusicAudioPlan(sourceStartFrame: 0, requestedExcerptFrames: 10, availableSourceFrames: 0, outputFrames: 60))
    }
}
