import AppKit
import SwiftUI

@main
struct CompositorApp: App {
    @NSApplicationDelegateAdaptor(CompositorApplicationDelegate.self) private var delegate

    var body: some Scene {
        Window("拾光簿", id: "editor") {
            giftWindow
        }
        .defaultSize(width: 1120, height: 740)
        .handlesExternalEvents(matching: [])
        .commands {
            GiftCommands(workspace: delegate.workspace, navigation: delegate.giftNavigation)
        }
    }

    @ViewBuilder
    private var giftWindow: some View {
        #if DEBUG
        let arguments = ProcessInfo.processInfo.arguments
        let variant = arguments.firstIndex(of: "--gift-ui-appearance").flatMap {
            arguments.dropFirst($0 + 1).first
        }
        if let variant {
            if variant == "large" {
                workspaceView
                    .preferredColorScheme(.light)
                    .dynamicTypeSize(.accessibility1)
            } else {
                workspaceView.preferredColorScheme(variant == "dark" ? .dark : .light)
            }
        } else {
            workspaceView
        }
        #else
        workspaceView
        #endif
    }

    private var workspaceView: some View {
        GiftWorkspace(workspace: delegate.workspace, navigation: delegate.giftNavigation)
            .modifier(GiftWindowCommands(delegate: delegate))
    }
}

private struct GiftWindowCommands: ViewModifier {
    let delegate: CompositorApplicationDelegate
    @Environment(\.openWindow) private var openWindow

    func body(content: Content) -> some View {
        content.onAppear {
            delegate.showEditor = { openWindow(id: "editor") }
        }
    }
}

private struct GiftCommands: Commands {
    let workspace: ProjectWorkspace
    let navigation: GiftNavigation
    private var session: EditorSession { workspace.current.session }
    private var controller: ProjectController { workspace.current.controller }
    private var canWrite: Bool { session.document != nil && workspace.canSwitch && session.cropRect == nil }
    private var editorVisible: Bool { navigation.page == .editor }

    var body: some Commands {
        CommandGroup(replacing: .newItem) {
            Button("选取照片…") {
                Task { await navigation.choosePhoto(in: workspace) }
            }
            .keyboardShortcut("i", modifiers: [.command, .shift])
            .disabled(!workspace.canSwitch || navigation.isPickingPhoto)
            Button("打开工程…") {
                navigation.page = .editor
                Task { await workspace.open() }
            }
            .keyboardShortcut("o")
            .disabled(!workspace.canSwitch)
            Menu("最近打开的工程") {
                ForEach(RecentProjects.shared.urls, id: \.self) { url in
                    Button(url.deletingPathExtension().lastPathComponent) {
                        navigation.page = .editor
                        Task { await workspace.open(url) }
                    }
                }
                if RecentProjects.shared.urls.isEmpty {
                    Text("暂无最近工程")
                }
            }
            .disabled(!workspace.canSwitch)
        }
        CommandGroup(replacing: .saveItem) {
            Button("保存工程") { Task { await controller.save() } }
                .keyboardShortcut("s")
                .disabled(!editorVisible || !canWrite)
            Button("另存工程…") { Task { await controller.save(asNew: true) } }
                .keyboardShortcut("s", modifiers: [.command, .shift])
                .disabled(!editorVisible || !canWrite)
            Divider()
            Button("导出 PNG…") { Task { await controller.exportGiftPhoto(.png) } }
                .keyboardShortcut("e")
                .disabled(!editorVisible || !canWrite)
            Button("导出 JPEG…") { Task { await controller.exportGiftPhoto(.jpeg) } }
                .keyboardShortcut("e", modifiers: [.command, .shift])
                .disabled(!editorVisible || !canWrite)
        }
        CommandGroup(replacing: .undoRedo) {
            Button("撤销") {
                if NSApp.isEditingText { NSApp.sendAction(NSSelectorFromString("undo:"), to: nil, from: nil) }
                else { session.undo() }
            }
            .keyboardShortcut("z")
            .disabled(!editorVisible || !session.canUndo)
            Button("重做") {
                if NSApp.isEditingText { NSApp.sendAction(NSSelectorFromString("redo:"), to: nil, from: nil) }
                else { session.redo() }
            }
            .keyboardShortcut("z", modifiers: [.command, .shift])
            .disabled(!editorVisible || !session.canRedo)
        }
        CommandMenu("前往") {
            Button("生日") { navigation.page = .birthday }.keyboardShortcut("1")
            Button("回忆") { navigation.page = .memories }.keyboardShortcut("2")
            Button("修图") { navigation.page = .editor }.keyboardShortcut("3")
        }
        CommandMenu("照片") {
            Button("二比一裁剪") { session.beginGiftCrop("2:1") }
                .keyboardShortcut("k")
                .disabled(!editorVisible || !canWrite)
            Button("向右旋转 90°") { session.rotateCanvas(clockwise: true) }
                .keyboardShortcut("r")
                .disabled(!editorVisible || !session.canEditLayers)
            Button("曝光…") { session.beginFilter(.exposure) }
                .keyboardShortcut("l", modifiers: [.command, .shift])
                .disabled(!editorVisible || !canWrite || !session.canAdjustColors)
            Button("饱和度…") { session.beginHueSaturation() }
                .keyboardShortcut("u")
                .disabled(!editorVisible || !canWrite || !session.canAdjustColors)
            Divider()
            Button("适合窗口") { session.fit() }.keyboardShortcut("0")
                .disabled(!editorVisible || session.document == nil)
            Button("放大") { session.zoomKeyboard(by: 1) }.keyboardShortcut("=")
                .disabled(!editorVisible || session.document == nil)
            Button("缩小") { session.zoomKeyboard(by: -1) }.keyboardShortcut("-")
                .disabled(!editorVisible || session.document == nil)
            Button("平移") {
                session.selectTool(.hand)
                session.canvasFocusRequest += 1
            }
            .keyboardShortcut("h", modifiers: [.command, .shift])
            .disabled(!editorVisible || !canWrite)
        }
    }
}

extension NSApplication {
    /// Keep system panels and text fields on the native editing responder chain.
    var isEditingText: Bool { keyWindow?.firstResponder is NSTextView || keyWindow is NSSavePanel }
}
