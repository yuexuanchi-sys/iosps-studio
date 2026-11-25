import Foundation
import SwiftUI

struct LicenseNotice: Identifiable {
    let id: String
    let title: String
    let license: String
    let source: URL
    let text: String

    private struct Entry: Decodable {
        let id: String
        let title: String
        let license: String
        let source: URL
    }

    static func load(from bundle: Bundle = .main) throws -> [Self] {
        func resource(_ name: String, type: String) throws -> URL {
            guard let url = bundle.url(forResource: name, withExtension: type, subdirectory: "Notices") else {
                throw CocoaError(.fileReadNoSuchFile)
            }
            return url
        }

        let entries = try JSONDecoder().decode([Entry].self, from: Data(contentsOf: resource("licenses", type: "json")))
        return try entries.map { entry in
            let text = try String(contentsOf: resource(entry.id, type: "txt"), encoding: .utf8)
            return Self(id: entry.id, title: entry.title, license: entry.license, source: entry.source, text: text)
        }
    }
}

struct AboutLicensesView: View {
    private let notices: [LicenseNotice]
    @State private var selection: LicenseNotice.ID?

    init() {
        let notices = (try? LicenseNotice.load()) ?? []
        self.notices = notices
        _selection = State(initialValue: notices.first?.id)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("许可与致谢")
                .font(.title2.weight(.semibold))
                .accessibilityAddTraits(.isHeader)
            Text("本应用使用 macOS 系统框架与字体，以及以下开源组件与工具。")
                .foregroundStyle(.secondary)
            if let notice = notices.first(where: { $0.id == selection }) {
                Picker("组件与工具", selection: $selection) {
                    ForEach(notices) { item in
                        Text(verbatim: item.title).tag(Optional(item.id))
                    }
                }
                .pickerStyle(.menu)
                .accessibilityIdentifier("license-picker")
                HStack {
                    Text(verbatim: notice.license)
                    Link("查看上游来源", destination: notice.source)
                }
                Divider()
                ScrollView {
                    Text(verbatim: notice.text)
                        .font(.system(.body, design: .monospaced))
                        .textSelection(.enabled)
                        .accessibilityIdentifier("license-text")
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .id(notice.id)
            } else {
                Text("无法读取本机许可资料。")
                Spacer()
            }
        }
        .padding(20)
        .frame(minWidth: 440, minHeight: 320)
    }
}
