import AppKit
import Foundation
import SwiftUI
import UniformTypeIdentifiers

struct PhotoEditorView: View {
    let session: PhotoEditingSession
    @State private var dropTargeted = false
    @State private var customRatioInput = "4:5"

    private let aspectGridColumns = Array(repeating: GridItem(.flexible(), spacing: 6), count: 3)
    private let orientationGridColumns = Array(repeating: GridItem(.flexible(), spacing: 6), count: 2)

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            if session.hasDocument {
                HStack(spacing: 0) {
                    PhotoCanvasView(session: session)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .accessibilityLabel("照片画布")
                        .accessibilityIdentifier("photo-editor-canvas")
                    Divider()
                    ScrollView {
                        VStack(alignment: .leading, spacing: 14) {
                            Text("修图工具")
                                .font(.headline)
                                .accessibilityAddTraits(.isHeader)
                            if session.isAdjustingColor {
                                adjustmentPanel
                            } else {
                                toolPanel
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(16)
                    }
                    .frame(width: 248)
                    .background(.background)
                    .disabled(session.isBusy)
                }
                Divider()
                footer
            } else if session.isBusy {
                ProgressView("正在打开照片…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                emptyState
            }
        }
        .frame(minWidth: 740, minHeight: 480)
        .onDisappear {
            Task { _ = await session.saveDraftNow() }
        }
    }

    private var header: some View {
        HStack(spacing: 8) {
            Text("修图")
                .font(.title2.weight(.semibold))
                .accessibilityAddTraits(.isHeader)
                .accessibilityIdentifier("photo-editor-title")
            if session.hasDocument {
                Text(verbatim: session.documentTitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .accessibilityIdentifier("photo-editor-document-title")
            }
            if session.restoredFromDraft {
                Text("已恢复草稿")
                    .font(.caption)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.accentColor.opacity(0.16), in: Capsule())
                    .accessibilityIdentifier("photo-editor-draft-badge")
            }
            Spacer(minLength: 8)
            Button("选取照片…", action: choosePhoto)
                .disabled(session.isBusy)
                .accessibilityIdentifier("photo-editor-select")
            Button("打开工程…", action: chooseProjectToOpen)
                .disabled(session.isBusy)
                .accessibilityIdentifier("photo-editor-open")
            Button("保存工程", action: saveProject)
                .buttonStyle(.borderedProminent)
                .disabled(!session.canSave)
                .accessibilityIdentifier("photo-editor-save")
            Button("另存工程…", action: saveProjectAs)
                .disabled(!session.canSave)
                .accessibilityIdentifier("photo-editor-save-as")
            Menu("导出") {
                Button("导出 PNG…") { exportPhoto(.png) }
                Button("导出 JPEG…") { exportPhoto(.jpeg) }
            }
            .disabled(!session.canSave)
            .accessibilityIdentifier("photo-editor-export")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    private var emptyState: some View {
        ZStack {
            ContentUnavailableView {
                Label("选一张照片开始修图", systemImage: "photo.badge.plus")
            } description: {
                Text("支持 JPEG、PNG 和 HEIC，也可打开已保存的照片工程继续编辑。")
            } actions: {
                HStack(spacing: 10) {
                    Button("选取照片…", action: choosePhoto)
                        .buttonStyle(.borderedProminent)
                        .accessibilityIdentifier("photo-editor-empty-select")
                    Button("打开工程…", action: chooseProjectToOpen)
                        .accessibilityIdentifier("photo-editor-empty-open")
                }
            }
            .overlay {
                if dropTargeted {
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(Color.accentColor, style: StrokeStyle(lineWidth: 2, dash: [6, 4]))
                        .padding(16)
                        .allowsHitTesting(false)
                }
            }
            .overlay {
                FinderDropTarget(acceptsDrops: !session.isBusy, isTargeted: $dropTargeted) { urls in
                    Task { _ = await session.openDroppedURLs(urls) }
                    return true
                }
                .accessibilityHidden(true)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var toolPanel: some View {
        Group {
            Text("裁剪与方向")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
            LazyVGrid(columns: aspectGridColumns, spacing: 6) {
                ForEach(PhotoCropAspect.allCases) { aspect in
                    let isSelected = session.isCropping && session.activeCropAspect == aspect
                    Button {
                        session.beginCrop(aspect)
                    } label: {
                        Text(verbatim: aspect.displayTitle)
                            .font(.caption.weight(isSelected ? .semibold : .regular))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 5)
                            .background(
                                isSelected ? Color.accentColor.opacity(0.2) : Color(nsColor: .controlBackgroundColor),
                                in: RoundedRectangle(cornerRadius: 6)
                            )
                            .overlay {
                                RoundedRectangle(cornerRadius: 6)
                                    .strokeBorder(isSelected ? Color.accentColor : Color.secondary.opacity(0.25), lineWidth: 1)
                            }
                    }
                    .buttonStyle(.plain)
                    .disabled(!session.canCrop)
                    .accessibilityLabel(Text(verbatim: aspect.accessibilityTitle))
                    .accessibilityIdentifier(aspect.accessibilityID)
                }
            }
            if session.isCropping {
                Text("裁剪区域 \(session.cropPixelWidth) × \(session.cropPixelHeight) 像素")
                    .font(.caption)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier("photo-editor-crop-size")
                HStack(spacing: 6) {
                    TextField("如 4:5", text: $customRatioInput)
                        .textFieldStyle(.roundedBorder)
                        .onSubmit { _ = session.applyCustomCropRatio(customRatioInput) }
                        .accessibilityLabel("自定义裁剪比例")
                        .accessibilityIdentifier("photo-editor-crop-custom-input")
                    Button("设为比例") {
                        _ = session.applyCustomCropRatio(customRatioInput)
                    }
                    .disabled(!session.canCrop)
                    .accessibilityIdentifier("photo-editor-crop-custom-apply")
                }
                Text("拖动裁剪框调整范围，确认后生效。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                HStack(spacing: 6) {
                    Button("重置", action: session.resetCropRect)
                        .accessibilityIdentifier("photo-editor-crop-reset")
                    Button("取消裁剪", action: session.cancelCrop)
                        .keyboardShortcut(.cancelAction)
                        .accessibilityIdentifier("photo-editor-cancel-crop")
                }
                Button("应用裁剪") { Task { await session.commitCrop() } }
                    .buttonStyle(.borderedProminent)
                    .frame(maxWidth: .infinity)
                    .accessibilityIdentifier("photo-editor-apply-crop")
            } else {
                LazyVGrid(columns: orientationGridColumns, spacing: 6) {
                    Button {
                        session.rotateCounterclockwise()
                    } label: {
                        Label("左旋 90°", systemImage: "rotate.left")
                            .frame(maxWidth: .infinity)
                    }
                    .keyboardShortcut("[", modifiers: .command)
                    .disabled(!session.canEdit)
                    .accessibilityLabel("向左旋转 90°")
                    .accessibilityIdentifier("photo-editor-rotate-left")

                    Button {
                        session.rotateClockwise()
                    } label: {
                        Label("右旋 90°", systemImage: "rotate.right")
                            .frame(maxWidth: .infinity)
                    }
                    .keyboardShortcut("]", modifiers: .command)
                    .disabled(!session.canEdit)
                    .accessibilityLabel("向右旋转 90°")
                    .accessibilityIdentifier("photo-editor-rotate")

                    Button {
                        session.flipHorizontal()
                    } label: {
                        Label("水平翻转", systemImage: "arrow.left.and.right.righttriangle.left.righttriangle.right")
                            .frame(maxWidth: .infinity)
                    }
                    .disabled(!session.canEdit)
                    .accessibilityIdentifier("photo-editor-flip-h")

                    Button {
                        session.flipVertical()
                    } label: {
                        Label("垂直翻转", systemImage: "arrow.up.and.down.righttriangle.up.righttriangle.down")
                            .frame(maxWidth: .infinity)
                    }
                    .disabled(!session.canEdit)
                    .accessibilityIdentifier("photo-editor-flip-v")
                }
                Divider()
                Text("基础调色")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                Button("曝光…", action: session.beginExposureAdjustment)
                    .disabled(!session.canAdjustColors)
                    .accessibilityIdentifier("photo-editor-exposure")
                Button("饱和度…", action: session.beginSaturationAdjustment)
                    .disabled(!session.canAdjustColors)
                    .accessibilityIdentifier("photo-editor-saturation")
                Divider()
                Text("编辑历史")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                HStack(spacing: 8) {
                    Button("撤销", systemImage: "arrow.uturn.backward", action: session.undo)
                        .disabled(!session.canUndo)
                        .accessibilityIdentifier("photo-editor-undo")
                    Button("重做", systemImage: "arrow.uturn.forward", action: session.redo)
                        .disabled(!session.canRedo)
                        .accessibilityIdentifier("photo-editor-redo")
                }
                Text("可撤销 \(session.undoCount) 步 · 可重做 \(session.redoCount) 步")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
                    .accessibilityIdentifier("photo-editor-history-count")
            }
        }
    }

    private var adjustmentPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            if session.isAdjustingExposure {
                Slider(
                    value: Binding(get: { session.exposureValue }, set: { session.updateExposure($0) }),
                    in: -2...2,
                    step: 0.1
                ) {
                    Text("曝光")
                }
                .accessibilityIdentifier("photo-editor-exposure-slider")
                Text("曝光 \(session.exposureValue.formatted(.number.precision(.fractionLength(1))))")
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            } else if session.isAdjustingSaturation {
                Slider(
                    value: Binding(get: { session.saturationValue }, set: { session.updateSaturation($0) }),
                    in: -100...100,
                    step: 1
                ) {
                    Text("饱和度")
                }
                .accessibilityIdentifier("photo-editor-saturation-slider")
                Text("饱和度 \(session.saturationValue.formatted(.number.precision(.fractionLength(0))))")
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
            HStack(spacing: 8) {
                Button("取消", action: session.cancelActiveAdjustment)
                    .accessibilityIdentifier("photo-editor-cancel-adjustment")
                Button("应用调色") { Task { await session.commitActiveAdjustment() } }
                    .buttonStyle(.borderedProminent)
                    .accessibilityIdentifier("photo-editor-apply-adjustment")
            }
        }
    }

    private var footer: some View {
        HStack(spacing: 10) {
            Text("\(session.pixelWidth) × \(session.pixelHeight) 像素")
                .monospacedDigit()
                .accessibilityIdentifier("photo-editor-pixel-size")
            if session.isBusy {
                ProgressView()
                    .controlSize(.small)
                    .accessibilityLabel("正在处理")
            }
            if let error = session.errorMessage {
                Text(verbatim: error)
                    .foregroundStyle(.red)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .accessibilityIdentifier("photo-editor-error")
            } else if let status = session.statusMessage {
                Text(verbatim: status)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .accessibilityIdentifier("photo-editor-status")
            }
            Spacer(minLength: 8)
            Button("缩小", systemImage: "minus.magnifyingglass", action: session.zoomOut)
                .labelStyle(.iconOnly)
                .accessibilityIdentifier("photo-editor-zoom-out")
            Text("\(session.zoomPercentage)%")
                .monospacedDigit()
                .accessibilityIdentifier("photo-editor-zoom-value")
            Button("放大", systemImage: "plus.magnifyingglass", action: session.zoomIn)
                .labelStyle(.iconOnly)
                .accessibilityIdentifier("photo-editor-zoom-in")
            Button("适合窗口", action: session.fitToWindow)
                .accessibilityIdentifier("photo-editor-fit")
            Button("平移", systemImage: "hand.raised", action: session.selectHandTool)
                .accessibilityIdentifier("photo-editor-hand")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }

    // MARK: - Native File Panels

    private func choosePhoto() {
        let panel = NSOpenPanel()
        panel.title = String(localized: "选取照片")
        panel.prompt = String(localized: "打开")
        panel.allowedContentTypes = PhotoEditingSession.supportedImageContentTypes
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        Task {
            guard let url = await presentSaveOrOpenPanel(panel) else { return }
            _ = await session.importPhoto(from: url)
        }
    }

    private func chooseProjectToOpen() {
        let panel = NSOpenPanel()
        panel.title = String(localized: "打开照片工程")
        panel.prompt = String(localized: "打开")
        panel.allowedContentTypes = [PhotoEditingSession.projectContentType]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.treatsFilePackagesAsDirectories = false
        Task {
            guard let url = await presentSaveOrOpenPanel(panel) else { return }
            _ = await session.openProject(at: url)
        }
    }

    private func saveProject() {
        if session.currentProjectReference != nil {
            Task { _ = await session.saveProject(asNew: false) }
            return
        }
        presentSaveProjectPanel(asNew: false)
    }

    private func saveProjectAs() {
        presentSaveProjectPanel(asNew: true)
    }

    private func presentSaveProjectPanel(asNew: Bool) {
        let panel = NSSavePanel()
        panel.title = asNew ? String(localized: "另存照片工程") : String(localized: "保存照片工程")
        panel.prompt = String(localized: "保存")
        panel.allowedContentTypes = [PhotoEditingSession.projectContentType]
        panel.canCreateDirectories = true
        panel.isExtensionHidden = false
        panel.nameFieldStringValue = session.suggestedProjectFilename
        if let directory = session.suggestedProjectDirectory {
            panel.directoryURL = directory
        }
        Task {
            guard let url = await presentSaveOrOpenPanel(panel) else { return }
            _ = await session.saveProject(to: url, asNew: asNew)
        }
    }

    private func exportPhoto(_ format: PhotoExportFormat) {
        let panel = NSSavePanel()
        panel.title = format == .png ? String(localized: "导出 PNG 照片") : String(localized: "导出 JPEG 照片")
        panel.prompt = String(localized: "保存")
        panel.allowedContentTypes = [format.contentType]
        panel.canCreateDirectories = true
        panel.isExtensionHidden = false
        panel.nameFieldStringValue = session.suggestedExportFilename(for: format)
        if let directory = session.suggestedProjectDirectory {
            panel.directoryURL = directory
        }
        Task {
            guard let url = await presentSaveOrOpenPanel(panel) else { return }
            _ = await session.exportImage(format: format, to: url)
        }
    }

    private func presentSaveOrOpenPanel(_ panel: NSSavePanel) async -> URL? {
        let response: NSApplication.ModalResponse
        if let window = NSApp.keyWindow ?? NSApp.mainWindow {
            response = await panel.beginSheetModal(for: window)
        } else {
            response = await panel.begin()
        }
        return response == .OK ? panel.url : nil
    }
}
