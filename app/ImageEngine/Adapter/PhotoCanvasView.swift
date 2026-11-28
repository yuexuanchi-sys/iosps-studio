import SwiftUI

/// Wraps Compositor's AppKit/Metal canvas behind the ImageEngine adapter boundary.
struct PhotoCanvasView: View {
    let session: PhotoEditingSession

    var body: some View {
        EditorCanvas(session: session.editor)
            .clipped()
    }
}
