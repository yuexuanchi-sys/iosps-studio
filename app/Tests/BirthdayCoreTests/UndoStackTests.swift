import XCTest
@testable import BirthdayCore

private enum CommandFailure: Error {
    case apply
    case revert
}

private struct Move: EditCommand {
    let from: Int
    let to: Int
    var failsApply = false
    var failsRevert = false

    func apply(to state: inout Int) throws {
        state = to
        if failsApply { throw CommandFailure.apply }
    }

    func revert(on state: inout Int) throws {
        state = from
        if failsRevert { throw CommandFailure.revert }
    }
}

final class UndoStackTests: XCTestCase {
    func testEmptyHistoryIsANoOp() throws {
        var history = UndoStack(initialState: Int.min)
        XCTAssertFalse(try history.undo())
        XCTAssertFalse(try history.redo())
        XCTAssertEqual(history.state, Int.min)
    }

    func testUndoAndRedoRestoreState() throws {
        var history = UndoStack(initialState: Int.min)
        try history.perform(Move(from: Int.min, to: Int.max))
        XCTAssertTrue(try history.undo())
        XCTAssertEqual(history.state, Int.min)
        XCTAssertTrue(try history.redo())
        XCTAssertEqual(history.state, Int.max)
    }

    func testNewEditDiscardsRedo() throws {
        var history = UndoStack(initialState: 0)
        try history.perform(Move(from: 0, to: 1))
        try history.undo()
        try history.perform(Move(from: 0, to: 2))
        XCTAssertFalse(try history.redo())
        XCTAssertEqual(history.state, 2)
    }

    func testDefaultLimitKeepsLatestTwentyEdits() throws {
        var history = UndoStack(initialState: 0)
        for value in 1...25 {
            try history.perform(Move(from: value - 1, to: value))
        }
        for _ in 0..<20 {
            XCTAssertTrue(try history.undo())
        }
        XCTAssertFalse(try history.undo())
        XCTAssertEqual(history.state, 5)
    }

    func testFailedApplyPreservesStateAndRedo() throws {
        var history = UndoStack(initialState: 0)
        try history.perform(Move(from: 0, to: 1))
        try history.undo()
        XCTAssertThrowsError(try history.perform(Move(from: 0, to: 2, failsApply: true)))
        XCTAssertEqual(history.state, 0)
        XCTAssertFalse(history.canUndo)
        XCTAssertTrue(try history.redo())
        XCTAssertEqual(history.state, 1)
    }

    func testFailedRevertPreservesStateAndUndo() throws {
        var history = UndoStack(initialState: 0)
        try history.perform(Move(from: 0, to: 1, failsRevert: true))
        XCTAssertThrowsError(try history.undo())
        XCTAssertEqual(history.state, 1)
        XCTAssertTrue(history.canUndo)
        XCTAssertFalse(history.canRedo)
    }
}
