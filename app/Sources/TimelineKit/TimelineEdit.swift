import BirthdayCore

/// Describes a single edit on the current sequence. Trim and split offsets are clip-relative.
public enum TimelineEdit: Sendable {
    case trim(clip: Int, from: Int, to: Int)
    case split(clip: Int, at: Int)
    case delete(clip: Int)
    /// Moves a clip to its index in the final sequence.
    case move(from: Int, to: Int)

    fileprivate var sourceIndex: Int {
        switch self {
        case .trim(let clip, _, _), .split(let clip, _), .delete(let clip), .move(let clip, _):
            clip
        }
    }
}

/// Captures a validated edit so undo and redo restore the exact clips and transitions.
public struct TimelineEditCommand: EditCommand {
    public enum ValidationError: Error, Equatable {
        case invalidClipIndex
        case invalidOffset
        case unchanged
        case staleTimeline
    }

    private struct Slot {
        let originalIndex: Int
        var clip: TimelineClip
    }

    private let original: Timeline
    private let edited: Timeline

    /// Computes and validates the modified timeline before the undo stack records it.
    public init(_ edit: TimelineEdit, on original: Timeline) throws {
        let index = edit.sourceIndex
        guard original.clips.indices.contains(index) else { throw ValidationError.invalidClipIndex }
        var slots = original.clips.enumerated().map { Slot(originalIndex: $0.offset, clip: $0.element) }
        let source = slots[index]

        switch edit {
        case .trim(_, let start, let end):
            slots[index].clip = try Self.slice(source.clip, from: start, to: end)
        case .split(_, let offset):
            let first = try Self.slice(source.clip, from: 0, to: offset)
            let second = try Self.slice(source.clip, from: offset, to: source.clip.frameCount)
            slots[index].clip = first
            slots.insert(Slot(originalIndex: index, clip: second), at: index + 1)
        case .delete:
            slots.remove(at: index)
        case .move(_, let destination):
            guard slots.indices.contains(destination) else { throw ValidationError.invalidClipIndex }
            slots.remove(at: index)
            slots.insert(source, at: destination)
        }

        // An existing transition belongs to the two clips that originally shared the boundary.
        let overlaps = zip(slots, slots.dropFirst()).map { left, right in
            right.originalIndex == left.originalIndex + 1 ? original.overlaps[left.originalIndex] : 0
        }
        let edited = try Timeline(clips: slots.map(\.clip), overlaps: overlaps)
        guard edited != original else { throw ValidationError.unchanged }
        self.original = original
        self.edited = edited
    }

    /// Rejects positions calculated against a different timeline state.
    public func apply(to state: inout Timeline) throws {
        guard state == original else { throw ValidationError.staleTimeline }
        state = edited
    }

    /// Restores the previous source ranges and transition boundaries.
    public func revert(on state: inout Timeline) throws {
        guard state == edited else { throw ValidationError.staleTimeline }
        state = original
    }

    private static func slice(_ clip: TimelineClip, from start: Int, to end: Int) throws -> TimelineClip {
        guard start >= 0, start < end, end <= clip.frameCount else { throw ValidationError.invalidOffset }
        return try TimelineClip(media: clip.media, startFrame: clip.startFrame + start, frameCount: end - start)
    }
}
