import AVFoundation
import BirthdayCore
import Foundation
import MediaIO
import Observation
import TimelineKit
import VideoEngine

@MainActor
@Observable
final class VideoEditingSession {
    enum Operation: Equatable { case importing, previewing, saving, opening, exporting }

    struct ImportIssue: Identifiable {
        let id = UUID()
        let name: String
        let explanation: String
    }

    private enum Issue: Error {
        case unavailableOriginal, malformedProject, tooLong
    }

    private let library: MediaLibrary
    private let drafts: FileDraftStore
    private var history = UndoStack(initialState: Timeline())
    private var sources: [MediaID: VideoSource] = [:]
    private var names: [MediaID: String] = [:]
    private var projectID = ProjectID()
    private var lastSaved = Timeline()
    private var task: Task<Void, Never>?
    private var activeMontage: VideoMontage?

    let player = AVPlayer()
    private(set) var operation: Operation?
    private(set) var hasPreview = false
    private(set) var progress = 0.0
    private(set) var message: String?
    private(set) var importIssues: [ImportIssue] = []

    var timeline: Timeline { history.state }
    var canUndo: Bool { history.canUndo }
    var canRedo: Bool { history.canRedo }
    var hasUnsavedEdits: Bool { timeline != lastSaved }

    init(library: MediaLibrary, drafts: FileDraftStore) {
        self.library = library
        self.drafts = drafts
    }

    func label(for index: Int) -> String {
        names[timeline.clips[index].media] ?? String(localized: "第 \(index + 1) 段")
    }

    @discardableResult
    func importVideos(_ urls: [URL]) -> Task<Void, Never>? {
        guard !urls.isEmpty else { return nil }
        return perform(.importing, failure: String(localized: "无法导入视频。请重试。")) {
            self.importIssues = []
            let results = await self.library.importFiles(urls)
            var clips = self.timeline.clips
            var totalFrames = self.timeline.durationFrames
            for (url, result) in zip(urls, results) {
                do {
                    try Task.checkCancellation()
                    let imported = try result.get()
                    guard imported.kind == .video else { throw Issue.unavailableOriginal }
                    let source = try await VideoSource.load(id: imported.id, from: imported.sourceURL)
                    guard source.frameCount <= VideoTiming.maxOutputFrames - totalFrames else { throw Issue.tooLong }
                    clips.append(try TimelineClip(media: imported.id, startFrame: 0, frameCount: source.frameCount))
                    self.sources[imported.id] = source
                    self.names[imported.id] = url.lastPathComponent
                    totalFrames += source.frameCount
                } catch is CancellationError {
                    throw CancellationError()
                } catch {
                    self.importIssues.append(ImportIssue(name: url.lastPathComponent, explanation: Self.explainImport(error)))
                }
            }
            if clips.count > self.timeline.clips.count {
                let after = try Self.hardCuts(clips)
                try self.history.perform(AppendVideos(previous: self.timeline, result: after))
                self.invalidatePreview()
            }
        }
    }

    func apply(_ edit: TimelineEdit) {
        changeHistory {
            let command = try TimelineEditCommand(edit, on: timeline)
            try history.perform(command)
        }
    }

    func undo() { changeHistory { _ = try history.undo() } }
    func redo() { changeHistory { _ = try history.redo() } }

    @discardableResult
    func preview() -> Task<Void, Never>? {
        perform(.previewing, failure: String(localized: "无法预览。请检查素材是否仍可读取。")) {
            let montage = try VideoMontage(timeline: self.timeline, sources: self.sources)
            self.player.replaceCurrentItem(with: montage.makePlayerItem())
            self.hasPreview = true
            self.player.play()
        }
    }

    @discardableResult
    func save(at url: URL) -> Task<Void, Never>? {
        perform(.saving, failure: String(localized: "无法保存工程。原文件仍保留，请换个位置重试。")) {
            let clips = self.timeline.clips
            let document = VideoProject(
                sources: clips.map(\.media),
                frameRanges: clips.map { .init(start: $0.startFrame, count: $0.frameCount) },
                sourceNames: clips.indices.map { self.label(for: $0) }
            )
            try await self.drafts.saveProject(Project(id: self.projectID, content: .video(document)), at: url)
            self.lastSaved = self.timeline
            self.message = String(localized: "工程已保存。")
        }
    }

    @discardableResult
    func open(at url: URL) -> Task<Void, Never>? {
        perform(.opening, failure: String(localized: "无法打开工程。请检查工程和本机素材，当前剪辑仍保留。")) {
            let project = try await self.drafts.openProject(at: url)
            guard case .video(let video) = project.content,
                  video.frameRanges.map({ $0.count == video.sources.count }) ?? true else {
                throw Issue.malformedProject
            }
            var recovered: [MediaID: VideoSource] = [:]
            var labels: [MediaID: String] = [:]
            var clips: [TimelineClip] = []
            for (index, id) in video.sources.enumerated() {
                if recovered[id] == nil {
                    guard let media = try await self.library.load(id: id), media.kind == .video else {
                        throw Issue.unavailableOriginal
                    }
                    recovered[id] = try await VideoSource.load(id: id, from: media.sourceURL)
                }
                guard let source = recovered[id] else { throw Issue.unavailableOriginal }
                let range = video.frameRanges?[index] ?? .init(start: 0, count: source.frameCount)
                let clip = try TimelineClip(media: id, startFrame: range.start, frameCount: range.count)
                guard clip.startFrame + clip.frameCount <= source.frameCount else { throw Issue.malformedProject }
                clips.append(clip)
                if let stored = video.sourceNames, stored.indices.contains(index) { labels[id] = stored[index] }
            }
            let recoveredTimeline = try Self.hardCuts(clips)
            self.projectID = project.id
            self.history = UndoStack(initialState: recoveredTimeline)
            self.lastSaved = recoveredTimeline
            self.sources = recovered
            self.names = labels
            self.importIssues = []
            self.invalidatePreview()
            self.message = String(localized: "工程已打开。")
        }
    }

    func newProject() {
        guard operation == nil else { return }
        projectID = ProjectID()
        history = UndoStack(initialState: Timeline())
        lastSaved = timeline
        sources.removeAll()
        names.removeAll()
        importIssues.removeAll()
        message = nil
        invalidatePreview()
    }

    @discardableResult
    func export(at url: URL) -> Task<Void, Never>? {
        perform(.exporting, failure: String(localized: "导出失败。已保留先前的文件，请重试。")) {
            let montage = try VideoMontage(timeline: self.timeline, sources: self.sources)
            self.activeMontage = montage
            defer { self.activeMontage = nil }
            try await montage.export(to: url) { self.progress = $0 }
            self.message = String(localized: "MP4 已导出。")
        }
    }

    func cancelExport() {
        guard operation == .exporting else { return }
        task?.cancel()
        activeMontage?.cancelExport()
    }

    func pausePreview() { player.pause() }

    private func perform(
        _ kind: Operation, failure: String, work: @escaping @MainActor () async throws -> Void
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
                self.message = Task.isCancelled ? String(localized: "操作已取消。") : failure
            }
        }
        task = running
        return running
    }

    private func changeHistory(_ change: () throws -> Void) {
        guard operation == nil else { return }
        do {
            try change()
            invalidatePreview()
            message = nil
        } catch {
            message = String(localized: "剪辑范围无效。请检查起止帧后重试。")
        }
    }

    private func invalidatePreview() {
        player.pause()
        player.replaceCurrentItem(with: nil)
        hasPreview = false
    }

    private static func hardCuts(_ clips: [TimelineClip]) throws -> Timeline {
        try Timeline(clips: clips, overlaps: Array(repeating: 0, count: max(0, clips.count - 1)))
    }

    private static func explainImport(_ error: Error) -> String {
        switch error {
        case Issue.tooLong: String(localized: "剪辑总时长最多 10 分钟。")
        case VideoMontageError.variableFrameRate: String(localized: "此文件使用可变帧率。请先转换成固定帧率视频再试。")
        default: String(localized: "无法读取此视频。请检查文件后重试。")
        }
    }
}

private struct AppendVideos: EditCommand {
    let previous: Timeline
    let result: Timeline

    func apply(to state: inout Timeline) throws {
        guard state == previous else { throw TimelineEditCommand.ValidationError.staleTimeline }
        state = result
    }

    func revert(on state: inout Timeline) throws {
        guard state == result else { throw TimelineEditCommand.ValidationError.staleTimeline }
        state = previous
    }
}
