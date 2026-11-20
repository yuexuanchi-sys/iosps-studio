import AppKit
import CryptoKit
import ImageIO
import Testing
import UniformTypeIdentifiers
@testable import IOSPSCompositorPrototype

@MainActor
struct PrototypeEditorTests {
    @Test
    func cropRotateUndoReopenAndExportPreserveSource() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: false)
        defer { try? FileManager.default.removeItem(at: directory) }
        let original = directory.appendingPathComponent("sample.png")
        let fixture = try makeImage()
        let destination = try #require(CGImageDestinationCreateWithURL(original as CFURL, UTType.png.identifier as CFString, 1, nil))
        CGImageDestinationAddImage(destination, fixture, nil)
        try #require(CGImageDestinationFinalize(destination))
        let fingerprint = SHA256.hash(data: try Data(contentsOf: original))

        let session = EditorSession()
        await session.importImages([original])
        #expect(session.document?.size == CGSize(width: 64, height: 48))
        session.selectTool(.crop)
        session.cropRect = CropGeometry.create(from: .zero, to: CGPoint(x: 32, y: 16), ratio: 2)
        await session.commitCrop()
        #expect(session.document?.size == CGSize(width: 32, height: 16))
        session.rotateCanvas(clockwise: true)
        #expect(session.document?.size == CGSize(width: 16, height: 32))
        session.undo()
        #expect(session.document?.size == CGSize(width: 32, height: 16))
        session.redo()
        #expect(session.document?.size == CGSize(width: 16, height: 32))

        let edited = try #require(session.projectSnapshot())
        let project = directory.appendingPathComponent("sample.comp", isDirectory: true)
        try await ProjectStore.shared.save(edited, to: project)
        let reopened = try await ProjectStore.shared.load(from: project)
        #expect(reopened.manifest.documentID == edited.manifest.documentID)
        let png = try await ImageExporter.shared.pngData(reopened)
        let raster = try await ImageExporter.shared.render(reopened)
        let jpeg = try await ImageExporter.shared.jpeg(raster, options: JPEGOptions())
        let pngImage = try decode(png)
        let jpegImage = try decode(jpeg.data)
        for image in [pngImage, jpegImage] {
            #expect(image.width == 16 && image.height == 32)
            #expect(image.colorSpace?.name == CGColorSpace.sRGB)
        }
        #expect(pngImage.alphaInfo != .none && pngImage.alphaInfo != .noneSkipFirst && pngImage.alphaInfo != .noneSkipLast)
        #expect(jpegImage.alphaInfo == .none || jpegImage.alphaInfo == .noneSkipFirst || jpegImage.alphaInfo == .noneSkipLast)
        let originalAfterEditing = try Data(contentsOf: original)
        #expect(SHA256.hash(data: originalAfterEditing) == fingerprint)
    }

    @Test
    func exposureAndSaturationChangeSyntheticPixels() throws {
        let fixture = try makeImage()
        let exposed = try ExposureSettings(exposure: 1).apply(fixture)
        let settings = HueSaturationSettings(saturation: -100)
        let job = HueSaturationJob(image: fixture, settings: settings, selection: nil,
                                   pixelToDocument: .identity, thumbnail: false)
        let desaturated = try HueSaturationFilter.run(job).image
        let original = try pixelBytes(fixture)
        let brighter = try pixelBytes(exposed)
        let muted = try pixelBytes(desaturated)
        #expect(brighter != original)
        #expect(muted != original)
        #expect(exposed.width == fixture.width && desaturated.height == fixture.height)
    }

    @Test
    func jpegImportAppliesSourceOrientation() async throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".jpg")
        defer { try? FileManager.default.removeItem(at: url) }
        let fixture = try makeImage()
        let destination = try #require(CGImageDestinationCreateWithURL(url as CFURL, UTType.jpeg.identifier as CFString, 1, nil))
        let orientation = [kCGImagePropertyOrientation: CGImagePropertyOrientation.right.rawValue] as CFDictionary
        CGImageDestinationAddImage(destination, fixture, orientation)
        try #require(CGImageDestinationFinalize(destination))

        let imported = try await ImageImporter.shared.decode(url)
        #expect(imported.image.width == fixture.height)
        #expect(imported.image.height == fixture.width)
    }

    private func makeImage() throws -> CGImage {
        let space = try #require(CGColorSpace(name: CGColorSpace.sRGB))
        let bitmap = try #require(CGContext(data: nil, width: 64, height: 48, bitsPerComponent: 8, bytesPerRow: 0,
                                            space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        bitmap.clear(CGRect(x: 0, y: 0, width: 64, height: 48))
        bitmap.setFillColor(CGColor(red: 0.6, green: 0.3, blue: 0.1, alpha: 1))
        bitmap.fill(CGRect(x: 4, y: 4, width: 56, height: 40))
        return try #require(bitmap.makeImage())
    }

    private func decode(_ data: Data) throws -> CGImage {
        let source = try #require(CGImageSourceCreateWithData(data as CFData, nil))
        return try #require(CGImageSourceCreateImageAtIndex(source, 0, nil))
    }

    private func pixelBytes(_ image: CGImage) throws -> Data {
        try #require(image.dataProvider?.data) as Data
    }
}
