import AVFoundation
import BirthdayCore
import Foundation
import TimelineKit

public enum VideoMontageError: Error {
    case unreadableSource
    case variableFrameRate
    case invalidRange
    case emptyTimeline
    case compositionFailed
    case exportUnavailable
    case exportFailed
    case invalidDestination
}

/// Keeps the resolved native asset with its original source frame limit.
@MainActor
public struct VideoSource {
    fileprivate let source: MedioResuelto
    public let frameCount: Int

    public static func load(id: MediaID, from url: URL) async throws -> Self {
        guard url.isFileURL else { throw VideoMontageError.unreadableSource }
        let source = try await MedioResuelto.cargar(id: id.rawValue, url: url)
        let frames = source.duracion.seconds * Double(VideoTiming.framesPerSecond)
        guard source.tieneVideo, frames.isFinite, frames >= 1, frames < Double(Int.max) else {
            throw VideoMontageError.unreadableSource
        }
        guard !source.esVFR else { throw VideoMontageError.variableFrameRate }
        return Self(source: source, frameCount: Int(frames.rounded(.down)))
    }
}

/// Uses one native composition for playback and file export.
@MainActor
public final class VideoMontage {
    private let render: MontajeRenderizable
    private var activeExport: AVAssetExportSession?

    public init(timeline: Timeline, sources: [MediaID: VideoSource]) throws {
        guard !timeline.clips.isEmpty else { throw VideoMontageError.emptyTimeline }
        guard timeline.overlaps.allSatisfy({ $0 == 0 }) else { throw VideoMontageError.invalidRange }
        var composition = LineaDeTiempo.nueva(timebase: .p30)
        guard let video = composition.pistas.first(where: { $0.tipo == .video })?.id,
              let audio = composition.pistas.first(where: { $0.tipo == .audio })?.id else {
            throw VideoMontageError.compositionFailed
        }
        var resolved: [UUID: MedioResuelto] = [:]
        for (clip, position) in zip(timeline.clips, timeline.clipStartFrames) {
            guard let source = sources[clip.media],
                  clip.startFrame + clip.frameCount <= source.frameCount else {
                throw VideoMontageError.invalidRange
            }
            let id = clip.media.rawValue
            resolved[id] = source.source
            let name = source.source.url.lastPathComponent
            composition.sobrescribir(
                Clip(mediaID: id, nombre: name, inicio: position, duracion: clip.frameCount, entradaEnOrigen: clip.startFrame),
                enPista: video, en: position
            )
            if source.source.tieneAudio {
                composition.sobrescribir(
                    Clip(mediaID: id, nombre: name, inicio: position, duracion: clip.frameCount, entradaEnOrigen: clip.startFrame),
                    enPista: audio, en: position
                )
            }
        }
        let built = ConstructorDeMontaje.construir(composition, medios: resolved)
        guard !built.estaVacio, !built.avisos.contains(where: \.critico) else {
            throw VideoMontageError.compositionFailed
        }
        render = built
    }

    public func makePlayerItem() -> AVPlayerItem {
        let item = AVPlayerItem(asset: render.composicion)
        item.videoComposition = render.composicionDeVideo
        item.audioMix = render.mezclaDeAudio
        return item
    }

    /// Publishes a temporary MP4 only after the encoder completes.
    public func export(to destination: URL, progress: @escaping @MainActor (Double) -> Void) async throws {
        guard destination.isFileURL, !destination.hasDirectoryPath else { throw VideoMontageError.invalidDestination }
        let hasScope = destination.startAccessingSecurityScopedResource()
        defer { if hasScope { destination.stopAccessingSecurityScopedResource() } }
        let attributes = try? destination.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey])
        if let attributes, attributes.isRegularFile == false || attributes.isSymbolicLink == true {
            throw VideoMontageError.invalidDestination
        }
        let preset = PresetExportacion.mp4
        guard activeExport == nil,
              let session = AVAssetExportSession(asset: render.composicion, presetName: preset.presetAV) else {
            throw VideoMontageError.exportUnavailable
        }
        let staging = EscrituraAtomica.temporal(para: destination)
        activeExport = session
        session.videoComposition = render.composicionDeVideo
        session.audioMix = render.mezclaDeAudio
        progress(0)
        let observer = Task { @MainActor in
            while !Task.isCancelled {
                progress(Double(session.progress))
                try await Task.sleep(for: .milliseconds(100))
            }
        }
        defer {
            observer.cancel()
            activeExport = nil
            try? FileManager.default.removeItem(at: staging)
        }
        try Task.checkCancellation()
        if #available(macOS 15.0, *) {
            try await session.export(to: staging, as: preset.tipoDeArchivo)
        } else {
            session.outputURL = staging
            session.outputFileType = preset.tipoDeArchivo
            await session.export()
            if session.status != .completed {
                throw session.error ?? VideoMontageError.exportFailed
            }
        }
        try Task.checkCancellation()
        try EscrituraAtomica.instalar(staging, en: destination)
        progress(1)
    }

    public func cancelExport() {
        activeExport?.cancelExport()
    }
}
