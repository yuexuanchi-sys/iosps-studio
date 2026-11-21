import AppKit
import GiftKit
import Observation
import SwiftUI
import UniformTypeIdentifiers

enum GiftPage: CaseIterable, Identifiable {
    case birthday, memories, editor

    var id: Self { self }

    var title: LocalizedStringKey {
        switch self {
        case .birthday: "生日"
        case .memories: "回忆"
        case .editor: "修图"
        }
    }

    var symbol: String {
        switch self {
        case .birthday: "sparkles"
        case .memories: "photo.on.rectangle.angled"
        case .editor: "slider.horizontal.3"
        }
    }
}

struct GiftSample {
    let manifest: GiftManifest
    let directory: URL

    static func load() throws -> Self {
        guard let directory = Bundle.main.resourceURL?.appendingPathComponent("gift-sample", isDirectory: true) else {
            throw CocoaError(.fileNoSuchFile)
        }
        let data = try Data(contentsOf: directory.appendingPathComponent("memories.json"))
        return Self(manifest: try JSONDecoder().decode(GiftManifest.self, from: data), directory: directory)
    }

    func url(for photo: GiftFilePath) -> URL {
        directory.appendingPathComponent(photo.value)
    }
}

@Observable
final class GiftNavigation {
    var page: GiftPage = .birthday
    var isPickingPhoto = false
    var lastSavedMovie: URL?
    let sample = try? GiftSample.load()

    func choosePhoto(in workspace: ProjectWorkspace) async {
        guard workspace.canSwitch, !isPickingPhoto else { return }
        isPickingPhoto = true
        defer { isPickingPhoto = false }
        let panel = NSOpenPanel()
        panel.title = String(localized: "选取照片")
        panel.prompt = String(localized: "打开")
        panel.allowedContentTypes = [.jpeg, .png]
        let response = if let window = workspace.window { await panel.beginSheetModal(for: window) } else { await panel.begin() }
        if response == .OK, let url = panel.url {
            await edit(url, in: workspace)
        }
    }

    func edit(_ url: URL, in workspace: ProjectWorkspace) async {
        guard workspace.canSwitch else { return }
        page = .editor
        await workspace.receive([url])
        workspace.current.session.selectTool(.hand)
    }

    func exportMovie(in workspace: ProjectWorkspace) async {
        guard workspace.canSwitch else { return }
        lastSavedMovie = await workspace.current.controller.exportGiftMovie()
    }
}

struct GiftWorkspace: View {
    let workspace: ProjectWorkspace
    let navigation: GiftNavigation
    let largeText: Bool
    @Environment(\.colorScheme) private var colorScheme

    private var paper: Color {
        colorScheme == .dark ? Color(red: 0.13, green: 0.12, blue: 0.11) : Color(red: 0.98, green: 0.96, blue: 0.92)
    }

    private var accent: Color {
        colorScheme == .dark ? Color(red: 0.97, green: 0.72, blue: 0.50) : Color(red: 0.55, green: 0.24, blue: 0.13)
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Text("拾光簿")
                    .font(.system(size: largeText ? 20 : 15, weight: .semibold))
                    .foregroundStyle(accent)
                    .accessibilityAddTraits(.isHeader)
                Spacer(minLength: 12)
                ForEach(GiftPage.allCases) { page in
                    Button {
                        navigation.page = page
                    } label: {
                        Label(page.title, systemImage: page.symbol)
                            .padding(.horizontal, 6)
                    }
                    .buttonStyle(.bordered)
                    .tint(navigation.page == page ? accent : .secondary)
                    .accessibilityAddTraits(navigation.page == page ? .isSelected : [])
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 14)
            Divider()
            switch navigation.page {
            case .birthday:
                GeometryReader { viewport in
                    ScrollView {
                        birthday
                            .frame(maxWidth: 1000, alignment: .leading)
                            .padding(32)
                            .frame(maxWidth: .infinity, minHeight: viewport.size.height)
                    }
                }
            case .memories:
                ScrollView {
                    memories
                        .frame(maxWidth: 1000, alignment: .leading)
                        .padding(32)
                        .frame(maxWidth: .infinity)
                }
            case .editor:
                GiftPhotoEditor(workspace: workspace, navigation: navigation, largeText: largeText)
                    .id(workspace.current.id)
            }
        }
        .frame(minWidth: 760, minHeight: 490)
        .font(.system(size: largeText ? 18 : 14))
        .controlSize(largeText ? .large : .regular)
        .background(paper)
        .background {
            ProjectWindowBridge(controller: workspace.current.controller).frame(width: 0, height: 0)
        }
    }

    private var birthday: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .center, spacing: 38) {
                birthdayMessage.frame(minWidth: 300, alignment: .leading)
                if let sample = navigation.sample, let path = sample.manifest.featuredPhoto {
                    photo(sample.url(for: path)).frame(minWidth: 340, maxWidth: 510)
                }
            }
            VStack(alignment: .leading, spacing: 24) {
                birthdayMessage
                if let sample = navigation.sample, let path = sample.manifest.featuredPhoto {
                    photo(sample.url(for: path))
                }
            }
        }
    }

    private var birthdayMessage: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("生日快乐")
                .font(.system(size: largeText ? 48 : 36, weight: .heavy))
                .accessibilityAddTraits(.isHeader)
            if let manifest = navigation.sample?.manifest, let date = manifest.birthday {
                Text("生日 · \(date.month) 月 \(date.day) 日")
                    .font(.system(size: largeText ? 26 : 19, weight: .medium))
                    .foregroundStyle(accent)
                if let today = try? LocalDay(containing: .now, timeZone: .current),
                   let count = GiftCalendar.metrics(on: today, birthday: date, metOn: manifest.metOn).daysUntilBirthday {
                    if count == 0 {
                        Text("今天是生日")
                    } else {
                        Text("离下次生日还有 \(count) 天")
                    }
                }
            }
            Text("翻翻相册，看看那些一起度过的日子。")
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Button("打开回忆") { navigation.page = .memories }
                .buttonStyle(.borderedProminent)
                .tint(accent)
                .controlSize(.large)
            Text("示例相册")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var memories: some View {
        VStack(alignment: .leading, spacing: 22) {
            Text("回忆")
                .font(.system(size: largeText ? 48 : 36, weight: .heavy))
                .accessibilityAddTraits(.isHeader)
            if let sample = navigation.sample, !sample.manifest.memories.isEmpty {
                ForEach(sample.manifest.memories, id: \.id) { memory in
                    VStack(alignment: .leading, spacing: 10) {
                        Text("\(memory.date.year.formatted(.number.grouping(.never))) 年 \(memory.date.month) 月 \(memory.date.day) 日")
                            .font(.callout)
                            .foregroundStyle(accent)
                        Text(memory.title)
                            .font(.system(size: largeText ? 27 : 20, weight: .semibold))
                            .accessibilityAddTraits(.isHeader)
                        if let note = memory.note {
                            Text(note).foregroundStyle(.secondary)
                        }
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), alignment: .top), count: 2), spacing: 16) {
                            ForEach(Array(memory.photos.enumerated()), id: \.offset) { index, path in
                                let url = sample.url(for: path)
                                VStack(alignment: .leading, spacing: 10) {
                                    photo(url)
                                        .accessibilityLabel(Text("\(memory.title)，第 \(index + 1) 张示例照片"))
                                    Button("编辑示例") { Task { await navigation.edit(url, in: workspace) } }
                                        .buttonStyle(.bordered)
                                        .disabled(!workspace.canSwitch)
                                        .accessibilityIdentifier("gift-edit-sample")
                                }
                            }
                        }
                    }
                }
            } else {
                Text("暂时没有可以浏览的回忆。")
                Button("去修图") { navigation.page = .editor }
            }
        }
    }

    @ViewBuilder
    private func photo(_ url: URL) -> some View {
        if let image = NSImage(contentsOf: url) {
            Image(nsImage: image)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .clipShape(.rect(cornerRadius: 4))
                .padding(8)
                .background(.background, in: .rect(cornerRadius: 8))
        } else {
            ContentUnavailableView("图片无法显示", systemImage: "photo")
        }
    }
}
