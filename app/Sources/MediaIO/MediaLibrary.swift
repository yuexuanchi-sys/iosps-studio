import BirthdayCore
import Foundation

/// Identifies the media pipeline that can use a library item.
public enum MediaKind: Equatable, Sendable {
    case photo
    case video
}

/// Resolves a portable project reference to files in the app's local media library.
public struct ImportedMedia: Equatable, Sendable {
    public let id: MediaID
    public let kind: MediaKind
    public let sourceURL: URL
    public let thumbnailURL: URL
}

/// Gives the file picker a stable reason to display for each failed item.
public enum MediaImportError: Error, Equatable {
    case unsupportedFormat
    case unreadableFile
    case unreadableMedia
    case thumbnailFailed
    case storageFailed
    case cancelled
}

/// Publishes an original and its thumbnail together only after a successful import.
public actor MediaLibrary {
    private let directory: URL

    private enum Format: String, Codable {
        case jpg, jpeg, png, heic, mov, mp4

        var kind: MediaKind {
            switch self {
            case .jpg, .jpeg, .png, .heic: .photo
            case .mov, .mp4: .video
            }
        }
    }

    /// Uses an app-owned directory so source permissions aren't needed after import.
    public init(directory: URL) {
        self.directory = directory
    }

    /// Returns one outcome per input URL in the order received from the picker.
    public func importFiles(_ urls: [URL]) async -> [Result<ImportedMedia, MediaImportError>] {
        var results: [Result<ImportedMedia, MediaImportError>] = []
        results.reserveCapacity(urls.count)
        for url in urls {
            do throws(MediaImportError) {
                results.append(.success(try await importFile(url)))
            } catch {
                results.append(.failure(error))
            }
        }
        return results
    }

    /// Reopens a published item using its identity after restarting the application.
    public func load(id: MediaID) throws -> ImportedMedia? {
        let folder = publishedFolder(for: id)
        guard FileManager.default.fileExists(atPath: folder.path) else { return nil }
        let format = try JSONDecoder().decode(Format.self, from: Data(contentsOf: metadataURL(in: folder)))
        let item = item(at: folder, id: id, format: format)
        guard FileManager.default.fileExists(atPath: item.sourceURL.path),
              FileManager.default.fileExists(atPath: item.thumbnailURL.path) else {
            throw MediaImportError.storageFailed
        }
        return item
    }

    private func importFile(_ url: URL) async throws(MediaImportError) -> ImportedMedia {
        guard !Task.isCancelled else { throw .cancelled }
        guard url.isFileURL, let format = Format(rawValue: url.pathExtension.lowercased()) else {
            throw .unsupportedFormat
        }

        let id = MediaID()
        let stage = directory.appendingPathComponent(".staging-\(id.rawValue.uuidString)", isDirectory: true)
        do {
            try FileManager.default.createDirectory(at: stage, withIntermediateDirectories: true)
        } catch {
            throw .storageFailed
        }
        defer { try? FileManager.default.removeItem(at: stage) }

        let stagedItem = item(at: stage, id: id, format: format)
        try copySource(url, to: stagedItem.sourceURL)
        let image = try await MediaThumbnailRenderer.readImage(for: stagedItem)
        guard !Task.isCancelled else { throw .cancelled }
        try MediaThumbnailRenderer.writePNG(image, to: stagedItem.thumbnailURL)
        let destination = publishedFolder(for: id)
        do {
            try JSONEncoder().encode(format).write(to: metadataURL(in: stage), options: .atomic)
            try FileManager.default.moveItem(at: stage, to: destination)
        } catch {
            throw .storageFailed
        }
        return item(at: destination, id: id, format: format)
    }

    private func copySource(_ url: URL, to destination: URL) throws(MediaImportError) {
        let hasScope = url.startAccessingSecurityScopedResource()
        defer {
            if hasScope { url.stopAccessingSecurityScopedResource() }
        }
        do {
            let values = try url.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey])
            guard values.isRegularFile == true, values.isSymbolicLink != true else {
                throw MediaImportError.unreadableFile
            }
            try FileManager.default.copyItem(at: url, to: destination)
        } catch {
            throw .unreadableFile
        }
    }

    private func publishedFolder(for id: MediaID) -> URL {
        directory.appendingPathComponent(id.rawValue.uuidString, isDirectory: true)
    }

    private func item(at folder: URL, id: MediaID, format: Format) -> ImportedMedia {
        ImportedMedia(
            id: id,
            kind: format.kind,
            sourceURL: folder.appendingPathComponent("original").appendingPathExtension(format.rawValue),
            thumbnailURL: folder.appendingPathComponent("preview.png")
        )
    }

    private func metadataURL(in folder: URL) -> URL {
        folder.appendingPathComponent("format.json")
    }
}
