/// Keeps draft persistence on the platform side of the dependency boundary.
public protocol DraftStore: Sendable {
    /// Distinguishes a missing draft from a read or decoding failure.
    func loadDraft(for id: ProjectID) async throws -> Project?

    /// Replaces the whole draft atomically so a failed write preserves the last good copy.
    func saveDraft(_ project: Project) async throws
}
