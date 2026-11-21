import AppKit
import SwiftUI

/// Shares the app's initial greeting with the visual smoke test.
@MainActor
public struct BirthdayGreetingView: View {
    private let enlargedText: Bool

    /// Provides a greeting that can be rendered without personal content.
    public init(enlargedText: Bool = false) {
        self.enlargedText = enlargedText
    }

    public var body: some View {
        ZStack {
            Color(nsColor: .windowBackgroundColor)
            Text("生日快乐", bundle: .module)
                .font(enlargedText ? .system(size: 44, weight: .semibold) : .largeTitle.weight(.semibold))
                .padding(32)
        }
        .frame(minWidth: 360, minHeight: 240)
    }
}
