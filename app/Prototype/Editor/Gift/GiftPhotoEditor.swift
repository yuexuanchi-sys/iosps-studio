import AppKit
import SwiftUI

struct GiftPhotoEditor: View {
    let workspace: ProjectWorkspace
    let navigation: GiftNavigation
    let largeText: Bool
    private var tab: ProjectTab { workspace.current }
    private var session: EditorSession { tab.session }
    private var working: Bool { workspace.isManaging || session.showsBusy || session.isImporting }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            if let document = session.document {
                HStack(spacing: 0) {
                    EditorCanvas(session: session)
                        .clipped()
                        .accessibilityLabel("照片画布")
                        .accessibilityIdentifier("gift-canvas")
                    Divider()
                    ScrollView {
                        VStack(alignment: .leading, spacing: 14) {
                            Text("修图")
                                .font(.system(size: largeText ? 27 : 20, weight: .semibold))
                                .accessibilityAddTraits(.isHeader)
                            if session.filterEdit != nil || session.hueSaturation != nil {
                                adjustment
                            } else {
                                tools
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(16)
                    }
                    .frame(width: largeText ? 284 : 246)
                    .background(.background)
                    .disabled(working)
                }
                Divider()
                footer(document)
            } else if working {
                ProgressView("正在打开照片…").frame(maxHeight: .infinity)
            } else {
                ContentUnavailableView {
                    Label("选一张照片开始", systemImage: "photo")
                } description: {
                    Text("支持 JPEG 和 PNG，也可以从回忆中打开示例照片。")
                } actions: {
                    Button("选取照片…") { Task { await navigation.choosePhoto(in: workspace) } }
                        .buttonStyle(.borderedProminent)
                }
            }
        }
        .onAppear {
            if session.tool == .move { session.selectTool(.hand) }
        }
        .alert("无法完成操作", isPresented: Binding(
            get: { session.importError != nil || session.cropError != nil || session.brushError != nil },
            set: { if !$0 { session.importError = nil; session.cropError = nil; session.brushError = nil } }
        )) {
            Button("好", role: .cancel) {}
        } message: {
            Text(session.importError != nil ? "请确认照片可读，再重新选取。" : "请重试，或撤销后再调整照片。")
        }
    }

    private var header: some View {
        HStack(spacing: 10) {
            if workspace.tabs.count > 1 {
                Picker("照片", selection: Binding(get: { workspace.selectedID }, set: { workspace.select($0) })) {
                    ForEach(workspace.tabs) { tab in
                        Text(tab.title).tag(tab.id)
                    }
                }
                .labelsHidden()
                .frame(maxWidth: 240)
                .disabled(!workspace.canSwitch)
            } else if session.document != nil {
                Text(tab.title).lineLimit(1).truncationMode(.middle).font(.headline)
            }
            Spacer(minLength: 12)
            Button("选取照片…") { Task { await navigation.choosePhoto(in: workspace) } }
                .disabled(!workspace.canSwitch || navigation.isPickingPhoto)
                .accessibilityIdentifier("gift-select")
            Button("打开工程…") { Task { await workspace.open() } }
                .disabled(!workspace.canSwitch)
                .accessibilityIdentifier("gift-open")
            Button("保存工程") { Task { await tab.controller.save() } }
                .buttonStyle(.borderedProminent)
                .disabled(session.document == nil || !workspace.canSwitch || session.cropRect != nil)
                .accessibilityIdentifier("gift-save")
            Menu("导出") {
                Button("导出 PNG…") { Task { await tab.controller.exportGiftPhoto(.png) } }
                Button("导出 JPEG…") { Task { await tab.controller.exportGiftPhoto(.jpeg) } }
                Divider()
                Button("导出回忆短片…") { Task { await navigation.exportMovie(in: workspace) } }
            }
            .disabled(session.document == nil || !workspace.canSwitch || session.cropRect != nil)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    private var tools: some View {
        Group {
            Text("裁剪").font(.system(size: largeText ? 20 : 15, weight: .semibold))
            HStack {
                Button("1:1") { session.beginGiftCrop("1:1") }
                    .accessibilityLabel("正方形裁剪")
                    .accessibilityIdentifier("gift-crop-square")
                Button("2:1") { session.beginGiftCrop("2:1") }
                    .accessibilityLabel("二比一裁剪")
                    .accessibilityIdentifier("gift-crop-wide")
            }
            if session.cropRect != nil {
                Text("拖动边框调整裁剪范围。").foregroundStyle(.secondary)
                HStack {
                    Button("取消") { session.selectTool(.hand) }
                        .keyboardShortcut(.cancelAction)
                    Button("应用裁剪") { Task { await session.finishGiftCrop() } }
                        .buttonStyle(.borderedProminent)
                        .keyboardShortcut(.defaultAction)
                        .accessibilityIdentifier("gift-apply-crop")
                }
            } else {
                Button("向右旋转 90°", systemImage: "rotate.right") {
                    session.rotateCanvas(clockwise: true)
                }
                .disabled(!session.canEditLayers)
                .accessibilityIdentifier("gift-rotate")
                Divider()
                Text("调色").font(.system(size: largeText ? 20 : 15, weight: .semibold))
                Button("曝光…") { session.beginFilter(.exposure) }
                    .disabled(!session.canAdjustColors)
                    .accessibilityIdentifier("gift-exposure")
                Button("饱和度…") { session.beginHueSaturation() }
                    .disabled(!session.canAdjustColors)
                    .accessibilityIdentifier("gift-saturation")
                Divider()
                HStack {
                    Button("撤销", systemImage: "arrow.uturn.backward") { session.undo() }
                        .disabled(!session.canUndo)
                    Button("重做", systemImage: "arrow.uturn.forward") { session.redo() }
                        .disabled(!session.canRedo)
                }
            }
        }
    }

    private var adjustment: some View {
        VStack(alignment: .leading, spacing: 14) {
            if let edit = session.filterEdit, edit.kind == .exposure {
                Slider(value: Binding(get: { edit.settings.exposure.exposure }, set: { value in
                    var settings = edit.settings
                    settings.exposure.exposure = value
                    session.updateFilter(settings, preview: true)
                }), in: -2...2, step: 0.1) {
                    Text("曝光")
                }
                .accessibilityIdentifier("gift-exposure-slider")
                Text(edit.settings.exposure.exposure.formatted(.number.precision(.fractionLength(1))))
                    .monospacedDigit()
            } else if let edit = session.hueSaturation {
                Slider(value: Binding(get: { edit.settings.saturation }, set: { value in
                    var settings = edit.settings
                    settings.saturation = value
                    session.updateHueSaturation(settings, preview: true)
                }), in: -100...100, step: 1) {
                    Text("饱和度")
                }
                .accessibilityIdentifier("gift-saturation-slider")
                Text(edit.settings.saturation.formatted(.number.precision(.fractionLength(0))))
                    .monospacedDigit()
            }
            HStack {
                Button("取消") {
                    session.cancelFilter()
                    session.cancelHueSaturation()
                }
                .keyboardShortcut(.cancelAction)
                Button("应用调色") {
                    Task { await session.applyGiftAdjustment() }
                }
                .buttonStyle(.borderedProminent)
                .accessibilityIdentifier("gift-apply-color")
            }
        }
    }

    private func footer(_ document: CanvasDocument) -> some View {
        HStack(spacing: 12) {
            Text("\(document.width) × \(document.height) 像素")
                .accessibilityIdentifier("gift-pixel-size")
            if working { ProgressView().controlSize(.small).accessibilityLabel("正在处理") }
            if let movie = navigation.lastSavedMovie {
                Button("查看短片") { NSWorkspace.shared.activateFileViewerSelecting([movie]) }
                    .help("在访达中显示已保存的 MP4")
                    .accessibilityIdentifier("gift-movie-saved")
            }
            Spacer()
            Button("缩小", systemImage: "minus.magnifyingglass") { session.zoomKeyboard(by: -1) }
                .labelStyle(.iconOnly)
            Text(Double(session.viewport.zoom).formatted(.percent.precision(.fractionLength(0))))
                .monospacedDigit()
                .accessibilityIdentifier("gift-zoom-value")
            Button("放大", systemImage: "plus.magnifyingglass") { session.zoomKeyboard(by: 1) }
                .labelStyle(.iconOnly)
            Button("适合窗口") { session.fit() }
            Button("平移", systemImage: "hand.raised") {
                session.selectTool(.hand)
                session.canvasFocusRequest += 1
            }
            .help("拖动画布，或用方向键平移")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }
}

extension EditorSession {
    func applyGiftAdjustment() async {
        if hueSaturation != nil { await commitHueSaturation() }
        else { await commitFilter() }
    }

    func beginGiftCrop(_ choice: String) {
        guard let document, let ratio = CropGeometry.ratio(choice), canStartProjectOperation else { return }
        selectTool(.crop)
        cropRatioChoice = choice
        let width = min(document.size.width, document.size.height * ratio)
        let height = width / ratio
        cropRect = CropGeometry.snapped(CGRect(x: (document.size.width - width) / 2,
                                              y: (document.size.height - height) / 2,
                                              width: width, height: height))
    }

    func finishGiftCrop() async {
        await commitCrop()
        if cropRect == nil { selectTool(.hand) }
    }
}
