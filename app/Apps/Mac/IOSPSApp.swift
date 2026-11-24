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
            BirthdayCommands(reload: birthday.reload)
            AboutCommands()
        }
        Window("关于 IOSPS", id: "about") {
            AboutLicensesView()
        }
        .defaultSize(width: 620, height: 460)
    }
}

private struct AboutCommands: Commands {
    @Environment(\.openWindow) private var openWindow

    var body: some Commands {
        CommandGroup(replacing: .appInfo) {
            Button("关于 IOSPS") { openWindow(id: "about") }
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
            }
        }
        .focusedSceneValue(\.openBirthdayEasterEgg, { showsEasterEggNotice = true })
        .sheet(isPresented: $showsEasterEggNotice) {
            VStack(spacing: 16) {
                Text("彩蛋正在准备中")
                    .accessibilityIdentifier("birthday-easter-egg-notice")
                Button("好") { showsEasterEggNotice = false }
                    .keyboardShortcut(.defaultAction)
                    .accessibilityIdentifier("birthday-easter-egg-dismiss")
            }
            .padding(24)
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

private struct BirthdayCommands: Commands {
    @FocusedValue(\.openBirthdayEasterEgg) private var openEasterEgg
    let reload: () -> Void

    var body: some Commands {
        CommandMenu("生日") {
            Button("打开彩蛋") { openEasterEgg?() }
                .keyboardShortcut("e", modifiers: [.command, .shift])
                .disabled(openEasterEgg == nil)
            Button("重新加载生日素材", action: reload)
        }
    }
}

private struct OpenBirthdayEasterEgg: FocusedValueKey {
    typealias Value = () -> Void
}

private extension FocusedValues {
    var openBirthdayEasterEgg: (() -> Void)? {
        get { self[OpenBirthdayEasterEgg.self] }
        set { self[OpenBirthdayEasterEgg.self] = newValue }
    }
}
