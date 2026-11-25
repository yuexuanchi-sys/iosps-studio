import BirthdayCore
import Foundation

/// Serializes disk access to independent, atomically replaced project snapshots.
public actor FileDraftStore: DraftStore {
    private let directory: URL

    public enum LoadError: Error {
        case mismatchedProjectID
    }

    /// Keeps drafts inside a directory owned by the application.
    public init(directory: URL) {
        self.directory = directory
    }

    /// Returns nil only when the expected snapshot file is absent.
    public func loadDraft(for id: ProjectID) async throws -> Project? {
        let data: Data
        do {
            data = try Data(contentsOf: fileURL(for: id))
        } catch let error as CocoaError where error.code == .fileReadNoSuchFile || error.code == .fileNoSuchFile {
            return nil
        }

        let project = try JSONDecoder().decode(Project.self, from: data)
        guard project.id == id else {
            throw LoadError.mismatchedProjectID
        }
        return project
    }

    /// Encodes before writing and keeps the last snapshot intact if replacement fails.
    public func saveDraft(_ project: Project) async throws {
        let data = try JSONEncoder().encode(project)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try data.write(to: fileURL(for: project.id), options: .atomic)
    }

    /// Reads the same project format from a user-selected file.
    public func openProject(at url: URL) throws -> Project {
        guard url.isFileURL else { throw CocoaError(.fileReadUnsupportedScheme) }
        let hasScope = url.startAccessingSecurityScopedResource()
        defer { if hasScope { url.stopAccessingSecurityScopedResource() } }
        return try JSONDecoder().decode(Project.self, from: Data(contentsOf: url))
    }

    /// Atomically replaces a user-selected project after successful encoding.
    public func saveProject(_ project: Project, at url: URL) throws {
        guard url.isFileURL else { throw CocoaError(.fileWriteUnsupportedScheme) }
        let hasScope = url.startAccessingSecurityScopedResource()
        defer { if hasScope { url.stopAccessingSecurityScopedResource() } }
        try JSONEncoder().encode(project).write(to: url, options: .atomic)
    }

    private func fileURL(for id: ProjectID) -> URL {
        directory.appendingPathComponent(id.rawValue.uuidString).appendingPathExtension("json")
    }
}
