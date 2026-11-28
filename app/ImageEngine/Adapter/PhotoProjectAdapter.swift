import BirthdayCore
import CoreGraphics
import CryptoKit
import Foundation
import UniformTypeIdentifiers

/// Stable reference to a saved photo project across launches without leaking upstream `.comp` internals.
nonisolated struct PhotoProjectReference: Equatable, Hashable, Codable, Sendable {
    let projectID: ProjectID
    let fileURL: URL
}

/// Emitted only when a photo project with substantive edits is successfully written to disk.
nonisolated struct PhotoProjectSavedEvent: Equatable, Sendable {
    let reference: PhotoProjectReference
    let title: String
    let savedAt: Date
    let pixelWidth: Int
    let pixelHeight: Int
    let previewPNGData: Data
    let isSavedAsNew: Bool
}

/// Standalone raster export formats (never trigger memory timeline registration).
nonisolated enum PhotoExportFormat: String, CaseIterable, Sendable {
    case png
    case jpeg

    var contentType: UTType {
        switch self {
        case .png: .png
        case .jpeg: .jpeg
        }
    }

    var fileExtension: String {
        switch self {
        case .png: "png"
        case .jpeg: "jpg"
        }
    }
}

/// Canonical content digest of a photo document used to detect substantive visual/structural edits.
nonisolated struct PhotoContentFingerprint: Equatable, Hashable, Sendable {
    let hex: String

    private static let canonicalDocumentID = UUID(uuidString: "00000000-0000-0000-0000-000000000000")!

    /// Computes a deterministic SHA-256 fingerprint independent of project UUID, active layer selection, and row padding.
    static func compute(for snapshot: ProjectSnapshot) -> PhotoContentFingerprint {
        var hasher = SHA256()
        let manifest = snapshot.manifest
        let canonical = ProjectManifest(
            format: manifest.format,
            version: manifest.version,
            colorSpace: manifest.colorSpace,
            resolution: manifest.resolution,
            documentID: canonicalDocumentID,
            width: manifest.width,
            height: manifest.height,
            activeLayerID: nil,
            layers: manifest.layers,
            guides: manifest.guides
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        if let manifestBytes = try? encoder.encode(canonical) {
            hasher.update(data: manifestBytes)
        }
        for layer in manifest.layers {
            hasher.update(data: Data(layer.id.uuidString.utf8))
            if let image = snapshot.images[layer.id]?.image {
                update(&hasher, with: image, tag: 1)
            }
            if let mask = snapshot.masks[layer.id]?.image {
                update(&hasher, with: mask, tag: 2)
            }
        }
        let digest = hasher.finalize()
        return PhotoContentFingerprint(hex: digest.map { String(format: "%02x", $0) }.joined())
    }

    private static func update(_ hasher: inout SHA256, with image: CGImage, tag: UInt8) {
        var header: [UInt64] = [
            UInt64(tag),
            UInt64(image.width),
            UInt64(image.height),
            UInt64(image.bitsPerComponent),
            UInt64(image.bitsPerPixel),
        ]
        header.withUnsafeBytes { hasher.update(bufferPointer: $0) }
        guard let providerData = image.dataProvider?.data as Data? else { return }
        let activeRowBytes = (image.width * image.bitsPerPixel + 7) / 8
        let stride = image.bytesPerRow
        guard activeRowBytes > 0, stride >= activeRowBytes else {
            hasher.update(data: providerData)
            return
        }
        if stride == activeRowBytes {
            let expected = activeRowBytes * image.height
            hasher.update(data: providerData.prefix(expected))
            return
        }
        providerData.withUnsafeBytes { raw in
            guard let base = raw.baseAddress else { return }
            let total = raw.count
            for row in 0..<image.height {
                let offset = row * stride
                guard offset + activeRowBytes <= total else { break }
                hasher.update(bufferPointer: UnsafeRawBufferPointer(start: base.advanced(by: offset), count: activeRowBytes))
            }
        }
    }
}

/// Sidecar metadata stored beside an auto-saved photo draft so recovery preserves save-diff semantics.
nonisolated struct PhotoDraftMetadata: Codable, Equatable, Sendable {
    static let currentSchemaVersion = 1

    let schemaVersion: Int
    let projectID: ProjectID
    let projectURLPath: String?
    let sourceImageURLPath: String?
    let displayName: String
    let initialFingerprintHex: String?
    let lastSavedFingerprintHex: String?
    let hasSavedSubstantiveEdit: Bool
    let updatedAt: Date
}

/// Decoded latest valid photo draft returned on relaunch recovery.
nonisolated struct RestoredPhotoDraft: @unchecked Sendable {
    let snapshot: ProjectSnapshot
    let metadata: PhotoDraftMetadata
}

/// Stores auto-saved photo drafts atomically with a fallback backup slot so corrupt writes never lose the latest valid draft.
actor PhotoDraftRecoveryStore {
    private let directory: URL

    init(directory: URL) {
        self.directory = directory
    }

    /// Writes a staged draft and promotes it atomically; the previous valid draft moves to backup.
    func save(snapshot: ProjectSnapshot, metadata: PhotoDraftMetadata) async throws {
        let fm = FileManager.default
        try fm.createDirectory(at: directory, withIntermediateDirectories: true)
        let staging = directory.appendingPathComponent(".staging-\(UUID().uuidString)", isDirectory: true)
        try fm.createDirectory(at: staging, withIntermediateDirectories: false)
        defer { try? fm.removeItem(at: staging) }

        let packageURL = staging.appendingPathComponent("draft.comp", isDirectory: true)
        try await ProjectStore.shared.save(snapshot, to: packageURL)
        let metadataURL = staging.appendingPathComponent("metadata.json")
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(metadata).write(to: metadataURL, options: .atomic)

        let latest = directory.appendingPathComponent("latest", isDirectory: true)
        let backup = directory.appendingPathComponent("backup", isDirectory: true)
        if fm.fileExists(atPath: latest.path) {
            if fm.fileExists(atPath: backup.path) {
                try? fm.removeItem(at: backup)
            }
            try? fm.moveItem(at: latest, to: backup)
        }
        try fm.moveItem(at: staging, to: latest)
    }

    /// Restores the latest valid draft, falling back to the backup slot if `latest` is missing or damaged.
    func loadLatestValid() async -> RestoredPhotoDraft? {
        let latest = directory.appendingPathComponent("latest", isDirectory: true)
        if let draft = await loadSlot(latest) {
            return draft
        }
        let backup = directory.appendingPathComponent("backup", isDirectory: true)
        return await loadSlot(backup)
    }

    /// Removes stored draft slots.
    func clear() throws {
        let fm = FileManager.default
        for name in ["latest", "backup"] {
            let slot = directory.appendingPathComponent(name, isDirectory: true)
            if fm.fileExists(atPath: slot.path) {
                try fm.removeItem(at: slot)
            }
        }
    }

    private func loadSlot(_ slot: URL) async -> RestoredPhotoDraft? {
        let metadataURL = slot.appendingPathComponent("metadata.json")
        let packageURL = slot.appendingPathComponent("draft.comp", isDirectory: true)
        guard FileManager.default.fileExists(atPath: metadataURL.path),
              FileManager.default.fileExists(atPath: packageURL.path) else {
            return nil
        }
        do {
            let metadata = try JSONDecoder().decode(PhotoDraftMetadata.self, from: Data(contentsOf: metadataURL))
            guard metadata.schemaVersion == PhotoDraftMetadata.currentSchemaVersion else { return nil }
            let snapshot = try await ProjectStore.shared.load(from: packageURL)
            return RestoredPhotoDraft(snapshot: snapshot, metadata: metadata)
        } catch {
            return nil
        }
    }
}
