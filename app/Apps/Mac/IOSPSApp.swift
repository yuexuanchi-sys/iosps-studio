import DesignSystem
import Foundation
import MediaIO
import SwiftUI

@main
@MainActor
struct IOSPSApp: App {
    @State private var session = MediaImportSession(library: MediaLibrary(
        directory: URL.applicationSupportDirectory
            .appending(path: "org.iosps.birthday/Media")
    ))

    var body: some Scene {
        WindowGroup {
            MainWindow(session: session)
        }
        .defaultSize(width: 720, height: 480)
    }
}

private struct MainWindow: View {
    let session: MediaImportSession
    @State private var showsMedia = false

    var body: some View {
        Group {
            if showsMedia {
                MediaImportView(session: session)
            } else {
                BirthdayGreetingView()
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
            .help(showsMedia ? Text("返回生日主页") : Text("导入素材"))
        }
    }
}
