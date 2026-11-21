import DesignSystem
import Foundation
import GiftKit
import MediaIO
import SwiftUI

@main
@MainActor
struct IOSPSApp: App {
    private static let applicationDirectory = URL.applicationSupportDirectory.appending(path: "org.iosps.birthday")
    @State private var session = MediaImportSession(library: MediaLibrary(
        directory: Self.applicationDirectory.appending(path: "Media", directoryHint: .isDirectory)
    ))
    @State private var birthday = BirthdayHomeSession(
        directory: Self.applicationDirectory.appending(path: "content/private", directoryHint: .isDirectory)
    )

    var body: some Scene {
        WindowGroup {
            MainWindow(session: session, birthday: birthday)
        }
        .defaultSize(width: 720, height: 480)
        .commands {
            CommandMenu("生日") {
                Button("重新加载生日素材", action: birthday.reload)
            }
        }
    }
}

private struct MainWindow: View {
    let session: MediaImportSession
    let birthday: BirthdayHomeSession
    @State private var showsMedia = false
    @State private var showsEasterEggNotice = false

    var body: some View {
        Group {
            if showsMedia {
                MediaImportView(session: session)
            } else {
                TimelineView(.periodic(from: .now, by: 60)) { context in
                    let today = try? LocalDay(containing: context.date, timeZone: .autoupdatingCurrent)
                    BirthdayGreetingView(
                        wishes: birthday.wishes,
                        birthday: birthday.birthday,
                        metrics: today.map { birthday.metrics(on: $0) },
                        configurationFailed: birthday.reloadFailed,
                        onEasterEgg: { showsEasterEggNotice = true }
                    )
                }
                .alert("彩蛋正在准备中", isPresented: $showsEasterEggNotice) {
                    Button("好", role: .cancel) {}
                }
            }
        }
        .toolbar {
            Button {
                showsMedia.toggle()
            } label: {
                if showsMedia {
                    Label("返回生日主页", systemImage: "house")
                } else {
                    Label("导入素材", systemImage: "photo.on.rectangle")
                }
            }
            .accessibilityIdentifier("shared-media-entry")
            .help(showsMedia ? Text("返回生日主页") : Text("导入素材"))
        }
    }
}
