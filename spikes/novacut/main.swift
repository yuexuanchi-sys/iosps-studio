import AVFoundation
import CoreGraphics
import CoreVideo
import Foundation
import ImageIO
import UniformTypeIdentifiers

struct SpikeFailure: LocalizedError {
    let description: String
    var errorDescription: String? { description }
}

func check(_ condition: Bool, _ description: String) throws {
    guard condition else { throw SpikeFailure(description: description) }
}

enum FrameColor: String {
    case red, green, blue, yellow

    var channels: (red: UInt8, green: UInt8, blue: UInt8) {
        switch self {
        case .red: (230, 15, 15)
        case .green: (15, 220, 15)
        case .blue: (15, 15, 230)
        case .yellow: (225, 215, 15)
        }
    }
}

let output = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
let timebase = Timebase.p30
let sourceA = output.appendingPathComponent("source-a.mov")
let sourceB = output.appendingPathComponent("source-b.mp4")
try await makeSource(at: sourceA, type: .mov, first: .red, second: .blue, frequency: 440)
try await makeSource(at: sourceB, type: .mp4, first: .yellow, second: .green, frequency: 660)
let a = try await MedioResuelto.cargar(id: UUID(), url: sourceA)
let b = try await MedioResuelto.cargar(id: UUID(), url: sourceB)
try check([a, b].allSatisfy { $0.tieneVideo && $0.tieneAudio && abs($0.duracion.seconds - 2) < 0.034 },
          "Both sources must import with two seconds of video and audio")

var timeline = LineaDeTiempo.nueva(timebase: timebase)
guard let video = timeline.pistas.first(where: { $0.tipo == .video })?.id,
      let audio = timeline.pistas.first(where: { $0.tipo == .audio })?.id else {
    throw SpikeFailure(description: "Missing default video/audio tracks")
}
let clipA = Clip(mediaID: a.id, nombre: "A", inicio: 0, duracion: 60, entradaEnOrigen: 0)
let clipB = Clip(mediaID: b.id, nombre: "B", inicio: 60, duracion: 60, entradaEnOrigen: 0)
timeline.sobrescribir(clipA, enPista: video, en: 0)
timeline.sobrescribir(clipB, enPista: video, en: 60)
let trimA = timeline.recortar(clipA.id, borde: .salida, delta: -30, modo: .normal, duracionDelMedio: 60)
let trimB = timeline.recortar(clipB.id, borde: .entrada, delta: 30, modo: .normal, duracionDelMedio: 60)
try check(trimA == -30 && trimB == 30, "Both clips must be trimmed by 30 frames")
timeline.mover(clipA.id, aPista: video, en: 30)
timeline.mover(clipB.id, aPista: video, en: 0)
let clips = timeline.pistas.first(where: { $0.id == video })?.clips ?? []
try check(clips.map(\.id) == [clipB.id, clipA.id] &&
          clips.map(\.inicio) == [0, 30] && clips.map(\.entradaEnOrigen) == [30, 0] &&
          clips.map(\.duracion) == [30, 30], "Expected B[30–60) then A[0–30) without a gap")
for clip in clips {
    timeline.sobrescribir(
        Clip(mediaID: clip.mediaID, nombre: clip.nombre, inicio: clip.inicio,
             duracion: clip.duracion, entradaEnOrigen: clip.entradaEnOrigen),
        enPista: audio, en: clip.inicio
    )
}

let projectURL = output.appendingPathComponent("project.editorcito")
let project = ProyectoEditorcito(version: 2, nombre: "Synthetic B then A", medios: [(a, sourceA), (b, sourceB)].map {
    media, url in
    ProyectoEditorcito.MedioGuardado(
        id: media.id, ruta: url.path, rutaRelativa: url.lastPathComponent,
        duracion: media.duracion.seconds, ancho: media.tamanoVisible.width, alto: media.tamanoVisible.height,
        bytes: nil, fps: media.fps, vfr: false, nombre: url.lastPathComponent, bin: nil, subclip: nil
    )
}, montaje: timeline)
let encoder = JSONEncoder()
encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
try encoder.encode(project).write(to: projectURL, options: .atomic)
let reopened = try ProyectoEditorcito.leer(Data(contentsOf: projectURL))
try check(reopened.montaje == timeline, "Saving and reopening must preserve the edit")
var media: [UUID: MedioResuelto] = [:]
for reference in reopened.medios {
    guard let url = reopened.localizar(reference, carpetaDelProyecto: output) else {
        throw SpikeFailure(description: "The saved project must resolve its two source files")
    }
    media[reference.id] = try await MedioResuelto.cargar(id: reference.id, url: url)
}

let render = ConstructorDeMontaje.construir(reopened.montaje, medios: media)
try check(!render.estaVacio && !render.avisos.contains(where: \.critico), "Composition must render without critical errors")
let playerItem = AVPlayerItem(asset: render.composicion)
playerItem.videoComposition = render.composicionDeVideo
playerItem.audioMix = render.mezclaDeAudio
let preview = AVAssetImageGenerator(asset: playerItem.asset)
preview.videoComposition = playerItem.videoComposition
try await verifyFrames(preview, pngPrefix: "preview")
print("Preview after reopening: B green through frame 29, A red from frame 30")

let edited = output.appendingPathComponent("edited.mp4")
let staging = EscrituraAtomica.temporal(para: edited)
let preset = PresetExportacion.mp4
guard let session = AVAssetExportSession(asset: render.composicion, presetName: preset.presetAV) else {
    throw EditorError.exportUnavailable
}
session.videoComposition = render.composicionDeVideo
session.audioMix = render.mezclaDeAudio
try await export(session, to: staging, type: preset.tipoDeArchivo)
try EscrituraAtomica.instalar(staging, en: edited)

let exportedAsset = AVURLAsset(url: edited)
let duration = try await exportedAsset.load(.duration).seconds
let exportedAudio = try await exportedAsset.loadTracks(withMediaType: .audio)
let exportedVideo = try await exportedAsset.loadTracks(withMediaType: .video)
try check(abs(duration - 2) <= 1.0 / 30 && exportedAudio.count == 1 && exportedVideo.count == 1,
          "Expected two seconds, one video track and one audio track in exported MP4")
try await verifyFrames(AVAssetImageGenerator(asset: exportedAsset), pngPrefix: "export")
print("Offline MP4: \(duration)s, \(exportedVideo.count) video track, \(exportedAudio.count) audio track, exact cut at frame 30")

@MainActor
func export(_ session: AVAssetExportSession, to url: URL, type: AVFileType) async throws {
    if #available(macOS 15.0, *) {
        try await session.export(to: url, as: type)
    } else {
        session.outputURL = url
        session.outputFileType = type
        await session.export()
        if session.status != .completed {
            throw session.error ?? EditorError.exportFailed
        }
    }
}

@MainActor
func verifyFrames(_ generator: AVAssetImageGenerator, pngPrefix: String) async throws {
    generator.requestedTimeToleranceBefore = .zero
    generator.requestedTimeToleranceAfter = .zero
    for (frame, expected) in [(15, FrameColor.green), (29, .green), (30, .red), (45, .red)] {
        let image = try await generator.image(at: CMTime(value: CMTimeValue(frame), timescale: 30)).image
        guard let context = CGContext(
            data: nil, width: 1, height: 1, bitsPerComponent: 8, bytesPerRow: 4,
            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
        ), let pixel = context.data?.assumingMemoryBound(to: UInt8.self) else {
            throw SpikeFailure(description: "Cannot read frame sample")
        }
        context.draw(image, in: CGRect(x: 0, y: 0, width: 1, height: 1))
        let actual = (pixel[0], pixel[1], pixel[2])
        let correct = expected == .green
            ? actual.1 > 120 && actual.0 < 80 && actual.2 < 80
            : actual.0 > 120 && actual.1 < 80 && actual.2 < 80
        try check(correct, "\(pngPrefix) frame \(frame) expected \(expected), got \(actual)")
        if frame == 29 || frame == 30 {
            let url = output.appendingPathComponent("\(pngPrefix)-frame-\(frame).png")
            guard let png = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil) else {
                throw SpikeFailure(description: "Cannot create evidence PNG")
            }
            CGImageDestinationAddImage(png, image, nil)
            try check(CGImageDestinationFinalize(png), "Cannot write evidence PNG")
        }
    }
}

@MainActor
func makeSource(at url: URL, type: AVFileType, first: FrameColor, second: FrameColor, frequency: Double) async throws {
    let scratch = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    try FileManager.default.createDirectory(at: scratch, withIntermediateDirectories: false)
    defer { try? FileManager.default.removeItem(at: scratch) }
    let silent = scratch.appendingPathComponent("silent.mov")
    let wave = scratch.appendingPathComponent("tone.wav")
    try await makeVideo(at: silent, first: first, second: second)
    try makeAudio(at: wave, frequency: frequency)
    let composition = AVMutableComposition()
    let range = CMTimeRange(start: .zero, duration: CMTime(value: 2, timescale: 1))
    for (source, kind) in [(silent, AVMediaType.video), (wave, .audio)] {
        let asset = AVURLAsset(url: source)
        guard let track = try await asset.loadTracks(withMediaType: kind).first,
              let destination = composition.addMutableTrack(withMediaType: kind, preferredTrackID: kCMPersistentTrackID_Invalid) else {
            throw SpikeFailure(description: "Cannot load synthetic source track")
        }
        try destination.insertTimeRange(range, of: track, at: .zero)
    }
    guard let mux = AVAssetExportSession(asset: composition, presetName: AVAssetExportPresetHighestQuality) else {
        throw EditorError.exportUnavailable
    }
    try await export(mux, to: url, type: type)
}

@MainActor
func makeVideo(at url: URL, first: FrameColor, second: FrameColor) async throws {
    let width = 160
    let height = 96
    let writer = try AVAssetWriter(outputURL: url, fileType: .mov)
    let video = AVAssetWriterInput(mediaType: .video, outputSettings: [
        AVVideoCodecKey: AVVideoCodecType.h264,
        AVVideoWidthKey: width,
        AVVideoHeightKey: height,
    ])
    let pixels = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: video, sourcePixelBufferAttributes: [
        kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
        kCVPixelBufferWidthKey as String: width,
        kCVPixelBufferHeightKey as String: height,
    ])
    try check(writer.canAdd(video), "Cannot add synthetic video encoder")
    writer.add(video)
    try check(writer.startWriting(), "Cannot start synthetic video encoder")
    writer.startSession(atSourceTime: .zero)
    guard let pool = pixels.pixelBufferPool else {
        throw SpikeFailure(description: "Cannot allocate video pixels")
    }
    let deadline = ContinuousClock.now.advanced(by: .seconds(15))
    for frame in 0..<60 {
        while !video.isReadyForMoreMediaData {
            try check(writer.status == .writing && ContinuousClock.now < deadline, "Synthetic video encoder timed out")
            try await Task.sleep(for: .milliseconds(5))
        }
        var storage: CVPixelBuffer?
        let status = CVPixelBufferPoolCreatePixelBuffer(nil, pool, &storage)
        guard status == kCVReturnSuccess, let buffer = storage else {
            throw SpikeFailure(description: "Cannot allocate synthetic video frame")
        }
        try fill(buffer, color: frame < 30 ? first : second)
        try check(pixels.append(buffer, withPresentationTime: CMTime(value: CMTimeValue(frame), timescale: 30)),
                  "Cannot append synthetic video frame")
    }
    writer.endSession(atSourceTime: CMTime(value: 60, timescale: 30))
    video.markAsFinished()
    await writer.finishWriting()
    try check(writer.status == .completed, "Synthetic video did not finish: \(String(describing: writer.error))")
}

func fill(_ buffer: CVPixelBuffer, color: FrameColor) throws {
    try check(CVPixelBufferLockBaseAddress(buffer, []) == kCVReturnSuccess, "Cannot lock video pixels")
    defer { CVPixelBufferUnlockBaseAddress(buffer, []) }
    guard let base = CVPixelBufferGetBaseAddress(buffer) else { throw SpikeFailure(description: "Missing pixel storage") }
    let stride = CVPixelBufferGetBytesPerRow(buffer)
    let pointer = base.assumingMemoryBound(to: UInt8.self)
    let channels = color.channels
    for row in 0..<CVPixelBufferGetHeight(buffer) {
        for column in 0..<CVPixelBufferGetWidth(buffer) {
            let offset = row * stride + column * 4
            pointer[offset] = channels.blue
            pointer[offset + 1] = channels.green
            pointer[offset + 2] = channels.red
            pointer[offset + 3] = 255
        }
    }
}

func makeAudio(at url: URL, frequency: Double) throws {
    let rate = 48_000.0
    let frames = AVAudioFrameCount(rate * 2)
    guard let format = AVAudioFormat(standardFormatWithSampleRate: rate, channels: 1),
          let samples = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames),
          let channel = samples.floatChannelData?.pointee else {
        throw SpikeFailure(description: "Cannot allocate synthetic audio")
    }
    samples.frameLength = frames
    for frame in 0..<Int(frames) {
        channel[frame] = Float(0.2 * sin(2 * .pi * frequency * Double(frame) / rate))
    }
    let file = try AVAudioFile(forWriting: url, settings: format.settings)
    try file.write(from: samples)
}
