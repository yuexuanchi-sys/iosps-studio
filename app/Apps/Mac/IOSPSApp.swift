import DesignSystem
import SwiftUI

@main
@MainActor
struct IOSPSApp: App {
    var body: some Scene {
        WindowGroup {
            BirthdayGreetingView()
        }
        .defaultSize(width: 720, height: 480)
    }
}
