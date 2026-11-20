/// Describes a replayable edit with no side effects beyond the state it receives.
public protocol EditCommand<State>: Sendable {
    associatedtype State: Sendable

    /// Makes the edit using the information captured by the command.
    func apply(to state: inout State) throws

    /// Restores the prior value needed to reverse the edit.
    func revert(on state: inout State) throws
}

/// Owns value-semantic editor state and keeps the latest twenty committed edits.
public struct UndoStack<State: Sendable>: Sendable {
    public private(set) var state: State
    private var undoCommands: [any EditCommand<State>] = []
    private var redoCommands: [any EditCommand<State>] = []

    /// Starts a fresh history for a new project or a restored draft.
    public init(initialState: State) {
        state = initialState
    }

    public var canUndo: Bool { !undoCommands.isEmpty }
    public var canRedo: Bool { !redoCommands.isEmpty }

    /// Commits a successful edit and discards the abandoned redo branch.
    public mutating func perform(_ command: any EditCommand<State>) throws {
        var candidate = state
        try command.apply(to: &candidate)
        state = candidate
        undoCommands.append(command)
        if undoCommands.count > 20 {
            undoCommands.removeFirst()
        }
        redoCommands.removeAll()
    }

    /// Leaves the current state and both histories intact if reversal fails.
    @discardableResult
    public mutating func undo() throws -> Bool {
        guard let command = undoCommands.last else { return false }
        var candidate = state
        try command.revert(on: &candidate)
        state = candidate
        undoCommands.removeLast()
        redoCommands.append(command)
        return true
    }

    /// Returns false when there is no abandoned edit to replay.
    @discardableResult
    public mutating func redo() throws -> Bool {
        guard let command = redoCommands.last else { return false }
        var candidate = state
        try command.apply(to: &candidate)
        state = candidate
        redoCommands.removeLast()
        undoCommands.append(command)
        return true
    }
}
