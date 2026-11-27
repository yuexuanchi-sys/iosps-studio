import AppKit
import AVKit
import SwiftUI
import TemplateKit
import UniformTypeIdentifiers

struct PhotoMovieView: View {
    private enum PickerKind: Equatable {
        case photos, music
    }

    let session: PhotoMovieSession
    @State private var pickerKind = PickerKind.photos
    @State private var showsPicker = false
    @State private var selection = 0
    @State private var dropTargeted = false
    @State private var pickerMessage: String?

    private var hasPhotos: Bool { !session.photos.isEmpty }
    private var busy: Bool { session.operation != nil }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header
            HStack(alignment: .top, spacing: 14) {
                previewAndTemplates
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                photoRail
                    .frame(minWidth: 224, idealWidth: 248, maxWidth: 276)
                    .disabled(busy)
            }
            feedback
        }
        .padding(.horizontal, 18)
        .padding(.top, 14)
        .padding(.bottom, 16)
        .frame(minWidth: 740, minHeight: 480)
        .onChange(of: session.photos.count) { clampSelection() }
        .onDisappear(perform: session.pausePreview)
        .fileImporter(
            isPresented: $showsPicker,
            allowedContentTypes: pickerKind == .photos ? [.jpeg, .png, .heic] : [.audio],
            allowsMultipleSelection: pickerKind == .photos,
            onCompletion: acceptSelection
        )
    }

    private var header: some View {
        HStack(spacing: 8) {
            Text("回忆短片")
                .font(.title2.weight(.semibold))
                .accessibilityAddTraits(.isHeader)
                .accessibilityIdentifier("photo-movie-title")
            Spacer()
            Button("添加照片…") { presentPicker(.photos) }
                .accessibilityIdentifier("photo-movie-add-photos")
            Button("自定义配乐…") { presentPicker(.music) }
                .accessibilityIdentifier("photo-movie-select-music")
            Button("导出 MP4…", action: chooseExportDestination)
                .buttonStyle(.borderedProminent)
                .disabled(!hasPhotos)
                .accessibilityIdentifier("photo-movie-export")
        }
        .disabled(busy)
    }

    private var previewAndTemplates: some View {
        VStack(alignment: .leading, spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(dropTargeted ? Color.accentColor.opacity(0.14) : Color(nsColor: .controlBackgroundColor))
                if session.hasPreview {
                    PhotoMoviePlayerView(player: session.player)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                } else {
                    VStack(spacing: 8) {
                        Image(systemName: "film.stack")
                            .font(.title)
                            .accessibilityHidden(true)
                        Text(hasPhotos ? "点击「生成并播放预览」查看短片效果" : "添加或拖入照片，一键生成回忆短片")
                            .multilineTextAlignment(.center)
                    }
                    .foregroundStyle(.secondary)
                    .padding(12)
                }
            }
            .overlay {
                if !session.hasPreview {
                    FinderDropTarget(acceptsDrops: !busy && !showsPicker, isTargeted: $dropTargeted) { files in
                        guard session.importPhotos(files) != nil else { return false }
                        pickerMessage = nil
                        return true
                    }
                    .accessibilityHidden(true)
                }
            }
            .frame(minHeight: 156, maxHeight: .infinity)

            HStack(spacing: 8) {
                Button("生成并播放预览") { session.preview() }
                    .disabled(!hasPhotos || busy)
                    .accessibilityIdentifier("photo-movie-preview")
                if session.hasPreview {
                    Button(session.isPlaying ? "暂停" : "继续播放", action: session.togglePlayback)
                        .disabled(busy)
                        .accessibilityIdentifier("photo-movie-play-pause")
                }
                Spacer()
                Text("预计时长 \(session.estimatedDurationSeconds, format: .number.precision(.fractionLength(2))) 秒")
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier("photo-movie-duration")
            }

            templateStrip
                .disabled(busy)

            HStack(spacing: 8) {
                Text("片头祝福")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                TextField(
                    "选填，留空使用模板默认文案",
                    text: Binding(
                        get: { session.customOpeningCaption },
                        set: { session.setOpeningCaption($0) }
                    )
                )
                .textFieldStyle(.roundedBorder)
                .disabled(busy)
                .accessibilityIdentifier("photo-movie-opening-caption")
            }

            musicBar
        }
    }

    private var templateStrip: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("短片模板")
                    .font(.headline)
                Spacer()
                Text("共 \(session.catalog.count) 套内置模板")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            ScrollView(.horizontal, showsIndicators: true) {
                HStack(spacing: 8) {
                    ForEach(session.catalog.indices, id: \.self) { index in
                        let descriptor = session.catalog[index]
                        let template = descriptor.template
                        let selected = template.id == session.selectedTemplateID
                        Button {
                            session.selectTemplate(id: template.id)
                        } label: {
                            VStack(alignment: .leading, spacing: 3) {
                                HStack(spacing: 4) {
                                    Text(verbatim: template.name)
                                        .font(.subheadline.weight(.medium))
                                        .lineLimit(1)
                                    if descriptor.isRecommended {
                                        Text("推荐")
                                            .font(.caption2)
                                            .padding(.horizontal, 4)
                                            .padding(.vertical, 1)
                                            .background(Color.accentColor.opacity(0.2), in: Capsule())
                                    }
                                    Spacer(minLength: 0)
                                    if selected {
                                        Image(systemName: "checkmark.circle.fill")
                                            .font(.caption)
                                            .foregroundStyle(Color.accentColor)
                                            .accessibilityHidden(true)
                                    }
                                }
                                Text(verbatim: descriptor.subtitle)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 8)
                            .frame(width: 136, alignment: .leading)
                            .background(
                                selected ? Color.accentColor.opacity(0.16) : Color(nsColor: .controlBackgroundColor),
                                in: RoundedRectangle(cornerRadius: 8)
                            )
                            .overlay {
                                RoundedRectangle(cornerRadius: 8)
                                    .strokeBorder(selected ? Color.accentColor : Color.secondary.opacity(0.25), lineWidth: 1)
                            }
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("photo-movie-template-\(template.id)")
                    }
                }
                .padding(.vertical, 2)
            }
        }
    }

    private var musicBar: some View {
        HStack(spacing: 8) {
            Image(systemName: session.musicMode == .muted ? "speaker.slash" : "music.note")
                .accessibilityHidden(true)
            Text(verbatim: session.activeMusicDisplayName)
                .lineLimit(1)
                .truncationMode(.middle)
                .accessibilityIdentifier("photo-movie-music-name")
            Spacer()
            if session.musicMode != .templateDefault {
                Button("恢复模板配乐", action: session.useTemplateMusic)
                    .buttonStyle(.borderless)
                    .disabled(busy)
                    .accessibilityIdentifier("photo-movie-use-template-music")
            }
            if session.musicMode != .muted {
                Button("静音", action: session.muteMusic)
                    .buttonStyle(.borderless)
                    .disabled(busy)
                    .accessibilityIdentifier("photo-movie-mute-music")
            }
        }
        .font(.subheadline)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 8))
    }

    private var photoRail: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("已选照片")
                    .font(.headline)
                Spacer()
                Text("\(session.photos.count) 张")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            ScrollView {
                VStack(spacing: 4) {
                    if session.photos.isEmpty {
                        Text("还没有照片，点上方「添加照片…」选择多张照片。")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(8)
                    } else {
                        ForEach(session.photos.indices, id: \.self) { index in
                            let item = session.photos[index]
                            Button {
                                selection = index
                            } label: {
                                HStack(spacing: 8) {
                                    photoThumbnail(for: item)
                                        .frame(width: 44, height: 32)
                                        .clipShape(RoundedRectangle(cornerRadius: 4))
                                        .accessibilityHidden(true)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(verbatim: item.name)
                                            .lineLimit(1)
                                            .truncationMode(.middle)
                                        Text("第 \(index + 1) 张")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    Spacer(minLength: 0)
                                }
                                .padding(6)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(
                                    index == selection ? Color.accentColor.opacity(0.16) : .clear,
                                    in: RoundedRectangle(cornerRadius: 6)
                                )
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .accessibilityIdentifier("photo-movie-photo-\(index)")
                        }
                    }
                }
            }
            .frame(minHeight: 110, maxHeight: .infinity)
            .accessibilityLabel("照片顺序")

            if hasPhotos {
                HStack(spacing: 8) {
                    Button("上移") { move(by: -1) }
                        .disabled(selection <= 0)
                        .accessibilityIdentifier("photo-movie-move-up")
                    Button("下移") { move(by: 1) }
                        .disabled(selection >= session.photos.count - 1)
                        .accessibilityIdentifier("photo-movie-move-down")
                    Spacer()
                    Button("移除", role: .destructive) {
                        session.removePhoto(at: selection)
                        clampSelection()
                    }
                    .accessibilityIdentifier("photo-movie-remove")
                }
            }
        }
    }

    @ViewBuilder
    private func photoThumbnail(for item: PhotoMovieSession.PhotoItem) -> some View {
        if let image = NSImage(contentsOf: item.thumbnailURL) {
            Image(nsImage: image)
                .resizable()
                .scaledToFill()
        } else {
            Image(systemName: "photo")
        }
    }

    @ViewBuilder
    private var feedback: some View {
        if session.operation == .exporting {
            HStack(spacing: 10) {
                ProgressView("正在导出回忆短片…", value: session.progress, total: 1.0)
                Text("\(Int((session.progress * 100).rounded()))%")
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                Button("取消导出", action: session.cancelCurrentOperation)
                    .keyboardShortcut(.cancelAction)
                    .accessibilityIdentifier("photo-movie-cancel-export")
            }
        } else if session.operation == .previewing {
            HStack(spacing: 10) {
                ProgressView("正在生成预览…", value: session.progress, total: 1.0)
                Button("取消", action: session.cancelCurrentOperation)
                    .keyboardShortcut(.cancelAction)
                    .accessibilityIdentifier("photo-movie-cancel-preview")
            }
        } else if session.operation == .importing {
            ProgressView("正在导入照片…")
                .controlSize(.small)
        }

        if let message = pickerMessage ?? session.message {
            Text(verbatim: message)
                .accessibilityIdentifier("photo-movie-status")
        }

        if !session.importIssues.isEmpty {
            ScrollView {
                VStack(alignment: .leading, spacing: 3) {
                    ForEach(session.importIssues) { issue in
                        Text(verbatim: "\(issue.name) · \(issue.explanation)")
                    }
                }
            }
            .frame(maxHeight: 52)
            .accessibilityIdentifier("photo-movie-import-issues")
        }
    }

    private func move(by offset: Int) {
        let target = selection + offset
        guard session.photos.indices.contains(target) else { return }
        session.movePhoto(from: selection, by: offset)
        selection = target
    }

    private func clampSelection() {
        selection = min(selection, max(0, session.photos.count - 1))
    }

    private func presentPicker(_ kind: PickerKind) {
        pickerKind = kind
        pickerMessage = nil
        showsPicker = true
    }

    private func acceptSelection(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            if pickerKind == .photos {
                session.importPhotos(urls)
            } else if let url = urls.first {
                session.selectMusic(url)
            }
        case .failure:
            pickerMessage = String(localized: "无法打开选取结果。请重试。")
        }
    }

    private func chooseExportDestination() {
        guard let window = NSApp.keyWindow else { return }
        pickerMessage = nil
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.mpeg4Movie]
        panel.nameFieldStringValue = "回忆短片.mp4"
        panel.beginSheetModal(for: window) { response in
            guard response == .OK, let destination = panel.url else { return }
            session.export(at: destination)
        }
    }
}

private struct PhotoMoviePlayerView: NSViewRepresentable {
    let player: AVPlayer

    func makeNSView(context: Context) -> AVPlayerView {
        // Use AppKit AVPlayerView directly; SwiftUI VideoPlayer aborts on the macOS 26.7 runner.
        let view = AVPlayerView()
        view.controlsStyle = .inline
        view.setAccessibilityIdentifier("photo-movie-player")
        return view
    }

    func updateNSView(_ view: AVPlayerView, context: Context) {
        if view.player !== player {
            view.player = player
        }
    }
}
