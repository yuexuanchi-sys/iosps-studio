import AppKit
import SwiftUI

extension View {
    /// Bordered buttons and pop-up menus drawn as capsules throughout Compositor controls.
    func roundedControls() -> some View { buttonBorderShape(.capsule) }
}

extension View {
    /// Return or Escape in a property field hands focus back to the canvas.
    func releasesFocusOnCommit(_ session: EditorSession) -> some View {
        onSubmit { session.canvasFocusRequest += 1 }
            .onExitCommand { session.canvasFocusRequest += 1 }
    }
}

/// Shared key monitor backing Up/Down stepping in numeric fields.
@MainActor final class ArrowStepper {
    var editing = false
    var value: @MainActor () -> Double = { 0 }
    var change: @MainActor (Double) -> Void = { _ in }
    private var monitor: Any?

    func listen(step: Double) {
        guard monitor == nil else { return }
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self, self.editing, event.keyCode == 126 || event.keyCode == 125,
                  NSApp.keyWindow?.firstResponder is NSTextView else { return event }
            let amount = step * (event.modifierFlags.contains(.shift) ? 10 : 1)
            self.change(self.value() + (event.keyCode == 126 ? amount : -amount))
            return nil
        }
    }

    func stopListening() {
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
        editing = false
    }

    isolated deinit {
        if let monitor { NSEvent.removeMonitor(monitor) }
    }
}

private struct ArrowStepping: ViewModifier {
    let step: Double
    let value: @MainActor () -> Double
    let change: @MainActor (Double) -> Void
    @FocusState private var focused: Bool
    @State private var stepper = ArrowStepper()

    func body(content: Content) -> some View {
        content
            .focused($focused)
            .onChange(of: focused) { _, editing in
                stepper.editing = editing
                editing ? stepper.listen(step: step) : stepper.stopListening()
            }
            .onDisappear { stepper.stopListening() }
            .onAppear { refresh() }
            .onChange(of: value()) { _, _ in refresh() }
    }

    private func refresh() {
        stepper.value = value
        stepper.change = change
    }
}

extension View {
    @MainActor
    func arrowSteps(_ step: Double = 1, value: @escaping @MainActor () -> Double,
                    change: @escaping @MainActor (Double) -> Void) -> some View {
        modifier(ArrowStepping(step: step, value: value, change: change))
    }

    @MainActor
    func arrowSteps(_ step: Double = 1, editing: Bool, stepper: ArrowStepper,
                    value: @escaping @MainActor () -> Double, change: @escaping @MainActor (Double) -> Void) -> some View {
        onAppear { stepper.value = value; stepper.change = change }
            .onChange(of: value()) { _, _ in stepper.value = value; stepper.change = change }
            .onChange(of: editing) { _, active in
                stepper.editing = active
                stepper.value = value
                stepper.change = change
                active ? stepper.listen(step: step) : stepper.stopListening()
            }
            .onDisappear { stepper.stopListening() }
    }
}
