import AppKit
import SwiftUI

/// Shares the app's initial greeting with the visual smoke test.
@MainActor
public struct BirthdayGreetingView: View {
    /// Provides a greeting that can be rendered without personal content.
    public init() {}

    public var body: some View {
        ZStack {
            Color(nsColor: .windowBackgroundColor)
            Text("生日快乐", bundle: .module)
                .font(.largeTitle.weight(.semibold))
                .padding(32)
        }
        .frame(minWidth: 360, minHeight: 240)
    }
}
