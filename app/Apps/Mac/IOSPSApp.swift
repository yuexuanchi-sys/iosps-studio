import DesignSystem
import Foundation
import GiftKit
import MediaIO
import SwiftUI

@main
@MainActor
struct IOSPSApp: App {
    private static let applicationDirectory = URL.applicationSupportDirectory.appending(path: "org.iosps.birthday")
    @State private var session: MediaImportSession
    @State private var photoMovie: PhotoMovieSession
    @State private var editor: VideoEditingSession
    @State private var birthday = Self.makeBirthdaySession()
    @State private var celebration = BirthdayCelebrationPanel()

    init() {
        let local = Self.localDataDirectory()
        let library = MediaLibrary(directory: local.appending(path: "Media", directoryHint: .isDirectory))
        let drafts = FileDraftStore(directory: local.appending(path: "Drafts", directoryHint: .isDirectory))
        _session = State(wrappedValue: MediaImportSession(library: library))
        _photoMovie = State(wrappedValue: PhotoMovieSession(library: library))
        _editor = State(wrappedValue: VideoEditingSession(library: library, drafts: drafts))
    }

    var body: some Scene {
        WindowGroup {
            MainWindow(session: session, photoMovie: photoMovie, editor: editor, birthday: birthday, celebration: celebration)
        }
        .defaultSize(width: 820, height: 560)
        .commands {
            BirthdayCommands(reload: birthday.reload)
            AboutCommands()
        }
        Window("关于 IOSPS", id: "about") {
            AboutLicensesView()
        }
        .defaultSize(width: 620, height: 460)
    }

    private static func localDataDirectory() -> URL {
        #if DEBUG
        if let directory = ProcessInfo.processInfo.environment["IOSPS_TEST_VIDEO_DIRECTORY"] {
            return URL(fileURLWithPath: directory, isDirectory: true)
        }
        #endif
        return applicationDirectory
    }

    private static func makeBirthdaySession() -> BirthdayHomeSession {
        #if DEBUG
        let environment = ProcessInfo.processInfo.environment
        if let directory = environment["IOSPS_TEST_GIFT_DIRECTORY"],
           let suite = environment["IOSPS_TEST_GIFT_DEFAULTS"],
           let defaults = UserDefaults(suiteName: suite) {
            return BirthdayHomeSession(directory: URL(fileURLWithPath: directory, isDirectory: true),
                                       defaults: defaults,
                                       fixedDay: environment["IOSPS_TEST_GIFT_DATE"].flatMap { try? LocalDay(isoDate: $0) })
        }
        #endif
        return BirthdayHomeSession(directory: applicationDirectory.appending(path: "content/private", directoryHint: .isDirectory))
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
    private enum Page { case birthday, media, movie, video }

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let session: MediaImportSession
    let photoMovie: PhotoMovieSession
    let editor: VideoEditingSession
    let birthday: BirthdayHomeSession
    let celebration: BirthdayCelebrationPanel
    @State private var pageSelection = Page.birthday
    @State private var showsEasterEggNotice = false
    @State private var eggTrigger = EasterEggTrigger()
    @State private var eggFocusRequest = 0
    @State private var titleFocusRequest = 0
    @State private var checkedFirstLaunch = false

    var body: some View {
        page
            .task {
                guard !checkedFirstLaunch else { return }
                checkedFirstLaunch = true
                if let day = birthday.day(), birthday.shouldPresentAutomatically(on: day), presentCelebration() {
                    birthday.recordAutomaticPresentation(on: day)
                }
            }
            .focusedSceneValue(\.birthdayActions, BirthdayActions(
                openEgg: openEasterEgg,
                replay: replay,
                canReplay: pageSelection == .birthday && birthday.day().map { birthday.metrics(on: $0).isBirthday } == true
            ))
            .sheet(isPresented: $showsEasterEggNotice, onDismiss: { eggFocusRequest += 1 }) {
                eggSheet
            }
            .toolbar { mediaToolbar }
    }

    @ViewBuilder
    private var page: some View {
        if pageSelection == .media {
            MediaImportView(session: session)
        } else if pageSelection == .movie {
            PhotoMovieView(session: photoMovie)
        } else if pageSelection == .video {
            VideoEditorView(session: editor)
        } else {
            TimelineView(.periodic(from: .now, by: 60)) { context in
                greeting(at: context.date)
            }
        }
    }

    private func greeting(at date: Date) -> BirthdayGreetingView {
        let today = birthday.day(at: date)
        let metrics = today.map { birthday.metrics(on: $0) }
        return BirthdayGreetingView(
            wishes: birthday.wishes,
            birthday: birthday.birthday,
            metrics: metrics,
            configurationFailed: birthday.reloadFailed,
            onEasterEgg: countEggTap,
            openAccessibleEgg: openEasterEgg,
            replayCelebration: replay,
            eggFocusRequest: eggFocusRequest,
            titleFocusRequest: titleFocusRequest
        )
    }

    private var eggSheet: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("生日彩蛋")
                .font(.title2.weight(.semibold))
                .accessibilityAddTraits(.isHeader)
            if let egg = birthday.easterEgg {
                ScrollView {
                    Text(verbatim: egg)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .accessibilityIdentifier("birthday-easter-egg-message")
                }
                .frame(idealHeight: 112, maxHeight: 260)
            } else {
                Text("彩蛋还未准备好。添加本地素材后，可从「生日」菜单重新加载。")
                    .accessibilityIdentifier("birthday-easter-egg-notice")
            }
            Button("好") { showsEasterEggNotice = false }
                .keyboardShortcut(.cancelAction)
                .accessibilityIdentifier("birthday-easter-egg-dismiss")
        }
        .padding(24)
        .frame(width: 365)
    }

    @ToolbarContentBuilder
    private var mediaToolbar: some ToolbarContent {
        ToolbarItem(placement: .automatic) {
            Button {
                navigate(to: .media)
            } label: {
                if pageSelection == .media {
                    Label("返回生日主页", systemImage: "house")
                } else {
                    Label("导入素材", systemImage: "photo.on.rectangle")
                }
            }
            .accessibilityIdentifier("shared-media-entry")
            .help(pageSelection == .media ? Text("返回生日主页") : Text("导入素材"))
        }
        ToolbarItem(placement: .automatic) {
            Button {
                navigate(to: .movie)
            } label: {
                if pageSelection == .movie {
                    Label("返回生日主页", systemImage: "house")
                } else {
                    Label("回忆短片", systemImage: "film.stack")
                }
            }
            .accessibilityIdentifier("photo-movie-entry")
            .help(pageSelection == .movie ? Text("返回生日主页") : Text("回忆短片"))
        }
        ToolbarItem(placement: .automatic) {
            Button {
                navigate(to: .video)
            } label: {
                if pageSelection == .video {
                    Label("返回生日主页", systemImage: "house")
                } else {
                    Label("剪辑", systemImage: "scissors")
                }
            }
            .accessibilityIdentifier("video-editor-entry")
            .help(pageSelection == .video ? Text("返回生日主页") : Text("剪辑"))
        }
    }

    private func navigate(to target: Page) {
        eggTrigger = EasterEggTrigger()
        pageSelection = pageSelection == target ? .birthday : target
    }

    private func countEggTap() {
        if eggTrigger.registerTap(at: ContinuousClock.now) {
            openEasterEgg()
        }
    }

    private func openEasterEgg() {
        eggTrigger = EasterEggTrigger()
        showsEasterEggNotice = true
    }

    private func replay() {
        guard pageSelection == .birthday, let day = birthday.day(), birthday.metrics(on: day).isBirthday else { return }
        _ = presentCelebration()
    }

    private func presentCelebration() -> Bool {
        var prefersStaticGreeting = reduceMotion
        #if DEBUG
        if let fixture = ProcessInfo.processInfo.environment["IOSPS_TEST_GIFT_REDUCE_MOTION"] {
            prefersStaticGreeting = fixture == "1"
        }
        #endif
        return celebration.present(wishes: birthday.wishes, reduceMotion: prefersStaticGreeting) {
            titleFocusRequest += 1
        }
    }
}

private struct BirthdayCommands: Commands {
    @FocusedValue(\.birthdayActions) private var actions
    let reload: () -> Void

    var body: some Commands {
        CommandMenu("生日") {
            Button("打开彩蛋") { actions?.openEgg() }
                .keyboardShortcut("e", modifiers: [.command, .shift])
                .disabled(actions == nil)
            Button("重播生日祝福") { actions?.replay() }
                .disabled(actions?.canReplay != true)
            Button("重新加载生日素材", action: reload)
        }
    }
}

private struct BirthdayActions {
    let openEgg: () -> Void
    let replay: () -> Void
    let canReplay: Bool
}

private struct BirthdayActionsKey: FocusedValueKey {
    typealias Value = BirthdayActions
}

private extension FocusedValues {
    var birthdayActions: BirthdayActions? {
        get { self[BirthdayActionsKey.self] }
        set { self[BirthdayActionsKey.self] = newValue }
    }
}
