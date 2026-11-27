import Foundation

/// Pairs a decoded built-in memory movie template with user-facing presentation metadata.
public struct BuiltInTemplateDescriptor: Equatable, Sendable {
    public let template: MemoryTemplate
    public let subtitle: String
    public let musicTitle: String
    public let isRecommended: Bool

    public init(
        template: MemoryTemplate,
        subtitle: String,
        musicTitle: String,
        isRecommended: Bool
    ) {
        self.template = template
        self.subtitle = subtitle
        self.musicTitle = musicTitle
        self.isRecommended = isRecommended
    }
}

/// Loads the eight bundled v1 memory movie templates packaged inside TemplateKit.
public enum BuiltInMemoryTemplateCatalog {
    public enum CatalogError: Error, Equatable, Sendable {
        case missingResource(String)
    }

    private struct Entry {
        let resourceName: String
        let subtitle: String
        let isRecommended: Bool
    }

    private static let entries: [Entry] = [
        Entry(resourceName: "01-warm-keepsake", subtitle: "柔和慢推 · 温暖钢琴", isRecommended: true),
        Entry(resourceName: "02-birthday-candle", subtitle: "舒缓拉远 · 八音盒", isRecommended: false),
        Entry(resourceName: "03-sunny-journey", subtitle: "轻快平移 · 晴日拨弦", isRecommended: false),
        Entry(resourceName: "04-film-diary", subtitle: "硬切慢拍 · 温暖钢琴", isRecommended: false),
        Entry(resourceName: "05-starry-night", subtitle: "悠长叠化 · 星夜独白", isRecommended: false),
        Entry(resourceName: "06-bloom-season", subtitle: "自然摇镜 · 晴日拨弦", isRecommended: false),
        Entry(resourceName: "07-polaroid-notes", subtitle: "明快切镜 · 八音盒", isRecommended: false),
        Entry(resourceName: "08-years-together", subtitle: "沉稳回忆 · 星夜独白", isRecommended: false),
    ]

    /// Maps built-in soundtrack asset IDs to human-readable Chinese titles.
    public static func musicDisplayTitle(for assetID: String) -> String {
        switch assetID {
        case "warm-piano": "温暖钢琴"
        case "music-box": "晶莹八音盒"
        case "sunny-acoustic": "晴日拨弦"
        case "starry-nocturne": "星夜独白"
        default: assetID
        }
    }

    /// Decodes all eight bundled templates in canonical display order.
    public static func load() throws -> [BuiltInTemplateDescriptor] {
        let decoder = JSONDecoder()
        return try entries.map { entry in
            let url = Bundle.module.url(
                forResource: entry.resourceName,
                withExtension: "json",
                subdirectory: "MemoryTemplates"
            ) ?? Bundle.module.url(
                forResource: entry.resourceName,
                withExtension: "json"
            )
            guard let url else {
                throw CatalogError.missingResource(entry.resourceName)
            }
            let data = try Data(contentsOf: url)
            let template = try decoder.decode(MemoryTemplate.self, from: data)
            let musicTitle = template.music.map { musicDisplayTitle(for: $0.assetID) } ?? "静音"
            return BuiltInTemplateDescriptor(
                template: template,
                subtitle: entry.subtitle,
                musicTitle: musicTitle,
                isRecommended: entry.isRecommended
            )
        }
    }
}
