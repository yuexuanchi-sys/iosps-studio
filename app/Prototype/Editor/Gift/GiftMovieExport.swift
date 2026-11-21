import BirthdayCore
import Foundation
import MediaIO
import TemplateKit
import TimelineKit

nonisolated enum GiftMovieExport {
    static func applicationLibrary() throws -> MediaLibrary {
        let support = try FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask,
                                                  appropriateFor: nil, create: true)
        let root = support.appendingPathComponent("IOSPSCompositorPrototype", isDirectory: true)
        return MediaLibrary(directory: root.appendingPathComponent("MovieMedia", isDirectory: true))
    }

    /// Publishes the editor's original-pixel PNG and resolves the template's clip through its MediaID.
    static func render(_ snapshot: ProjectSnapshot, library: MediaLibrary, to destination: URL) async throws -> MediaID {
        guard let url = Bundle.main.url(forResource: "memory-still", withExtension: "json") else {
            throw PrototypeMovieError.missingTemplate
        }
        let template = try JSONDecoder().decode(MemoryTemplate.self, from: Data(contentsOf: url))
        guard template.scenes.count == 1, let scene = template.scene(at: 0),
              scene.motion == .still, scene.transitionFrames == 0, scene.caption == nil,
              scene.filterID == nil, template.music == nil else {
            throw PrototypeMovieError.unsupportedTimeline
        }
        let temporaryPhoto = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".png")
        defer { try? FileManager.default.removeItem(at: temporaryPhoto) }
        try await ImageExporter.shared.exportPNG(snapshot, to: temporaryPhoto)
        guard let imported = await library.importFiles([temporaryPhoto]).first else { throw PrototypeMovieError.missingPhoto }
        let media = try imported.get()
        let clip = try TimelineClip(media: media.id, startFrame: 0, frameCount: scene.frames)
        let timeline = try Timeline(clips: [clip], overlaps: [])
        guard let resolved = try await library.load(id: clip.media), resolved.kind == .photo else {
            throw PrototypeMovieError.missingPhoto
        }
        try await PrototypeMovieRenderer.write(photo: resolved.sourceURL, timeline: timeline, to: destination)
        return clip.media
    }
}
