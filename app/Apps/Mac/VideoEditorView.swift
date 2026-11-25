import AppKit
import AVKit
import SwiftUI
import TimelineKit
import UniformTypeIdentifiers

struct VideoEditorView: View {
    private enum Picker: Equatable { case videos, project }
    private enum Replacement: Equatable { case new, open }
    private enum SaveTarget: Equatable { case project, movie }

    let session: VideoEditingSession
    @State private var picker = Picker.videos
    @State private var showsPicker = false
    @State private var replacement = Replacement.open
    @State private var confirmsReplacement = false
    @State private var selection = 0
    @State private var trimStart = "0"
    @State private var trimEnd = ""
    @State private var splitAt = ""
    @State private var pickerMessage: String?

    private var hasClips: Bool { !session.timeline.clips.isEmpty }
    private var busy: Bool { session.operation != nil }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header
            HStack(alignment: .top, spacing: 14) {
                preview
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                clipControls
                    .frame(minWidth: 248, idealWidth: 290, maxWidth: 320)
                    .disabled(busy)
            }
            feedback
        }
        .padding(16)
        .frame(minWidth: 620, minHeight: 390)
        .onAppear(perform: resetFields)
        .onChange(of: session.timeline) { resetFields() }
        .onDisappear(perform: session.pausePreview)
        .fileImporter(
            isPresented: $showsPicker,
            allowedContentTypes: picker == .videos ? [.quickTimeMovie, .mpeg4Movie] : [.json],
            allowsMultipleSelection: picker == .videos,
            onCompletion: acceptSelection
        )
        .confirmationDialog("切换工程？", isPresented: $confirmsReplacement, titleVisibility: .visible) {
            Button("放弃此工程未保存的修改", role: .destructive) { replaceProject() }
            Button("取消", role: .cancel) {}
        } message: {
            Text("先保存可保留目前的剪辑。")
        }
    }

    private var header: some View {
        HStack(spacing: 8) {
            Text("剪辑")
                .font(.title2.weight(.semibold))
                .accessibilityAddTraits(.isHeader)
                .accessibilityIdentifier("video-editor-title")
            Spacer()
            Button("导入视频…") { presentPicker(.videos) }
                .accessibilityIdentifier("video-import")
            Button("新工程") { request(.new) }
                .accessibilityIdentifier("video-new")
            Button("打开工程…") { request(.open) }
                .accessibilityIdentifier("video-open")
            Button("保存工程…") { chooseDestination(.project) }
                .accessibilityIdentifier("video-save")
            Button("导出 MP4…") { chooseDestination(.movie) }
                .buttonStyle(.borderedProminent)
                .disabled(!hasClips)
                .accessibilityIdentifier("video-export")
        }
        .disabled(busy)
    }

    private var preview: some View {
        VStack(spacing: 8) {
            ZStack {
                RoundedRectangle(cornerRadius: 10).fill(Color(nsColor: .controlBackgroundColor))
                if session.hasPreview {
                    VideoPlayer(player: session.player)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .accessibilityIdentifier("video-player")
                } else {
                    VStack(spacing: 8) {
                        Image(systemName: "film")
                            .font(.title)
                            .accessibilityHidden(true)
                        Text(hasClips ? "预览当前顺序与裁切" : "导入 MOV 或 MP4 开始剪辑")
                    }
                    .foregroundStyle(.secondary)
                }
            }
            .frame(minHeight: 160)
            HStack {
                Button("播放预览", action: { session.preview() })
                    .disabled(!hasClips || busy)
                    .accessibilityIdentifier("video-preview")
                Spacer()
                Text("时长 \(Double(session.timeline.durationFrames) / 30, format: .number.precision(.fractionLength(2))) 秒")
                    .monospacedDigit()
                    .accessibilityIdentifier("video-duration")
            }
        }
    }

    private var clipControls: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack {
                Text("片段").font(.headline)
                Spacer()
                Button("撤销", action: session.undo)
                    .disabled(!session.canUndo)
                    .accessibilityIdentifier("video-undo")
                Button("重做", action: session.redo)
                    .disabled(!session.canRedo)
                    .accessibilityIdentifier("video-redo")
            }
            clipList
            if hasClips {
                rangeControls
                HStack {
                    Button("上移") { move(by: -1) }
                        .disabled(selection == 0)
                        .accessibilityIdentifier("video-move-up")
                    Button("下移") { move(by: 1) }
                        .disabled(selection >= session.timeline.clips.count - 1)
                        .accessibilityIdentifier("video-move-down")
                    Spacer()
                    Button("移除", role: .destructive) { session.apply(.delete(clip: selection)) }
                        .accessibilityIdentifier("video-remove")
                }
            }
        }
    }

    private var clipList: some View {
        ScrollView {
            VStack(spacing: 4) {
                ForEach(session.timeline.clips.indices, id: \.self) { index in
                    let clip = session.timeline.clips[index]
                    Button {
                        selection = index
                        resetFields()
                    } label: {
                        HStack {
                            Image(systemName: index == selection ? "checkmark.circle.fill" : "circle")
                                .accessibilityHidden(true)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(verbatim: session.label(for: index)).lineLimit(1)
                                Text("\(clip.startFrame)–\(clip.startFrame + clip.frameCount) 帧")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer(minLength: 0)
                        }
                        .padding(6)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(index == selection ? Color.accentColor.opacity(0.16) : .clear,
                                    in: RoundedRectangle(cornerRadius: 6))
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("video-clip-\(index)")
                }
            }
        }
        .frame(minHeight: 92, maxHeight: .infinity)
        .accessibilityLabel("片段顺序")
    }

    private var rangeControls: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text("相对所选片段的帧数 · 30 fps")
                .font(.caption)
                .foregroundStyle(.secondary)
            HStack {
                TextField("入点", text: $trimStart)
                    .accessibilityIdentifier("video-trim-start")
                TextField("出点", text: $trimEnd)
                    .accessibilityIdentifier("video-trim-end")
                Button("裁切") {
                    if let start = Int(trimStart), let end = Int(trimEnd) {
                        session.apply(.trim(clip: selection, from: start, to: end))
                    }
                }
                .disabled(Int(trimStart) == nil || Int(trimEnd) == nil)
                .accessibilityIdentifier("video-trim")
            }
            HStack {
                TextField("分割点", text: $splitAt)
                    .accessibilityIdentifier("video-split-point")
                Button("分割") {
                    if let offset = Int(splitAt) { session.apply(.split(clip: selection, at: offset)) }
                }
                .disabled(Int(splitAt) == nil)
                .accessibilityIdentifier("video-split")
            }
        }
    }

    @ViewBuilder
    private var feedback: some View {
        if session.operation == .exporting {
            HStack {
                ProgressView("正在导出 MP4…", value: session.progress)
                Button("取消导出", action: session.cancelExport)
                    .keyboardShortcut(.cancelAction)
                    .accessibilityIdentifier("video-cancel-export")
            }
        } else if busy {
            ProgressView("正在处理…").controlSize(.small)
        }
        if let message = pickerMessage ?? session.message {
            Text(verbatim: message)
                .accessibilityIdentifier("video-status")
        }
        if !session.importIssues.isEmpty {
            ScrollView {
                VStack(alignment: .leading, spacing: 3) {
                    ForEach(session.importIssues) { issue in
                        Text(verbatim: "\(issue.name) · \(issue.explanation)")
                    }
                }
            }
            .frame(maxHeight: 58)
            .accessibilityIdentifier("video-import-issues")
        }
    }

    private func move(by offset: Int) {
        let target = selection + offset
        guard session.timeline.clips.indices.contains(target) else { return }
        session.apply(.move(from: selection, to: target))
        selection = target
        resetFields()
    }

    private func resetFields() {
        selection = min(selection, max(0, session.timeline.clips.count - 1))
        let count = session.timeline.clips.indices.contains(selection) ? session.timeline.clips[selection].frameCount : 0
        trimStart = "0"
        trimEnd = count > 0 ? String(count) : ""
        splitAt = count > 1 ? String(count / 2) : ""
    }

    private func request(_ action: Replacement) {
        replacement = action
        if session.hasUnsavedEdits { confirmsReplacement = true } else { replaceProject() }
    }

    private func replaceProject() {
        if replacement == .open { presentPicker(.project) } else { session.newProject() }
    }

    private func presentPicker(_ kind: Picker) {
        picker = kind
        pickerMessage = nil
        showsPicker = true
    }

    private func acceptSelection(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            if picker == .videos {
                session.importVideos(urls)
            } else if let url = urls.first {
                session.open(at: url)
            }
        case .failure:
            pickerMessage = String(localized: "无法打开选取结果。请重试。")
        }
    }

    private func chooseDestination(_ purpose: SaveTarget) {
        guard let window = NSApp.keyWindow else { return }
        pickerMessage = nil
        let panel = NSSavePanel()
        panel.allowedContentTypes = purpose == .project ? [.json] : [.mpeg4Movie]
        panel.nameFieldStringValue = purpose == .project ? "剪辑.iosps.json" : "剪辑.mp4"
        panel.beginSheetModal(for: window) { response in
            guard response == .OK, let destination = panel.url else { return }
            if purpose == .project { session.save(at: destination) } else { session.export(at: destination) }
        }
    }
}
