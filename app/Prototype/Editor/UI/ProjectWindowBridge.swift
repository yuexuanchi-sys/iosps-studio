import AppKit
import SwiftUI

/// Intercepts only close approval and forwards SwiftUI's other window callbacks.
struct ProjectWindowBridge: NSViewRepresentable {
    let controller: ProjectController
    func makeNSView(context: Context) -> ProjectWindowView { ProjectWindowView(controller: controller) }
    func updateNSView(_ view: ProjectWindowView, context: Context) {
        view.update(controller)
        view.window?.representedURL = controller.session.projectURL
        view.window?.isDocumentEdited = controller.session.isModified
        view.window?.titleVisibility = .hidden
    }
}

final class ProjectWindowView: NSView {
    var controller: ProjectController
    private let proxy = ProjectWindowDelegate()
    init(controller: ProjectController) {
        self.controller = controller
        super.init(frame: .zero)
        proxy.controller = controller
    }
    required init?(coder: NSCoder) { nil }
    func update(_ controller: ProjectController) {
        self.controller = controller
        proxy.controller = controller
        controller.window = window
        controller.workspace?.window = window
    }
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        DispatchQueue.main.async { [weak self] in
            guard let self, let window = self.window else { return }
            self.controller.window = window
            self.controller.workspace?.window = window
            if window.delegate !== self.proxy {
                self.proxy.previous = window.delegate
                window.delegate = self.proxy
            }
            Self.fillScreenOnceForThisBuild(window)
        }
    }

    /// The first launch of each build, a new download or an update, fills the screen (without going full screen), as
    /// `defaultWindowPlacement` does only the very first time; after that macOS reopens the window at the size it was left.
    private static func fillScreenOnceForThisBuild(_ window: NSWindow) {
        let key = "windowFilledScreenForBuild"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? ""
        guard UserDefaults.standard.string(forKey: key) != build, !window.styleMask.contains(.fullScreen),
              let screen = window.screen ?? NSScreen.main else { return }
        UserDefaults.standard.set(build, forKey: key)
        window.setFrame(screen.visibleFrame, display: true)
    }
}

private final class ProjectWindowDelegate: NSObject, NSWindowDelegate {
    weak var previous: NSWindowDelegate?
    weak var controller: ProjectController?
    func windowShouldClose(_ sender: NSWindow) -> Bool {
        guard let controller else { return true }
        Task {
            if let workspace = controller.workspace { await workspace.closeWindow(sender) }
            else { await controller.close(sender) }
        }
        return false
    }
    nonisolated override func responds(to selector: Selector!) -> Bool {
        if super.responds(to: selector) { return true }
        guard Thread.isMainThread else { return false }
        return MainActor.assumeIsolated { previous?.responds(to: selector) == true }
    }

    nonisolated override func forwardingTarget(for selector: Selector!) -> Any? {
        if Thread.isMainThread {
            let forwarded = MainActor.assumeIsolated {
                ForwardedTarget(delegate: previous?.responds(to: selector) == true ? previous : nil)
            }
            if let delegate = forwarded.delegate { return delegate }
        }
        return super.forwardingTarget(for: selector)
    }

    /// Objective-C calls this override synchronously on the window thread.
    private nonisolated struct ForwardedTarget: @unchecked Sendable {
        let delegate: (any NSWindowDelegate)?
    }
}
