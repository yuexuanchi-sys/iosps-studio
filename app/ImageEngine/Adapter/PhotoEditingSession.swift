import AppKit
import BirthdayCore
import CoreGraphics
import Foundation
import Observation
import UniformTypeIdentifiers

/// Main-actor adapter owning Compositor's photo editor session, auto-draft recovery, and substantive-save callbacks.
@MainActor
@Observable
final class PhotoEditingSession {
    /// Opaque project package content type exposed to the UI file panels without leaking upstream `.comp` types.
    static var projectContentType: UTType { .compositorProject }

    /// Supported source image types for photo editing entry points.
    static var supportedImageContentTypes: [UTType] { [.jpeg, .png, .heic] }

    let editor = EditorSession()
    private let draftStore: PhotoDraftRecoveryStore
    private let clock: @MainActor () -> Date

    /// Invoked strictly when a photo project with substantive edits is successfully saved (consumed by T-0302).
    var onSubstantiveProjectSaved: (@MainActor (PhotoProjectSavedEvent) -> Void)?

    private var initialSourceFingerprint: PhotoContentFingerprint?
    private var lastSavedFingerprint: PhotoContentFingerprint?
    private var hasSavedSubstantiveEdit = false
    private var draftTask: Task<Void, Never>?
    private var lastDraftRevision: UUID?
    private var attemptedInitialRestore = false

    private(set) var currentProjectReference: PhotoProjectReference?
    private(set) var documentTitle: String = String(localized: "未命名照片")
    private(set) var isBusy = false
    private(set) var statusMessage: String?
    private(set) var errorMessage: String?
    private(set) var restoredFromDraft = false
    private(set) var savedEvents: [PhotoProjectSavedEvent] = []
    private(set) var lastExportURL: URL?

    var hasDocument: Bool { editor.document != nil }
    var pixelWidth: Int { editor.document?.width ?? 0 }
    var pixelHeight: Int { editor.document?.height ?? 0 }
    var zoomPercentage: Int { Int((Double(editor.viewport.zoom) * 100).rounded()) }
    var canUndo: Bool { !isBusy && editor.canUndo }
    var canRedo: Bool { !isBusy && editor.canRedo }
    var undoCount: Int { editor.history.undoCount }
    var redoCount: Int { editor.history.redoCount }
    var isCropping: Bool { editor.cropRect != nil }
    var isAdjustingExposure: Bool { editor.filterEdit?.kind == .exposure }
    var isAdjustingSaturation: Bool { editor.hueSaturation != nil }
    var isAdjustingColor: Bool { isAdjustingExposure || isAdjustingSaturation }
    var canEdit: Bool { !isBusy && editor.document != nil && editor.canEditLayers }
    var canAdjustColors: Bool { !isBusy && editor.document != nil && editor.canStartProjectOperation && editor.canAdjustColors && editor.cropRect == nil }
    var canSave: Bool { !isBusy && editor.document != nil && editor.canStartProjectOperation && editor.cropRect == nil && !isAdjustingColor }
    var needsDraftFlush: Bool { editor.document != nil && (draftTask != nil || lastDraftRevision != editor.history.currentRevision) }

    var exposureValue: Double {
        editor.filterEdit?.settings.exposure.exposure ?? 0
    }

    var saturationValue: Double {
        editor.hueSaturation?.settings.saturation ?? 0
    }

    var suggestedProjectFilename: String {
        if let existing = currentProjectReference?.fileURL.lastPathComponent {
            return existing
        }
        let base = editor.sourceImageURL?.deletingPathExtension().lastPathComponent ?? documentTitle
        return "\(base).comp"
    }

    var suggestedProjectDirectory: URL? {
        currentProjectReference?.fileURL.deletingLastPathComponent()
            ?? editor.sourceImageURL?.deletingLastPathComponent()
    }

    func suggestedExportFilename(for format: PhotoExportFormat) -> String {
        let base = currentProjectReference?.fileURL.deletingPathExtension().lastPathComponent
            ?? editor.sourceImageURL?.deletingPathExtension().lastPathComponent
            ?? documentTitle
        return "\(base)-edited.\(format.fileExtension)"
    }

    init(draftStore: PhotoDraftRecoveryStore, clock: @escaping @MainActor () -> Date = { Date() }) {
        self.draftStore = draftStore
        self.clock = clock
        editor.skipsInitialClipboardCanvasSize = true
    }

    /// Imports a local photo file read-only as a fresh editing document without emitting a memory save callback.
    @discardableResult
    func importPhoto(from url: URL) async -> Bool {
        guard !isBusy else { return false }
        isBusy = true
        defer { isBusy = false }
        errorMessage = nil
        statusMessage = nil

        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        do {
            guard url.isFileURL else { throw ImageImportError.unsupported }
            let asset = try await ImageImporter.shared.decode(url)
            editor.cancelFilter()
            editor.cancelHueSaturation()
            editor.clearProject()
            editor.insert(asset)
            editor.sourceImageURL = url
            editor.history.reset()
            editor.selectTool(.hand)

            documentTitle = url.deletingPathExtension().lastPathComponent
            currentProjectReference = nil
            restoredFromDraft = false
            hasSavedSubstantiveEdit = false
            lastSavedFingerprint = nil
            initialSourceFingerprint = editor.projectSnapshot().map(PhotoContentFingerprint.compute(for:))
            lastDraftRevision = nil
            statusMessage = String(localized: "已打开照片。")
            scheduleDraftSave()
            return true
        } catch {
            errorMessage = String(localized: "无法打开所选照片。请确认文件未损坏且可读后重试。")
            return false
        }
    }

    /// Handles dropped Finder files: opens a saved project package or imports the first supported photo.
    @discardableResult
    func openDroppedURLs(_ urls: [URL]) async -> Bool {
        guard let first = urls.first else { return false }
        if first.pathExtension.lowercased() == "comp" {
            return await openProject(at: first)
        }
        return await importPhoto(from: first)
    }

    // MARK: - Editing Operations

    func beginCrop(aspectChoice: String) {
        guard canSave, let document = editor.document else { return }
        errorMessage = nil
        editor.selectTool(.crop)
        editor.cropRatioChoice = aspectChoice
        if let ratio = CropGeometry.ratio(aspectChoice) {
            let width = min(document.size.width, document.size.height * ratio)
            let height = width / ratio
            editor.cropRect = CropGeometry.snapped(CGRect(
                x: (document.size.width - width) / 2,
                y: (document.size.height - height) / 2,
                width: width,
                height: height
            ))
        } else {
            editor.cropRect = CGRect(origin: .zero, size: document.size)
        }
    }

    func commitCrop() async {
        guard !isBusy, editor.cropRect != nil else { return }
        errorMessage = nil
        await editor.commitCrop()
        if let cropError = editor.cropError {
            errorMessage = cropError
            editor.cropError = nil
            return
        }
        if editor.cropRect == nil {
            editor.selectTool(.hand)
            restoredFromDraft = false
            statusMessage = String(localized: "已应用裁剪。")
            scheduleDraftSave()
        }
    }

    func cancelCrop() {
        editor.cancelCrop()
        editor.selectTool(.hand)
    }

    func rotateClockwise() {
        guard canEdit else { return }
        errorMessage = nil
        editor.rotateCanvas(clockwise: true)
        restoredFromDraft = false
        statusMessage = nil
        scheduleDraftSave()
    }

    func rotateCounterclockwise() {
        guard canEdit else { return }
        errorMessage = nil
        editor.rotateCanvas(clockwise: false)
        restoredFromDraft = false
        statusMessage = nil
        scheduleDraftSave()
    }

    func flipHorizontal() {
        guard canEdit else { return }
        errorMessage = nil
        editor.flipCanvas(horizontally: true)
        restoredFromDraft = false
        statusMessage = nil
        scheduleDraftSave()
    }

    func flipVertical() {
        guard canEdit else { return }
        errorMessage = nil
        editor.flipCanvas(horizontally: false)
        restoredFromDraft = false
        statusMessage = nil
        scheduleDraftSave()
    }

    func beginExposureAdjustment() {
        guard canAdjustColors else { return }
        errorMessage = nil
        editor.beginFilter(.exposure)
    }

    func updateExposure(_ value: Double) {
        guard let edit = editor.filterEdit, edit.kind == .exposure else { return }
        var settings = edit.settings
        settings.exposure.exposure = min(2, max(-2, value))
        editor.updateFilter(settings, preview: true)
    }

    func beginSaturationAdjustment() {
        guard canAdjustColors else { return }
        errorMessage = nil
        editor.beginHueSaturation()
    }

    func updateSaturation(_ value: Double) {
        guard let edit = editor.hueSaturation else { return }
        var settings = edit.settings
        settings.saturation = min(100, max(-100, value))
        editor.updateHueSaturation(settings, preview: true)
    }

    func commitActiveAdjustment() async {
        guard !isBusy else { return }
        errorMessage = nil
        if editor.hueSaturation != nil {
            await editor.commitHueSaturation()
        } else if editor.filterEdit != nil {
            await editor.commitFilter()
        } else {
            return
        }
        if let brushError = editor.brushError {
            errorMessage = brushError
            editor.brushError = nil
            return
        }
        restoredFromDraft = false
        statusMessage = String(localized: "已应用调色。")
        scheduleDraftSave()
    }

    func cancelActiveAdjustment() {
        editor.cancelFilter()
        editor.cancelHueSaturation()
    }

    func undo() {
        guard canUndo else { return }
        errorMessage = nil
        editor.undo()
        restoredFromDraft = false
        statusMessage = nil
        scheduleDraftSave()
    }

    func redo() {
        guard canRedo else { return }
        errorMessage = nil
        editor.redo()
        restoredFromDraft = false
        statusMessage = nil
        scheduleDraftSave()
    }

    func zoomIn() {
        editor.zoomKeyboard(by: 1)
    }

    func zoomOut() {
        editor.zoomKeyboard(by: -1)
    }

    func fitToWindow() {
        editor.fit()
    }

    func selectHandTool() {
        editor.selectTool(.hand)
        editor.canvasFocusRequest += 1
    }

    // MARK: - Project Save / Reopen & Standalone Export

    /// Atomically saves the photo project. Notifies `onSubstantiveProjectSaved` only on substantive changes.
    @discardableResult
    func saveProject(to destination: URL? = nil, asNew: Bool = false) async -> Bool {
        guard canSave, let snapshot = editor.projectSnapshot() else { return false }
        guard let targetURL = destination ?? (asNew ? nil : currentProjectReference?.fileURL) else {
            return false
        }
        isBusy = true
        defer { isBusy = false }
        errorMessage = nil

        let revision = editor.history.currentRevision
        let currentFingerprint = PhotoContentFingerprint.compute(for: snapshot)
        let savedID: ProjectID
        let targetSnapshot: ProjectSnapshot
        if asNew {
            let newUUID = UUID()
            savedID = ProjectID(rawValue: newUUID)
            let manifest = snapshot.manifest
            let rewrittenManifest = ProjectManifest(
                format: manifest.format,
                version: manifest.version,
                colorSpace: manifest.colorSpace,
                resolution: manifest.resolution,
                documentID: newUUID,
                width: manifest.width,
                height: manifest.height,
                activeLayerID: manifest.activeLayerID,
                layers: manifest.layers,
                guides: manifest.guides
            )
            targetSnapshot = ProjectSnapshot(
                manifest: rewrittenManifest,
                images: snapshot.images,
                masks: snapshot.masks,
                animations: snapshot.animations
            )
        } else {
            savedID = ProjectID(rawValue: snapshot.manifest.documentID)
            targetSnapshot = snapshot
        }

        let shouldNotify: Bool
        if asNew {
            shouldNotify = (currentFingerprint != initialSourceFingerprint) || hasSavedSubstantiveEdit
        } else if let lastSaved = lastSavedFingerprint {
            shouldNotify = currentFingerprint != lastSaved
        } else {
            shouldNotify = currentFingerprint != initialSourceFingerprint
        }

        let scoped = targetURL.startAccessingSecurityScopedResource()
        defer { if scoped { targetURL.stopAccessingSecurityScopedResource() } }
        do {
            let quickLook = await ImageExporter.shared.quickLookImages(targetSnapshot)
            try await ProjectStore.shared.save(targetSnapshot, to: targetURL, quickLook: quickLook)
        } catch {
            errorMessage = String(localized: "无法保存工程。原有工程未受影响，请检查保存位置权限后重试。")
            return false
        }

        if asNew {
            editor.adoptDocumentID(savedID.rawValue)
        }
        editor.projectURL = targetURL
        editor.history.markSaved(revision)

        let reference = PhotoProjectReference(projectID: savedID, fileURL: targetURL)
        currentProjectReference = reference
        documentTitle = targetURL.deletingPathExtension().lastPathComponent
        lastSavedFingerprint = currentFingerprint
        restoredFromDraft = false

        if shouldNotify {
            hasSavedSubstantiveEdit = true
            let previewData = (try? await ImageExporter.shared.pngData(targetSnapshot)) ?? Data()
            let event = PhotoProjectSavedEvent(
                reference: reference,
                title: documentTitle,
                savedAt: clock(),
                pixelWidth: targetSnapshot.manifest.width,
                pixelHeight: targetSnapshot.manifest.height,
                previewPNGData: previewData,
                isSavedAsNew: asNew
            )
            savedEvents.append(event)
            onSubstantiveProjectSaved?(event)
        }

        statusMessage = asNew ? String(localized: "工程已另存。") : String(localized: "工程已保存。")
        _ = await saveDraftNow()
        return true
    }

    /// Reopens a saved photo project package without triggering a memory registration notification.
    @discardableResult
    func openProject(at url: URL) async -> Bool {
        guard !isBusy else { return false }
        isBusy = true
        defer { isBusy = false }
        errorMessage = nil

        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        do {
            let snapshot = try await ProjectStore.shared.load(from: url)
            editor.cancelFilter()
            editor.cancelHueSaturation()
            editor.installProject(snapshot, from: url)
            editor.selectTool(.hand)

            let fingerprint = PhotoContentFingerprint.compute(for: snapshot)
            initialSourceFingerprint = fingerprint
            lastSavedFingerprint = fingerprint
            hasSavedSubstantiveEdit = false
            currentProjectReference = PhotoProjectReference(
                projectID: ProjectID(rawValue: snapshot.manifest.documentID),
                fileURL: url
            )
            documentTitle = url.deletingPathExtension().lastPathComponent
            restoredFromDraft = false
            lastDraftRevision = nil
            statusMessage = String(localized: "工程已打开。")
            _ = await saveDraftNow()
            return true
        } catch {
            errorMessage = String(localized: "无法打开照片工程。请确认工程完整可读，当前编辑内容未受影响。")
            return false
        }
    }

    /// Reopens a project previously reported via `PhotoProjectReference`.
    @discardableResult
    func openProject(reference: PhotoProjectReference) async -> Bool {
        await openProject(at: reference.fileURL)
    }

    /// Exports the flattened photo without overwriting the source original and without notifying memories.
    @discardableResult
    func exportImage(format: PhotoExportFormat, to destination: URL) async -> Bool {
        guard canSave, let snapshot = editor.projectSnapshot() else { return false }
        if let source = editor.sourceImageURL,
           destination.resolvingSymlinksInPath().standardizedFileURL == source.resolvingSymlinksInPath().standardizedFileURL {
            errorMessage = String(localized: "请为导出照片另选文件名，原图保持只读。")
            return false
        }
        isBusy = true
        defer { isBusy = false }
        errorMessage = nil

        let scoped = destination.startAccessingSecurityScopedResource()
        defer { if scoped { destination.stopAccessingSecurityScopedResource() } }
        do {
            switch format {
            case .png:
                try await ImageExporter.shared.exportPNG(snapshot, to: destination)
            case .jpeg:
                let raster = try await ImageExporter.shared.render(snapshot)
                let encoded = try await ImageExporter.shared.jpeg(raster, options: JPEGOptions())
                try await ImageExporter.shared.write(encoded.data, to: destination)
            }
            lastExportURL = destination
            statusMessage = format == .png ? String(localized: "PNG 照片已导出。") : String(localized: "JPEG 照片已导出。")
            return true
        } catch {
            errorMessage = String(localized: "无法导出照片。请检查保存位置权限后重试。")
            return false
        }
    }

    // MARK: - Auto-Draft Persistence & Recovery

    /// Writes the current document to the internal auto-draft store without triggering memory registration.
    @discardableResult
    func saveDraftNow() async -> Bool {
        draftTask?.cancel()
        draftTask = nil
        guard let snapshot = editor.projectSnapshot() else { return false }
        let revision = editor.history.currentRevision
        let metadata = PhotoDraftMetadata(
            schemaVersion: PhotoDraftMetadata.currentSchemaVersion,
            projectID: ProjectID(rawValue: snapshot.manifest.documentID),
            projectURLPath: currentProjectReference?.fileURL.path,
            sourceImageURLPath: editor.sourceImageURL?.path,
            displayName: documentTitle,
            initialFingerprintHex: initialSourceFingerprint?.hex,
            lastSavedFingerprintHex: lastSavedFingerprint?.hex,
            hasSavedSubstantiveEdit: hasSavedSubstantiveEdit,
            updatedAt: clock()
        )
        do {
            try await draftStore.save(snapshot: snapshot, metadata: metadata)
            lastDraftRevision = revision
            return true
        } catch {
            return false
        }
    }

    /// Flushes any pending auto-draft before app termination.
    func flushDraftBeforeQuit() async {
        guard needsDraftFlush else { return }
        _ = await saveDraftNow()
    }

    /// Restores the latest valid auto-saved draft once after launch without notifying memories.
    @discardableResult
    func restoreLatestValidDraftIfNeeded() async -> Bool {
        guard !attemptedInitialRestore else { return false }
        attemptedInitialRestore = true
        guard !hasDocument else { return false }
        return await restoreLatestValidDraft()
    }

    /// Restores the latest valid auto-saved draft from disk without notifying memories.
    @discardableResult
    func restoreLatestValidDraft() async -> Bool {
        guard !isBusy else { return false }
        isBusy = true
        defer { isBusy = false }
        guard let draft = await draftStore.loadLatestValid() else { return false }
        let linkedURL = draft.metadata.projectURLPath.map { URL(fileURLWithPath: $0, isDirectory: true) }
        editor.cancelFilter()
        editor.cancelHueSaturation()
        if let linkedURL {
            editor.installProject(draft.snapshot, from: linkedURL)
            currentProjectReference = PhotoProjectReference(projectID: draft.metadata.projectID, fileURL: linkedURL)
        } else {
            editor.clearProject()
            let manifest = draft.snapshot.manifest
            editor.document = CanvasDocument(
                id: manifest.documentID,
                width: manifest.width,
                height: manifest.height,
                layers: draft.snapshot.documentLayers,
                resolution: manifest.resolution ?? 72,
                guides: manifest.guides ?? []
            )
            editor.activeLayerID = manifest.activeLayerID
            editor.history.reset()
            if let document = editor.document {
                editor.viewport.fit(documentSize: document.size)
            }
            currentProjectReference = nil
        }
        editor.sourceImageURL = draft.metadata.sourceImageURLPath.map { URL(fileURLWithPath: $0) }
        editor.selectTool(.hand)

        documentTitle = draft.metadata.displayName
        initialSourceFingerprint = draft.metadata.initialFingerprintHex.map(PhotoContentFingerprint.init(hex:))
        lastSavedFingerprint = draft.metadata.lastSavedFingerprintHex.map(PhotoContentFingerprint.init(hex:))
        hasSavedSubstantiveEdit = draft.metadata.hasSavedSubstantiveEdit
        lastDraftRevision = editor.history.currentRevision
        restoredFromDraft = true
        statusMessage = String(localized: "已恢复上次有效草稿。")
        return true
    }

    private func scheduleDraftSave() {
        draftTask?.cancel()
        draftTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .milliseconds(250))
            guard let self, !Task.isCancelled else { return }
            _ = await self.saveDraftNow()
        }
    }
}
