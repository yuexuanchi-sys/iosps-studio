import BirthdayCore
import Foundation
import MediaIO
import Testing

struct FileDraftStoreTests {
    @Test func missingDraftReturnsNil() async throws {
        let directory = try makeDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = FileDraftStore(directory: directory.appendingPathComponent("drafts", isDirectory: true))

        let loaded = try await store.loadDraft(for: ProjectID())
        #expect(loaded == nil)
    }

    @Test func replacementSurvivesReopeningAndKeepsAnotherDraft() async throws {
        let directory = try makeDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = FileDraftStore(directory: directory.appendingPathComponent("drafts", isDirectory: true))
        let first = Project(content: .video(VideoProject(sources: [])))
        let other = Project(content: .photo(PhotoEditDocument(source: MediaID())))
        let updated = Project(id: first.id, content: .video(VideoProject(sources: [MediaID()])))
        try await store.saveDraft(first)
        try await store.saveDraft(other)
        try await store.saveDraft(updated)

        let reopened = FileDraftStore(directory: directory.appendingPathComponent("drafts", isDirectory: true))
        let loaded = try await reopened.loadDraft(for: first.id)
        let loadedOther = try await reopened.loadDraft(for: other.id)
        #expect(loaded == updated)
        #expect(loadedOther == other)
    }

    @Test func concurrentWritesLeaveOneWholeSnapshot() async throws {
        let directory = try makeDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = FileDraftStore(directory: directory)
        let first = Project(content: .photo(PhotoEditDocument(source: MediaID())))
        let second = Project(id: first.id, content: .video(VideoProject(sources: [MediaID(), MediaID()])))
        async let writeFirst: Void = store.saveDraft(first)
        async let writeSecond: Void = store.saveDraft(second)
        _ = try await (writeFirst, writeSecond)

        let loaded = try await store.loadDraft(for: first.id)
        #expect(loaded == first || loaded == second)
    }

    @Test func corruptJSONIsAnError() async throws {
        let directory = try makeDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let id = ProjectID()
        try Data("{invalid json".utf8).write(to: fileURL(for: id, in: directory))

        let store = FileDraftStore(directory: directory)
        do {
            _ = try await store.loadDraft(for: id)
            Issue.record("Expected a decoding error")
        } catch is DecodingError {
            return
        }
    }

    @Test func mismatchedProjectIDIsAnError() async throws {
        let directory = try makeDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let id = ProjectID()
        let other = Project(content: .video(VideoProject(sources: [])))
        try JSONEncoder().encode(other).write(to: fileURL(for: id, in: directory))

        let store = FileDraftStore(directory: directory)
        do {
            _ = try await store.loadDraft(for: id)
            Issue.record("Expected a mismatched project ID error")
        } catch FileDraftStore.LoadError.mismatchedProjectID {
            return
        }
    }

    @Test func failedSaveReportsErrorAndLeavesExistingFile() async throws {
        let directory = try makeDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let blockedDirectory = directory.appendingPathComponent("drafts")
        let existing = Data("existing data".utf8)
        try existing.write(to: blockedDirectory)
        let store = FileDraftStore(directory: blockedDirectory)

        do {
            try await store.saveDraft(Project(content: .video(VideoProject(sources: []))))
            Issue.record("Expected a file-system error")
        } catch is CocoaError {
            let preserved = try Data(contentsOf: blockedDirectory)
            #expect(preserved == existing)
        }
    }

    private func makeDirectory() throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: false)
        return directory
    }

    private func fileURL(for id: ProjectID, in directory: URL) -> URL {
        directory.appendingPathComponent(id.rawValue.uuidString).appendingPathExtension("json")
    }
}
