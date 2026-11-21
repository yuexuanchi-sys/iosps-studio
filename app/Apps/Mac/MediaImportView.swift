import AppKit
import MediaIO
import SwiftUI
import UniformTypeIdentifiers

struct MediaImportView: View {
    let session: MediaImportSession
    @State private var showsPicker = false
    @State private var pickerFailed = false
    @State private var dropTargeted = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("导入素材")
                    .font(.title2.weight(.semibold))
                    .accessibilityAddTraits(.isHeader)
                Spacer()
                Button("从 Finder 选择…") { showsPicker = true }
                    .keyboardShortcut("i", modifiers: [.command, .shift])
                    .disabled(session.isImporting)
                    .accessibilityIdentifier("media-finder-picker")
            }
            dropArea
            if pickerFailed {
                Label("无法打开所选文件。请检查读取权限后重试。", systemImage: "exclamationmark.circle")
            }
            if session.isImporting {
                HStack {
                    ProgressView("正在导入素材…")
                        .controlSize(.small)
                    Spacer()
                    Button("取消导入", action: session.cancel)
                        .keyboardShortcut(.cancelAction)
                }
            }
            if session.rows.isEmpty {
                Spacer(minLength: 0)
            } else {
                List(session.rows) { row in
                    MediaImportRow(row: row)
                }
                .listStyle(.inset)
                .accessibilityLabel("导入结果")
            }
        }
        .padding(20)
        .frame(minWidth: 360, minHeight: 240)
        .fileImporter(
            isPresented: $showsPicker,
            allowedContentTypes: [.jpeg, .png, .heic, .quickTimeMovie, .mpeg4Movie],
            allowsMultipleSelection: true
        ) { result in
            switch result {
            case .success(let urls):
                if session.importFiles(urls) != nil { pickerFailed = false }
            case .failure:
                pickerFailed = true
            }
        }
    }

    private var dropArea: some View {
        VStack(spacing: 4) {
            Label("将 Finder 中的照片或视频拖到这里", systemImage: "tray.and.arrow.down")
            Text("JPEG、PNG、HEIC、MOV、MP4")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .multilineTextAlignment(.center)
        .padding(12)
        .frame(maxWidth: .infinity)
        .background(dropTargeted ? Color.accentColor.opacity(0.15) : Color(nsColor: .controlBackgroundColor))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(dropTargeted ? Color.accentColor : Color.secondary,
                              style: StrokeStyle(lineWidth: 1, dash: [5, 4]))
                .allowsHitTesting(false)
        }
        .overlay {
            FinderDropTarget(acceptsDrops: !session.isImporting && !showsPicker, isTargeted: $dropTargeted) { files in
                guard session.importFiles(files) != nil else { return false }
                pickerFailed = false
                return true
            }
            .accessibilityHidden(true)
        }
    }
}

private struct MediaImportRow: View {
    let row: MediaImportSession.Row

    var body: some View {
        HStack(spacing: 12) {
            thumbnail
                .frame(width: 64, height: 48)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 4) {
                Text(verbatim: row.filename)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .help(Text(verbatim: row.filename))
                switch row.result {
                case .success(let media):
                    if media.kind == .photo {
                        Text("照片已导入")
                    } else {
                        Text("视频已导入")
                    }
                case .failure(let error):
                    Text(message(for: error))
                }
            }
        }
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private var thumbnail: some View {
        switch row.result {
        case .success(let media):
            if let image = NSImage(contentsOf: media.thumbnailURL) {
                Image(nsImage: image).resizable().scaledToFit()
            } else {
                Image(systemName: media.kind == .photo ? "photo" : "film")
            }
        case .failure:
            Image(systemName: "exclamationmark.circle")
        }
    }

    private func message(for error: MediaImportError) -> LocalizedStringKey {
        switch error {
        case .unsupportedFormat: "文件格式不受支持。请选择支持的照片或视频。"
        case .unreadableFile: "无法读取文件。请检查文件位置或读取权限后重试。"
        case .unreadableMedia: "无法解码媒体。请检查文件是否损坏或更换文件。"
        case .thumbnailFailed: "无法生成缩略图。请重试或更换文件。"
        case .storageFailed: "无法保存到本机。请检查可用空间及应用数据目录权限后重试。"
        case .cancelled: "已取消导入。可以重新选择此文件。"
        }
    }
}
