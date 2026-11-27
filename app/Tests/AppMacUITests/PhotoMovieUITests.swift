import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers
import XCTest

final class PhotoMovieUITests: XCTestCase {
    @MainActor
    func testToolbarEntryImportReorderSwitchTemplatePreviewAndExport() throws {
        continueAfterFailure = false
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let inputs = root.appendingPathComponent("Inputs")
        let outputs = root.appendingPathComponent("Outputs")
        try FileManager.default.createDirectory(at: inputs, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: outputs, withIntermediateDirectories: false)
        defer { try? FileManager.default.removeItem(at: root) }

        let photoA = inputs.appendingPathComponent("photo-a.jpg")
        let photoB = inputs.appendingPathComponent("photo-b.jpg")
        let corrupt = inputs.appendingPathComponent("corrupt.jpg")
        let soundtrack = inputs.appendingPathComponent("soundtrack.wav")
        try writePhoto(to: photoA, background: (0.82, 0.14, 0.16), stripe: (0.14, 0.72, 0.25))
        try writePhoto(to: photoB, background: (0.12, 0.24, 0.82), stripe: (0.92, 0.78, 0.14))
        try Data("Synthetic unreadable photo".utf8).write(to: corrupt)
        try writeStereoWave(to: soundtrack, frequency: 520, seconds: 3.0)
        let originalBytes = try [photoA, photoB, soundtrack].map { try Data(contentsOf: $0) }

        let app = XCUIApplication()
        app.launchEnvironment["IOSPS_TEST_VIDEO_DIRECTORY"] = root.appendingPathComponent("Local").path
        app.launch()
        defer {
            if app.state != .notRunning {
                app.terminate()
            }
        }

        openPhotoMovie(in: app)
        let firstPhoto = app.buttons["photo-movie-photo-0"]
        let secondPhoto = app.buttons["photo-movie-photo-1"]
        let exportButton = app.buttons["photo-movie-export"]
        XCTAssertFalse(exportButton.isEnabled)

        // Cancel picker before adding any photo keeps empty state intact.
        app.buttons["photo-movie-add-photos"].click()
        let picker = app.sheets["open-panel"]
        XCTAssertTrue(picker.waitForExistence(timeout: 15))
        app.typeKey(.escape, modifierFlags: [])
        XCTAssertTrue(picker.waitForNonExistence(timeout: 15))
        XCTAssertFalse(firstPhoto.exists)

        // Import valid photos and one unreadable photo; verify cancellation afterwards preserves list.
        app.buttons["photo-movie-add-photos"].click()
        choose(photoA, in: app)
        XCTAssertTrue(firstPhoto.waitForExistence(timeout: 15))
        app.buttons["photo-movie-add-photos"].click()
        choose(photoB, in: app)
        XCTAssertTrue(secondPhoto.waitForExistence(timeout: 15))
        app.buttons["photo-movie-add-photos"].click()
        choose(corrupt, in: app)
        let issue = app.staticTexts.matching(NSPredicate(
            format: "label CONTAINS %@ OR value CONTAINS %@", "corrupt.jpg", "corrupt.jpg"
        )).firstMatch
        XCTAssertTrue(issue.waitForExistence(timeout: 15))
        XCTAssertTrue(firstPhoto.exists && secondPhoto.exists)

        app.buttons["photo-movie-add-photos"].click()
        XCTAssertTrue(picker.waitForExistence(timeout: 15))
        app.typeKey(.escape, modifierFlags: [])
        XCTAssertTrue(picker.waitForNonExistence(timeout: 15))
        XCTAssertTrue(firstPhoto.exists && secondPhoto.exists)

        // Reorder and switch template while keeping selected photos.
        secondPhoto.click()
        app.buttons["photo-movie-move-up"].click()
        XCTAssertTrue(firstPhoto.label.contains("photo-b.jpg"), firstPhoto.debugDescription)
        XCTAssertTrue(secondPhoto.label.contains("photo-a.jpg"), secondPhoto.debugDescription)

        let breezyTemplate = app.buttons["photo-movie-template-breezy-album"]
        XCTAssertTrue(breezyTemplate.waitForExistence(timeout: 5))
        breezyTemplate.click()
        XCTAssertTrue(firstPhoto.label.contains("photo-b.jpg"))
        XCTAssertTrue(secondPhoto.label.contains("photo-a.jpg"))

        // Select soundtrack and render in-place preview via AppKit AVPlayerView.
        app.buttons["photo-movie-select-music"].click()
        choose(soundtrack, in: app)
        let musicName = app.staticTexts["photo-movie-music-name"]
        XCTAssertTrue(musicName.waitForExistence(timeout: 10))
        XCTAssertTrue(musicName.label.contains("soundtrack.wav") || (musicName.value as? String)?.contains("soundtrack.wav") == true)

        let previewPrompt = app.staticTexts["点击「生成并播放预览」查看短片效果"]
        XCTAssertTrue(previewPrompt.exists)
        app.buttons["photo-movie-preview"].click()
        XCTAssertTrue(previewPrompt.waitForNonExistence(timeout: 30), "The preview player must replace its prompt.")
        let playPause = app.buttons["photo-movie-play-pause"]
        XCTAssertTrue(playPause.waitForExistence(timeout: 10))
        XCTAssertEqual(app.state, .runningForeground, "The App must keep running after movie preview starts.")
        let window = app.windows["IOSPS"]
        attach(XCTAttachment(screenshot: window.screenshot()), named: "photo-movie-preview")

        // Leaving the page stops playback and returning preserves photos, order, and music.
        let entry = window.toolbars.buttons.matching(identifier: "photo-movie-entry").firstMatch
        entry.click()
        XCTAssertTrue(app.staticTexts["birthday-title"].waitForExistence(timeout: 10))
        entry.click()
        XCTAssertTrue(firstPhoto.waitForExistence(timeout: 10))
        XCTAssertTrue(firstPhoto.label.contains("photo-b.jpg"))
        XCTAssertTrue(musicName.exists)

        // Export 1080p MP4 through NSSavePanel and verify clean atomic output.
        let movie = outputs.appendingPathComponent("memory-movie.mp4")
        exportButton.click()
        save(movie, in: app)
        let exported = app.staticTexts.matching(NSPredicate(
            format: "identifier == %@ AND (label CONTAINS %@ OR value CONTAINS %@)",
            "photo-movie-status", "回忆短片已导出", "回忆短片已导出"
        )).firstMatch
        XCTAssertTrue(exported.waitForExistence(timeout: 30))
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: outputs.path), ["memory-movie.mp4"])
        XCTAssertEqual(try [photoA, photoB, soundtrack].map { try Data(contentsOf: $0) }, originalBytes)

        attach(XCTAttachment(screenshot: window.screenshot()), named: "photo-movie-exported-window")
        attach(XCTAttachment(data: try Data(contentsOf: movie), uniformTypeIdentifier: UTType.mpeg4Movie.identifier),
               named: "photo-movie-ui-exported")

        app.typeKey("q", modifierFlags: .command)
        XCTAssertTrue(app.wait(for: .notRunning, timeout: 10))
    }

    @MainActor
    private func openPhotoMovie(in app: XCUIApplication) {
        let window = app.windows["IOSPS"]
        if !window.waitForExistence(timeout: 5) {
            app.typeKey("n", modifierFlags: .command)
        }
        XCTAssertTrue(app.staticTexts["birthday-title"].waitForExistence(timeout: 15), app.debugDescription)
        let entry = window.toolbars.buttons.matching(identifier: "photo-movie-entry").firstMatch
        XCTAssertTrue(entry.waitForExistence(timeout: 5), "The main window toolbar should provide a photo movie entry.")
        entry.click()
        XCTAssertTrue(app.buttons["photo-movie-add-photos"].waitForExistence(timeout: 10))
    }

    @MainActor
    private func goTo(_ url: URL, in app: XCUIApplication) {
        app.typeKey("g", modifierFlags: [.command, .shift])
        app.typeText(url.path)
        app.typeKey(.return, modifierFlags: [])
    }

    @MainActor
    private func choose(_ url: URL, in app: XCUIApplication) {
        let panel = app.sheets["open-panel"]
        XCTAssertTrue(panel.waitForExistence(timeout: 15))
        goTo(url, in: app)
        confirm(panel)
        XCTAssertTrue(panel.waitForNonExistence(timeout: 15))
    }

    @MainActor
    private func replaceText(in element: XCUIElement, with text: String, app: XCUIApplication) {
        XCTAssertTrue(element.waitForExistence(timeout: 10))
        element.click()
        app.typeKey("a", modifierFlags: .command)
        app.typeText(text)
    }

    @MainActor
    private func save(_ url: URL, in app: XCUIApplication) {
        let panel = app.sheets.firstMatch
        XCTAssertTrue(panel.waitForExistence(timeout: 15))
        goTo(url.deletingLastPathComponent(), in: app)
        replaceText(in: panel.textFields.firstMatch, with: url.lastPathComponent, app: app)
        confirm(panel)
        let written = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            FileManager.default.fileExists(atPath: url.path)
        }, object: nil)
        XCTAssertEqual(XCTWaiter.wait(for: [written], timeout: 30), .completed)
    }

    @MainActor
    private func confirm(_ panel: XCUIElement) {
        let button = panel.buttons["OKButton"]
        let enabled = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == true AND enabled == true"), object: button)
        XCTAssertEqual(XCTWaiter.wait(for: [enabled], timeout: 20), .completed, panel.debugDescription)
        button.click()
    }

    @MainActor
    private func attach(_ attachment: XCTAttachment, named name: String) {
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private func writePhoto(to url: URL, background: (CGFloat, CGFloat, CGFloat), stripe: (CGFloat, CGFloat, CGFloat)) throws {
        let space = try XCTUnwrap(CGColorSpace(name: CGColorSpace.sRGB))
        let context = try XCTUnwrap(CGContext(
            data: nil, width: 640, height: 360, bitsPerComponent: 8, bytesPerRow: 0,
            space: space, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
        ))
        context.setFillColor(red: background.0, green: background.1, blue: background.2, alpha: 1)
        context.fill(CGRect(x: 0, y: 0, width: 640, height: 360))
        context.setFillColor(red: stripe.0, green: stripe.1, blue: stripe.2, alpha: 1)
        context.fill(CGRect(x: 240, y: 0, width: 160, height: 360))
        let image = try XCTUnwrap(context.makeImage())
        let destination = try XCTUnwrap(CGImageDestinationCreateWithURL(url as CFURL, UTType.jpeg.identifier as CFString, 1, nil))
        CGImageDestinationAddImage(destination, image, nil)
        XCTAssertTrue(CGImageDestinationFinalize(destination))
    }

    private func writeStereoWave(to url: URL, frequency: Double, seconds: Double) throws {
        let sampleRate = 44_100
        let channels = 2
        let bitsPerSample = 16
        let count = Int((seconds * Double(sampleRate)).rounded())
        var pcm = Data()
        pcm.reserveCapacity(count * channels * 2)
        for index in 0..<count {
            let phase = 2.0 * Double.pi * frequency * Double(index) / Double(sampleRate)
            let sample = Int16((sin(phase) * 0.75 * Double(Int16.max)).rounded())
            var little = sample.littleEndian
            withUnsafeBytes(of: &little) { bytes in
                pcm.append(contentsOf: bytes)
                pcm.append(contentsOf: bytes)
            }
        }
        let byteRate = UInt32(sampleRate * channels * bitsPerSample / 8)
        let blockAlign = UInt16(channels * bitsPerSample / 8)
        let dataSize = UInt32(pcm.count)
        let chunkSize = UInt32(36 + pcm.count)
        var wav = Data()
        wav.append(contentsOf: "RIFF".utf8)
        appendLittleEndian(chunkSize, to: &wav)
        wav.append(contentsOf: "WAVE".utf8)
        wav.append(contentsOf: "fmt ".utf8)
        appendLittleEndian(UInt32(16), to: &wav)
        appendLittleEndian(UInt16(1), to: &wav)
        appendLittleEndian(UInt16(channels), to: &wav)
        appendLittleEndian(UInt32(sampleRate), to: &wav)
        appendLittleEndian(byteRate, to: &wav)
        appendLittleEndian(blockAlign, to: &wav)
        appendLittleEndian(UInt16(bitsPerSample), to: &wav)
        wav.append(contentsOf: "data".utf8)
        appendLittleEndian(dataSize, to: &wav)
        wav.append(pcm)
        try wav.write(to: url)
    }

    private func appendLittleEndian<T: FixedWidthInteger>(_ value: T, to data: inout Data) {
        var little = value.littleEndian
        withUnsafeBytes(of: &little) { data.append(contentsOf: $0) }
    }
}
