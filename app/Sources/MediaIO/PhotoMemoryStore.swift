import BirthdayCore
import CoreGraphics
import Foundation
import ImageIO

/// Payload emitted after a substantive photo project save, ready for local timeline publication.
public struct PhotoMemoryPublication: Equatable, Sendable {
    public let projectID: ProjectID
    public let title: String
    public let projectURL: URL
    public let savedAt: Date
    public let pixelWidth: Int
    public let pixelHeight: Int
    public let previewPNGData: Data

    public init(
        projectID: ProjectID,
        title: String,
        projectURL: URL,
        savedAt: Date,
        pixelWidth: Int,
        pixelHeight: Int,
        previewPNGData: Data
    ) {
        self.projectID = projectID
        self.title = title
        self.projectURL = projectURL
        self.savedAt = savedAt
        self.pixelWidth = pixelWidth
        self.pixelHeight = pixelHeight
        self.previewPNGData = previewPNGData
    }
}

/// Per-entry disk availability status so one broken file never prevents viewing other memories.
public enum PhotoMemoryEntryHealth: Equatable, Sendable {
    case ready(projectURL: URL, media: ImportedMedia)
    case missingProject(projectURL: URL, media: ImportedMedia?)
    case unreadableProject(projectURL: URL, media: ImportedMedia?)
    case damagedPreview(projectURL: URL)
}

/// Timeline entry paired with its live local file and preview health.
public struct ResolvedPhotoMemory: Identifiable, Equatable, Sendable {
    public let entry: PhotoMemoryEntry
    public let health: PhotoMemoryEntryHealth

    public var id: ProjectID { entry.id }
    public var projectURL: URL { URL(fileURLWithPath: entry.projectPath) }

    public var previewThumbnailURL: URL? {
        switch health {
        case .ready(_, let media):
            media.thumbnailURL
        case .missingProject(_, let media), .unreadableProject(_, let media):
            media?.thumbnailURL
        case .damagedPreview:
            nil
        }
    }

    public var previewImageURL: URL? {
        switch health {
        case .ready(_, let media):
            media.sourceURL
        case .missingProject(_, let media), .unreadableProject(_, let media):
            media?.sourceURL
        case .damagedPreview:
            nil
        }
    }

    public var movieMedia: ImportedMedia? {
        switch health {
        case .ready(_, let media):
            media
        case .missingProject(_, let media), .unreadableProject(_, let media):
            media
        case .damagedPreview:
            nil
        }
    }

    public var canReopenProject: Bool {
        switch health {
        case .ready, .damagedPreview:
            true
        case .missingProject, .unreadableProject:
            false
        }
    }

    public init(entry: PhotoMemoryEntry, health: PhotoMemoryEntryHealth) {
        self.entry = entry
        self.health = health
    }
}

public enum PhotoMemoryStoreError: Error, Equatable, Sendable {
    case emptyPreview
    case previewImportFailed
    case writeFailed
}

/// Atomically persists the local photo memory timeline and publishes saved previews into `MediaLibrary`.
public actor PhotoMemoryStore {
    private let directory: URL
    private let library: MediaLibrary

    public init(directory: URL, library: MediaLibrary) {
        self.directory = directory
        self.library = library
    }

    /// Loads the persisted timeline, returning an empty timeline if no index has been written yet.
    public func loadTimeline() throws -> PhotoMemoryTimeline {
        let indexURL = timelineURL
        let data: Data
        do {
            data = try Data(contentsOf: indexURL)
        } catch let error as CocoaError where error.code == .fileReadNoSuchFile || error.code == .fileNoSuchFile {
            return PhotoMemoryTimeline()
        }
        return try JSONDecoder().decode(PhotoMemoryTimeline.self, from: data)
    }

    /// Publishes a saved photo's preview into `MediaLibrary` and atomically updates the timeline index.
    /// If writing the index fails (e.g. read-only directory), any earlier index file stays untouched.
    public func publish(_ publication: PhotoMemoryPublication) async throws -> PhotoMemoryTimeline {
        guard !publication.previewPNGData.isEmpty else {
            throw PhotoMemoryStoreError.emptyPreview
        }
        let fm = FileManager.default
        let tempPNG = fm.temporaryDirectory.appendingPathComponent("iosps-memory-\(UUID().uuidString).png")
        try publication.previewPNGData.write(to: tempPNG, options: .atomic)
        defer { try? fm.removeItem(at: tempPNG) }

        let importedResults = await library.importFiles([tempPNG])
        guard let firstResult = importedResults.first,
              let importedMedia = try? firstResult.get(),
              importedMedia.kind == .photo else {
            throw PhotoMemoryStoreError.previewImportFailed
        }

        var timeline = try loadTimeline()
        let entry = PhotoMemoryEntry(
            id: publication.projectID,
            title: publication.title,
            projectPath: publication.projectURL.path,
            previewMediaID: importedMedia.id,
            savedAt: publication.savedAt,
            pixelWidth: publication.pixelWidth,
            pixelHeight: publication.pixelHeight
        )
        timeline.record(entry)
        try writeAtomically(timeline)
        return timeline
    }

    /// Inspects every timeline entry independently so missing projects, revoked permissions, or corrupt thumbnails
    /// are reported per item while healthy entries remain accessible.
    public func resolve(_ timeline: PhotoMemoryTimeline) async -> [ResolvedPhotoMemory] {
        var resolved: [ResolvedPhotoMemory] = []
        resolved.reserveCapacity(timeline.entries.count)
        for entry in timeline.entries {
            let media = await loadVerifiedMedia(id: entry.previewMediaID)
            let projectURL = URL(fileURLWithPath: entry.projectPath)
            let health: PhotoMemoryEntryHealth
            if !FileManager.default.fileExists(atPath: projectURL.path) {
                health = .missingProject(projectURL: projectURL, media: media)
            } else if !Self.isReadableProject(at: projectURL) {
                health = .unreadableProject(projectURL: projectURL, media: media)
            } else if let media {
                health = .ready(projectURL: projectURL, media: media)
            } else {
                health = .damagedPreview(projectURL: projectURL)
            }
            resolved.append(ResolvedPhotoMemory(entry: entry, health: health))
        }
        return resolved
    }

    private var timelineURL: URL {
        directory.appendingPathComponent("timeline.json")
    }

    private func writeAtomically(_ timeline: PhotoMemoryTimeline) throws {
        let fm = FileManager.default
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let payload = try encoder.encode(timeline)
        do {
            try fm.createDirectory(at: directory, withIntermediateDirectories: true)
            let staging = directory.appendingPathComponent(".timeline.\(UUID().uuidString).staging")
            defer { try? fm.removeItem(at: staging) }
            try payload.write(to: staging, options: [])
            let destination = timelineURL
            if fm.fileExists(atPath: destination.path) {
                _ = try fm.replaceItemAt(destination, withItemAt: staging, backupItemName: nil, options: [])
            } else {
                try fm.moveItem(at: staging, to: destination)
            }
        } catch {
            throw PhotoMemoryStoreError.writeFailed
        }
    }

    private func loadVerifiedMedia(id: MediaID) async -> ImportedMedia? {
        guard let media = try? await library.load(id: id),
              Self.isDecodableImage(at: media.thumbnailURL),
              Self.isDecodableImage(at: media.sourceURL) else {
            return nil
        }
        return media
    }

    private static func isReadableProject(at url: URL) -> Bool {
        let fm = FileManager.default
        guard fm.isReadableFile(atPath: url.path) else { return false }
        var isDirectory: ObjCBool = false
        guard fm.fileExists(atPath: url.path, isDirectory: &isDirectory) else { return false }
        if isDirectory.boolValue {
            let manifestURL = url.appendingPathComponent("manifest.json")
            guard fm.isReadableFile(atPath: manifestURL.path),
                  let data = try? Data(contentsOf: manifestURL),
                  !data.isEmpty else {
                return false
            }
            return true
        }
        return (try? Data(contentsOf: url)) != nil
    }

    private static func isDecodableImage(at url: URL) -> Bool {
        guard FileManager.default.isReadableFile(atPath: url.path),
              let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              CGImageSourceGetCount(source) > 0,
              CGImageSourceCreateImageAtIndex(source, 0, nil) != nil else {
            return false
        }
        return true
    }
}
