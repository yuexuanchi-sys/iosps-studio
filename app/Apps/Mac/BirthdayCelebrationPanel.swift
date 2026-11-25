import AppKit
import DesignSystem
import SwiftUI

@MainActor
final class BirthdayCelebrationPanel {
    private var window: NSPanel?

    func present(wishes: String?, reduceMotion: Bool, onDismiss: @escaping () -> Void) -> Bool {
        guard window == nil else { return false }
        let previous = NSApp.keyWindow ?? NSApp.mainWindow
        guard let screen = previous?.screen ?? NSScreen.main else { return false }
        let panel = CelebrationScreen(contentRect: screen.frame, styleMask: [.borderless], backing: .buffered, defer: false)
        panel.title = String(localized: "生日祝福")
        panel.level = .statusBar
        panel.collectionBehavior = [.fullScreenAuxiliary, .moveToActiveSpace]
        panel.hidesOnDeactivate = true
        panel.isReleasedWhenClosed = false
        panel.contentViewController = NSHostingController(rootView: CelebrationContent(wishes: wishes, reduceMotion: reduceMotion) {
            [weak self, weak previous] in
            self?.window?.orderOut(nil)
            self?.window = nil
            previous?.makeKeyAndOrderFront(nil)
            onDismiss()
        })
        panel.setFrame(screen.frame, display: true)
        window = panel
        panel.makeKeyAndOrderFront(nil)
        return true
    }
}

private final class CelebrationScreen: NSPanel {
    override var canBecomeKey: Bool { true }
}

private struct CelebrationContent: View {
    let wishes: String?
    let reduceMotion: Bool
    let dismiss: () -> Void
    @State private var revealed = false

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            BirthdayGreetingView(enlargedText: true, wishes: wishes)
                .opacity(reduceMotion || revealed ? 1 : 0.62)
            Button("跳过祝福", action: dismiss)
                .keyboardShortcut(.cancelAction)
                .controlSize(.large)
                .padding(32)
                .accessibilityIdentifier(reduceMotion ? "birthday-celebration-static-close" : "birthday-celebration-close")
        }
        .onAppear {
            if !reduceMotion {
                withAnimation(.easeOut(duration: 0.7)) { revealed = true }
            }
        }
    }
}
