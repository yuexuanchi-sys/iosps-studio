import AppKit
import SwiftUI

struct FinderDropTarget: NSViewRepresentable {
    let acceptsDrops: Bool
    @Binding var isTargeted: Bool
    let importFiles: ([URL]) -> Bool

    func makeNSView(context: Context) -> DropView {
        let view = DropView(frame: .zero)
        view.registerForDraggedTypes([.fileURL])
        return view
    }

    func updateNSView(_ view: DropView, context: Context) {
        view.acceptsDrops = acceptsDrops
        view.setTargeted = { isTargeted = $0 }
        view.importFiles = importFiles
    }

    final class DropView: NSView {
        var acceptsDrops = false
        var setTargeted: ((Bool) -> Void)?
        var importFiles: (([URL]) -> Bool)?

        override func draggingEntered(_ sender: any NSDraggingInfo) -> NSDragOperation {
            updateDrag(sender)
        }

        override func draggingUpdated(_ sender: any NSDraggingInfo) -> NSDragOperation {
            updateDrag(sender)
        }

        override func draggingExited(_ sender: (any NSDraggingInfo)?) {
            setTargeted?(false)
        }

        override func performDragOperation(_ sender: any NSDraggingInfo) -> Bool {
            setTargeted?(false)
            guard acceptsDrops else { return false }
            let files = Self.fileURLs(from: sender.draggingPasteboard)
            return importFiles?(files) ?? false
        }

        static func fileURLs(from pasteboard: NSPasteboard) -> [URL] {
            pasteboard.readObjects(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true])
                as? [URL] ?? []
        }

        private func updateDrag(_ sender: any NSDraggingInfo) -> NSDragOperation {
            let accepts = acceptsDrops && sender.draggingSourceOperationMask.contains(.copy)
            setTargeted?(accepts)
            return accepts ? .copy : []
        }
    }
}
