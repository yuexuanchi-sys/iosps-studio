import BirthdayCore
import Foundation
import MediaIO
import Observation

/// Manages the local timeline of substantively saved photo projects, retry queue, and detail selection.
@MainActor
@Observable
final class PhotoMemorySession {
    struct DaySection: Identifiable, Equatable {
        let id: String
        let title: String
        let items: [ResolvedPhotoMemory]
    }

    private let store: PhotoMemoryStore
    private var publicationTail: Task<Void, Never>?
    private var inFlightCount = 0

    private(set) var timeline = PhotoMemoryTimeline()
    private(set) var items: [ResolvedPhotoMemory] = []
    private(set) var daySections: [DaySection] = []
    private(set) var pendingPublications: [PhotoMemoryPublication] = []
    private(set) var isBusy = false
    private(set) var errorMessage: String?
    private(set) var statusMessage: String?

    var selectedMemoryID: ProjectID?
    private(set) var lastOpenedMemoryID: ProjectID?

    var hasPendingRetries: Bool { !pendingPublications.isEmpty }
    var hasInFlightPublication: Bool { inFlightCount > 0 }

    var selectedMemory: ResolvedPhotoMemory? {
        guard let selectedMemoryID else { return nil }
        return items.first { $0.id == selectedMemoryID }
    }

    init(store: PhotoMemoryStore) {
        self.store = store
    }

    /// Loads the persisted timeline index from disk and resolves each entry's local file & preview health.
    func reload() async {
        isBusy = true
        defer { isBusy = false }
        await waitForInFlightPublications()
        do {
            let loaded = try await store.loadTimeline()
            let resolved = await store.resolve(loaded)
            apply(timeline: loaded, resolved: resolved)
            if !hasPendingRetries {
                errorMessage = nil
            }
        } catch {
            errorMessage = String(localized: "无法读取回忆时间线索引。请检查本机应用数据目录后重试。")
        }
    }

    /// Serializes substantive photo save callbacks from `PhotoEditingSession` so rapid saves stay ordered.
    @discardableResult
    func handleProjectSaved(_ event: PhotoProjectSavedEvent) -> Task<Void, Never> {
        let publication = PhotoMemoryPublication(
            projectID: event.reference.projectID,
            title: event.title,
            projectURL: event.reference.fileURL,
            savedAt: event.savedAt,
            pixelWidth: event.pixelWidth,
            pixelHeight: event.pixelHeight,
            previewPNGData: event.previewPNGData
        )
        inFlightCount += 1
        let previous = publicationTail
        let task = Task { @MainActor [weak self] in
            await previous?.value
            guard let self else { return }
            defer { self.inFlightCount = max(0, self.inFlightCount - 1) }
            _ = await self.publishNow(publication)
        }
        publicationTail = task
        return task
    }

    /// Waits for all enqueued publication tasks to finish (used before graceful app quit and in tests).
    func waitForInFlightPublications() async {
        await publicationTail?.value
    }

    /// Publishes one saved photo work immediately; on failure keeps earlier items and enqueues idempotent retry.
    @discardableResult
    func publishNow(_ publication: PhotoMemoryPublication) async -> Bool {
        do {
            let updated = try await store.publish(publication)
            let resolved = await store.resolve(updated)
            pendingPublications.removeAll { $0.projectID == publication.projectID }
            apply(timeline: updated, resolved: resolved)
            if pendingPublications.isEmpty {
                errorMessage = nil
            }
            statusMessage = String(localized: "已更新到回忆时间线。")
            return true
        } catch {
            enqueueRetry(publication)
            errorMessage = String(localized: "无法更新回忆索引。原有作品列表已保留，请检查存储权限后重试。")
            return false
        }
    }

    /// Retries any failed timeline index publications idempotently without producing duplicate entries.
    @discardableResult
    func retryPendingPublications() async -> Bool {
        guard !pendingPublications.isEmpty else { return true }
        let queue = pendingPublications
        var allSucceeded = true
        for publication in queue {
            let ok = await publishNow(publication)
            if !ok {
                allSucceeded = false
            }
        }
        return allSucceeded
    }

    func openDetail(id: ProjectID) {
        guard items.contains(where: { $0.id == id }) else { return }
        selectedMemoryID = id
        lastOpenedMemoryID = id
    }

    func closeDetail() {
        if let current = selectedMemoryID {
            lastOpenedMemoryID = current
        }
        selectedMemoryID = nil
    }

    func canSelectAdjacentDetail(offset: Int) -> Bool {
        guard let selectedMemoryID,
              let index = items.firstIndex(where: { $0.id == selectedMemoryID }) else {
            return false
        }
        return items.indices.contains(index + offset)
    }

    func selectAdjacentDetail(offset: Int) {
        guard let selectedMemoryID,
              let index = items.firstIndex(where: { $0.id == selectedMemoryID }) else {
            return
        }
        let target = index + offset
        guard items.indices.contains(target) else { return }
        let nextID = items[target].id
        self.selectedMemoryID = nextID
        self.lastOpenedMemoryID = nextID
    }

    private func enqueueRetry(_ publication: PhotoMemoryPublication) {
        pendingPublications.removeAll { $0.projectID == publication.projectID }
        pendingPublications.append(publication)
    }

    private func apply(timeline: PhotoMemoryTimeline, resolved: [ResolvedPhotoMemory]) {
        self.timeline = timeline
        self.items = resolved
        let resolvedByID = Dictionary(uniqueKeysWithValues: resolved.map { ($0.id, $0) })
        let groups = timeline.groupedByDay()
        self.daySections = groups.map { group in
            let title = "\(group.year) 年 \(group.month) 月 \(group.day) 日"
            let sectionItems = group.entries.compactMap { resolvedByID[$0.id] }
            return DaySection(id: group.id, title: title, items: sectionItems)
        }
        if let current = selectedMemoryID, !resolved.contains(where: { $0.id == current }) {
            selectedMemoryID = nil
        }
    }
}
