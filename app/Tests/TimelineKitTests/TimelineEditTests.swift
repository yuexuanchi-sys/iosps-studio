import BirthdayCore
import Foundation
import TimelineKit
import XCTest

final class TimelineEditTests: XCTestCase {
    func testTrimSplitReorderAndDeleteUseExactFrameBoundaries() throws {
        let a = MediaID()
        let b = MediaID()
        let initial = try Timeline(
            clips: [
                TimelineClip(media: a, startFrame: 8, frameCount: 60),
                TimelineClip(media: b, startFrame: 12, frameCount: 30),
            ],
            overlaps: [0]
        )
        var history = UndoStack(initialState: initial)
        try history.perform(TimelineEditCommand(.trim(clip: 0, from: 12, to: 42), on: history.state))
        try history.perform(TimelineEditCommand(.split(clip: 0, at: 10), on: history.state))
        try history.perform(TimelineEditCommand(.move(from: 2, to: 1), on: history.state))
        XCTAssertEqual(history.state.clips.map(\.media), [a, b, a])
        XCTAssertEqual(history.state.clips.map(\.startFrame), [20, 12, 30])
        XCTAssertEqual(history.state.clips.map(\.frameCount), [10, 30, 20])
        XCTAssertEqual(history.state.clipStartFrames, [0, 10, 40])
        try history.perform(TimelineEditCommand(.delete(clip: 0), on: history.state))
        XCTAssertEqual(history.state.clips.map(\.media), [b, a])
        XCTAssertEqual(history.state.clipStartFrames, [0, 30])
        XCTAssertEqual(history.state.durationFrames, 50)

        let final = history.state
        for _ in 0..<4 { XCTAssertTrue(try history.undo()) }
        XCTAssertEqual(history.state, initial)
        for _ in 0..<4 { XCTAssertTrue(try history.redo()) }
        XCTAssertEqual(history.state, final)
        XCTAssertEqual(try JSONDecoder().decode(Timeline.self, from: JSONEncoder().encode(final)), final)
    }

    func testUnchangedAdjacentClipsKeepTheirTransition() throws {
        let original = try Timeline(
            clips: (0..<4).map { try TimelineClip(media: MediaID(), startFrame: $0, frameCount: 30) },
            overlaps: [3, 5, 7]
        )
        var history = UndoStack(initialState: original)
        try history.perform(TimelineEditCommand(.move(from: 1, to: 3), on: original))
        XCTAssertEqual(history.state.overlaps, [0, 7, 0])
        XCTAssertTrue(try history.undo())
        try history.perform(TimelineEditCommand(.split(clip: 1, at: 15), on: original))
        XCTAssertEqual(history.state.overlaps, [3, 0, 5, 7])
        XCTAssertFalse(history.canRedo)
        XCTAssertTrue(try history.undo())
        try history.perform(TimelineEditCommand(.delete(clip: 1), on: original))
        XCTAssertEqual(history.state.overlaps, [0, 7])
    }

    func testInvalidAndStaleEditsLeaveHistoryAndStateIntact() throws {
        let clip = try TimelineClip(media: MediaID(), startFrame: .max - 20, frameCount: 20)
        let initial = try Timeline(clips: [clip, clip], overlaps: [5])
        var history = UndoStack(initialState: initial)
        let stale = try TimelineEditCommand(.delete(clip: 1), on: initial)

        let invalid: [TimelineEdit] = [
            .split(clip: 0, at: .min), .split(clip: 0, at: 0), .split(clip: 0, at: 20),
            .trim(clip: 0, from: 0, to: 0), .trim(clip: 0, from: 0, to: .max),
            .trim(clip: 0, from: 0, to: 20), .trim(clip: 0, from: 0, to: 5),
            .move(from: 0, to: 0), .move(from: 1, to: 2), .delete(clip: -1),
        ]
        for edit in invalid {
            XCTAssertThrowsError(try TimelineEditCommand(edit, on: history.state))
        }
        XCTAssertEqual(history.state, initial)
        XCTAssertFalse(history.canUndo || history.canRedo)

        try history.perform(TimelineEditCommand(.split(clip: 0, at: 10), on: initial))
        let edited = history.state
        XCTAssertThrowsError(try history.perform(stale))
        XCTAssertEqual(history.state, edited)
        XCTAssertEqual(edited.clips[1].startFrame, .max - 10)
        XCTAssertTrue(try history.undo())
        XCTAssertEqual(history.state, initial)
    }

    func testDeletingLastClipReturnsAnEmptyDraft() throws {
        let clip = try TimelineClip(media: MediaID(), startFrame: 0, frameCount: 1)
        let initial = try Timeline(clips: [clip], overlaps: [])
        var history = UndoStack(initialState: initial)
        try history.perform(TimelineEditCommand(.delete(clip: 0), on: initial))
        XCTAssertTrue(history.state.clips.isEmpty)
        XCTAssertEqual(history.state.durationFrames, 0)
        XCTAssertTrue(try history.undo())
        XCTAssertEqual(history.state, initial)
    }
}
