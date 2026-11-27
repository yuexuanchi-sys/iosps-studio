import AVFoundation
import BirthdayCore
import Foundation
import MediaIO
import Observation
import TemplateKit
import TimelineKit
import VideoEngine

/// Manages photo selection, template switching, in-place preview, and MP4 export for memory movies.
@MainActor
@Observable
final class PhotoMovieSession {
    enum Operation: Equatable, Sendable {
        case importing, previewing, exporting
    }

    struct PhotoItem: Identifiable, Equatable, Sendable {
        let id: MediaID
        let name: String
        let sourceURL: URL
        let thumbnailURL: URL
    }

    struct ImportIssue: Identifiable {
        let id = UUID()
        let name: String
        let explanation: String
    }

    struct MusicSelection: Equatable, Sendable {
        let name: String
        let url: URL
    }

    private enum ImportRejection: Error {
        case notPhoto
        case tooLong
    }

    /// Starter built-in templates for T-0505 preview/export; T-0506 expands this catalog to 8 full templates and bundled music.
    nonisolated static let builtInTemplates: [MemoryTemplate] = {
        let definitions = [
            #"{"formatVersion":1,"id":"warm-memory","name":"暖光纪念","scenes":[{"frames":45,"transitionFrames":12,"motion":"zoomIn","caption":"拾光留念"},{"frames":45,"transitionFrames":12,"motion":"panRight"},{"frames":45,"transitionFrames":12,"motion":"zoomOut","caption":"美好定格"}]}"#,
            #"{"formatVersion":1,"id":"breezy-album","name":"轻快画卷","scenes":[{"frames":30,"transitionFrames":8,"motion":"panLeft","caption":"此刻相伴"},{"frames":30,"transitionFrames":8,"motion":"zoomIn"}]}"#,
            #"{"formatVersion":1,"id":"quiet-keepsake","name":"静谧相册","scenes":[{"frames":60,"transitionFrames":15,"motion":"still","caption":"岁岁安暖"},{"frames":60,"transitionFrames":15,"motion":"zoomOut"}]}"#,
        ]
        let decoder = JSONDecoder()
        return definitions.compactMap { try? decoder.decode(MemoryTemplate.self, from: Data($0.utf8)) }
    }()

    private let library: MediaLibrary
    private let previewDirectory: URL
    private var task: Task<Void, Never>?

    let player = AVPlayer()
    let templates: [MemoryTemplate]
    private(set) var selectedTemplateID: String
    private(set) var photos: [PhotoItem] = []
    private(set) var music: MusicSelection?
    private(set) var operation: Operation?
    private(set) var hasPreview = false
    private(set) var isPlaying = false
    private(set) var previewURL: URL?
    private(set) var progress = 0.0
    private(set) var message: String?
    private(set) var importIssues: [ImportIssue] = []
    private(set) var lastExportURL: URL?

    var selectedTemplate: MemoryTemplate? {
        templates.first { $0.id == selectedTemplateID } ?? templates.first
    }

    var estimatedDurationFrames: Int {
        guard let template = selectedTemplate else { return 0 }
        return Self.durationFrames(photoCount: photos.count, template: template)
    }

    var estimatedDurationSeconds: Double {
        Double(estimatedDurationFrames) / Double(VideoTiming.framesPerSecond)
    }

    init(
        library: MediaLibrary,
        previewDirectory: URL? = nil,
        templates: [MemoryTemplate]? = nil
    ) {
        self.library = library
        self.previewDirectory = previewDirectory ?? FileManager.default.temporaryDirectory
            .appendingPathComponent("iosps-photo-movie-\(UUID().uuidString)", isDirectory: true)
        let candidate = templates ?? Self.builtInTemplates
        let resolved = candidate.isEmpty ? Self.builtInTemplates : candidate
        self.templates = resolved
        self.selectedTemplateID = resolved.first?.id ?? ""
    }

    @discardableResult
    func importPhotos(_ urls: [URL]) -> Task<Void, Never>? {
        guard !urls.isEmpty else { return nil }
        return perform(.importing) {
            self.importIssues = []
            let results = await self.library.importFiles(urls)
            var added = 0
            for (url, result) in zip(urls, results) {
                do {
                    try Task.checkCancellation()
                    let imported = try result.get()
                    guard imported.kind == .photo else { throw ImportRejection.notPhoto }
                    if let template = self.selectedTemplate,
                       Self.durationFrames(photoCount: self.photos.count + 1, template: template) > VideoTiming.maxOutputFrames {
                        throw ImportRejection.tooLong
                    }
                    self.photos.append(PhotoItem(
                        id: imported.id,
                        name: url.lastPathComponent,
                        sourceURL: imported.sourceURL,
                        thumbnailURL: imported.thumbnailURL
                    ))
                    added += 1
                } catch is CancellationError {
                    throw CancellationError()
                } catch {
                    self.importIssues.append(ImportIssue(
                        name: url.lastPathComponent,
                        explanation: Self.explainImport(error)
                    ))
                }
            }
            if added > 0 {
                self.invalidatePreview()
            }
        }
    }

    func movePhoto(from index: Int, by offset: Int) {
        guard operation == nil else { return }
        let target = index + offset
        guard photos.indices.contains(index), photos.indices.contains(target), index != target else { return }
        photos.swapAt(index, target)
        invalidatePreview()
        message = nil
    }

    func removePhoto(at index: Int) {
        guard operation == nil, photos.indices.contains(index) else { return }
        photos.remove(at: index)
        invalidatePreview()
        message = nil
    }

    func selectTemplate(id: String) {
        guard operation == nil, id != selectedTemplateID, templates.contains(where: { $0.id == id }) else { return }
        selectedTemplateID = id
        invalidatePreview()
        message = nil
    }

    func selectMusic(_ url: URL) {
        guard operation == nil else { return }
        music = MusicSelection(name: url.lastPathComponent, url: url)
        invalidatePreview()
        message = nil
    }

    func clearMusic() {
        guard operation == nil, music != nil else { return }
        music = nil
        invalidatePreview()
        message = nil
    }

    @discardableResult
    func preview() -> Task<Void, Never>? {
        guard !photos.isEmpty, let template = selectedTemplate else { return nil }
        let inputs = photos.map { PhotoMovieInput(id: $0.id, url: $0.sourceURL) }
        let resolvedMusic = music.map { PhotoMovieMusic(url: $0.url) }
        let directory = previewDirectory
        return perform(.previewing) {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let outputURL = directory.appendingPathComponent("preview-\(UUID().uuidString).mp4")
            do {
                try await self.renderInBackground(
                    photos: inputs,
                    template: template,
                    music: resolvedMusic,
                    to: outputURL,
                    operation: .previewing
                )
            } catch {
                try? FileManager.default.removeItem(at: outputURL)
                throw error
            }
            self.replacePreviewFile(with: outputURL)
            self.player.play()
            self.isPlaying = true
            self.progress = 1.0
            self.message = String(localized: "预览已就绪。")
        }
    }

    @discardableResult
    func export(at url: URL) -> Task<Void, Never>? {
        guard !photos.isEmpty, let template = selectedTemplate else { return nil }
        let inputs = photos.map { PhotoMovieInput(id: $0.id, url: $0.sourceURL) }
        let resolvedMusic = music.map { PhotoMovieMusic(url: $0.url) }
        return perform(.exporting) {
            try await self.renderInBackground(
                photos: inputs,
                template: template,
                music: resolvedMusic,
                to: url,
                operation: .exporting
            )
            self.lastExportURL = url
            self.progress = 1.0
            self.message = String(localized: "回忆短片已导出。")
        }
    }

    func cancelCurrentOperation() {
        task?.cancel()
    }

    func pausePreview() {
        player.pause()
        isPlaying = false
    }

    func togglePlayback() {
        guard hasPreview else { return }
        if player.rate != 0 {
            pausePreview()
            return
        }
        if let item = player.currentItem {
            let duration = item.duration.seconds
            let current = player.currentTime().seconds
            if duration.isFinite, duration > 0, current >= duration - 0.05 {
                player.seek(to: .zero)
            }
        }
        player.play()
        isPlaying = true
    }

    private func perform(
        _ kind: Operation,
        work: @escaping @MainActor () async throws -> Void
    ) -> Task<Void, Never>? {
        guard task == nil else { return nil }
        operation = kind
        progress = 0
        message = nil
        let running = Task {
            defer {
                self.operation = nil
                self.task = nil
            }
            do {
                try await work()
            } catch {
                if kind == .previewing {
                    self.invalidatePreview()
                }
                self.message = Self.explainOperationFailure(error, kind: kind, cancelled: Task.isCancelled)
            }
        }
        task = running
        return running
    }

    private func renderInBackground(
        photos: [PhotoMovieInput],
        template: MemoryTemplate,
        music: PhotoMovieMusic?,
        to destination: URL,
        operation expectedOperation: Operation
    ) async throws {
        let onProgress: @Sendable (Double) -> Void = { [weak self] value in
            guard let session = self else { return }
            let clamped = min(max(value, 0), 1)
            Task { @MainActor in
                guard session.operation == expectedOperation else { return }
                session.progress = max(session.progress, clamped)
            }
        }
        let worker = Task.detached(priority: .userInitiated) {
            try await PhotoMovieRenderer.write(
                photos: photos,
                template: template,
                music: music,
                to: destination,
                progress: onProgress
            )
        }
        try await withTaskCancellationHandler {
            try await worker.value
        } onCancel: {
            worker.cancel()
        }
    }

    private func replacePreviewFile(with url: URL) {
        let previous = previewURL
        player.pause()
        player.replaceCurrentItem(with: AVPlayerItem(url: url))
        previewURL = url
        hasPreview = true
        if let previous, previous != url {
            try? FileManager.default.removeItem(at: previous)
        }
    }

    private func invalidatePreview() {
        player.pause()
        player.replaceCurrentItem(with: nil)
        hasPreview = false
        isPlaying = false
        if let existing = previewURL {
            try? FileManager.default.removeItem(at: existing)
            previewURL = nil
        }
    }

    private static func durationFrames(photoCount: Int, template: MemoryTemplate) -> Int {
        guard photoCount > 0, !template.scenes.isEmpty else { return 0 }
        var total = 0
        var overlaps = 0
        for index in 0..<photoCount {
            let scene = template.scenes[index % template.scenes.count]
            total += scene.frames
            if index + 1 < photoCount {
                overlaps += scene.transitionFrames
            }
        }
        return max(0, total - overlaps)
    }

    private static func explainImport(_ error: Error) -> String {
        switch error {
        case ImportRejection.notPhoto:
            String(localized: "仅支持照片，视频请前往剪辑。")
        case ImportRejection.tooLong:
            String(localized: "回忆短片最长 10 分钟。")
        case MediaImportError.unsupportedFormat:
            String(localized: "文件格式不受支持。请选择 JPEG、PNG 或 HEIC 照片。")
        case MediaImportError.unreadableFile:
            String(localized: "无法读取文件。请检查文件位置或读取权限后重试。")
        case MediaImportError.unreadableMedia:
            String(localized: "无法解码照片。请检查文件是否损坏或更换照片。")
        default:
            String(localized: "无法导入此照片。请检查文件后重试。")
        }
    }

    private static func explainOperationFailure(_ error: Error, kind: Operation, cancelled: Bool) -> String {
        if cancelled || error is CancellationError {
            return switch kind {
            case .exporting: String(localized: "导出已取消。已保留先前的文件。")
            case .previewing: String(localized: "已取消生成预览。")
            case .importing: String(localized: "操作已取消。")
            }
        }
        if let failure = error as? PhotoMovieRenderer.Failure {
            switch failure {
            case .unreadableAudio:
                return String(localized: "无法读取所选配乐。已保留先前的文件，请更换或移除配乐后重试。")
            case .audioExcerptOutOfRange:
                return String(localized: "配乐时长不足以匹配截取区间。已保留先前的文件，请更换配乐后重试。")
            case .unreadablePhoto:
                return String(localized: "有照片无法读取。已保留先前的文件，请移除异常照片后重试。")
            case .invalidDestination:
                return String(localized: "目标位置无法写入。已保留先前的文件，请更改保存位置或权限后重试。")
            default:
                break
            }
        }
        return switch kind {
        case .exporting: String(localized: "导出失败。已保留先前的文件，请重试。")
        case .previewing: String(localized: "无法生成预览。请检查照片和配乐后重试。")
        case .importing: String(localized: "无法导入照片。请重试。")
        }
    }
}
