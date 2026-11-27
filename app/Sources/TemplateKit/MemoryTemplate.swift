import BirthdayCore
import Foundation

/// Describes motion in renderer-independent terms.
public enum PhotoMotion: String, Equatable, Decodable, Sendable {
    case still, zoomIn, zoomOut, panLeft, panRight
}

/// Defines one repeatable template slot for selected media.
public struct TemplateScene: Equatable, Decodable, Sendable {
    public let frames: Int
    public let transitionFrames: Int
    public let motion: PhotoMotion
    public let caption: String?
    public let filterID: String?

    private enum CodingKeys: String, CodingKey {
        case frames, transitionFrames, motion, caption, filterID
    }

    /// Keeps scene lengths and outgoing transitions on the shared frame grid.
    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        frames = try container.decode(Int.self, forKey: .frames)
        transitionFrames = try container.decode(Int.self, forKey: .transitionFrames)
        motion = try container.decode(PhotoMotion.self, forKey: .motion)
        caption = try container.decodeIfPresent(String.self, forKey: .caption)
        filterID = try container.decodeIfPresent(String.self, forKey: .filterID)
        guard (1...VideoTiming.maxOutputFrames).contains(frames) else {
            throw DecodingError.dataCorruptedError(forKey: .frames, in: container, debugDescription: "Invalid scene duration")
        }
        guard (0..<frames).contains(transitionFrames) else {
            throw DecodingError.dataCorruptedError(forKey: .transitionFrames, in: container, debugDescription: "Invalid scene transition")
        }
    }

    internal init(
        frames: Int,
        transitionFrames: Int,
        motion: PhotoMotion,
        caption: String?,
        filterID: String?
    ) {
        self.frames = frames
        self.transitionFrames = transitionFrames
        self.motion = motion
        self.caption = caption
        self.filterID = filterID
    }
}

/// References a licensed audio asset and an excerpt on the video frame grid.
public struct TemplateMusic: Equatable, Decodable, Sendable {
    public let assetID: String
    public let startFrame: Int
    public let frames: Int

    private enum CodingKeys: String, CodingKey {
        case assetID, startFrame, frames
    }

    /// Rejects ranges that cannot be translated to a valid media request.
    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        assetID = try container.decode(String.self, forKey: .assetID)
        startFrame = try container.decode(Int.self, forKey: .startFrame)
        frames = try container.decode(Int.self, forKey: .frames)
        guard !assetID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw DecodingError.dataCorruptedError(forKey: .assetID, in: container, debugDescription: "Empty music asset ID")
        }
        guard (1...VideoTiming.maxOutputFrames).contains(frames),
              (0...(Int.max - frames)).contains(startFrame) else {
            throw DecodingError.dataCorruptedError(forKey: .frames, in: container, debugDescription: "Invalid music excerpt")
        }
    }
}

/// Loads a repeatable style independently of the input media count.
public struct MemoryTemplate: Equatable, Decodable, Sendable {
    public let id: String
    public let name: String
    public let scenes: [TemplateScene]
    public let music: TemplateMusic?

    private enum CodingKeys: String, CodingKey {
        case formatVersion, id, name, scenes, music
    }

    /// Rejects layouts that would produce three simultaneous scenes.
    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        guard try container.decode(Int.self, forKey: .formatVersion) == 1 else {
            throw DecodingError.dataCorruptedError(forKey: .formatVersion, in: container, debugDescription: "Unsupported template version")
        }
        id = try container.decode(String.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        let scenes = try container.decode([TemplateScene].self, forKey: .scenes)
        music = try container.decodeIfPresent(TemplateMusic.self, forKey: .music)
        guard !id.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw DecodingError.dataCorruptedError(forKey: .name, in: container, debugDescription: "Template requires an ID and name")
        }
        guard let last = scenes.last else {
            throw DecodingError.dataCorruptedError(forKey: .scenes, in: container, debugDescription: "Template requires scenes")
        }
        var incoming = last.transitionFrames
        for scene in scenes {
            guard incoming < scene.frames, incoming + scene.transitionFrames <= scene.frames else {
                throw DecodingError.dataCorruptedError(forKey: .scenes, in: container, debugDescription: "Scene overlap exceeds its duration")
            }
            incoming = scene.transitionFrames
        }
        self.scenes = scenes
    }

    /// Repeats the scene pattern as additional input media are selected.
    public func scene(at index: Int) -> TemplateScene? {
        guard index >= 0 else { return nil }
        return scenes[index % scenes.count]
    }

    /// Returns a copy whose first scene uses a custom non-empty opening caption while preserving timing invariants.
    public func withOpeningCaption(_ caption: String?) -> MemoryTemplate {
        guard let trimmed = caption?.trimmingCharacters(in: .whitespacesAndNewlines),
              !trimmed.isEmpty,
              let first = scenes.first else {
            return self
        }
        var updated = scenes
        updated[0] = TemplateScene(
            frames: first.frames,
            transitionFrames: first.transitionFrames,
            motion: first.motion,
            caption: trimmed,
            filterID: first.filterID
        )
        return MemoryTemplate(id: id, name: name, scenes: updated, music: music)
    }

    private init(id: String, name: String, scenes: [TemplateScene], music: TemplateMusic?) {
        self.id = id
        self.name = name
        self.scenes = scenes
        self.music = music
    }
}
