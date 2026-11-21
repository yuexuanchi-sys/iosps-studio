import AppKit
import CoreGraphics
import DesignSystem
import Foundation
import GiftKit
import SwiftUI

private enum SnapshotError: Error {
    case missingOutputPath
    case pngEncodingFailed
}

@main
struct BirthdaySmokeSnapshot {
    @MainActor
    static func main() throws {
        let arguments = CommandLine.arguments.dropFirst()
        if arguments.count == 2, arguments.first == "--variants", let path = arguments.last {
            let directory = URL(fileURLWithPath: path, isDirectory: true)
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let variants: [(name: String, scheme: ColorScheme, enlargedText: Bool)] = [
                ("light", .light, false),
                ("dark", .dark, false),
                ("large", .light, true),
            ]
            for variant in variants {
                try render(to: directory.appendingPathComponent("birthday-\(variant.name).png"),
                           size: CGSize(width: 1280, height: 800), scheme: variant.scheme,
                           enlargedText: variant.enlargedText)
            }
        } else if arguments.count == 1, let path = arguments.first {
            try render(to: URL(fileURLWithPath: path), size: CGSize(width: 720, height: 480),
                       scheme: .light, enlargedText: false)
        } else {
            throw SnapshotError.missingOutputPath
        }
    }

    @MainActor
    private static func render(to output: URL, size: CGSize, scheme: ColorScheme, enlargedText: Bool) throws {
        let birthday = try LocalDay(isoDate: "2000-02-29")
        let metOn = try LocalDay(isoDate: "2025-02-27")
        let today = try LocalDay(isoDate: "2025-02-28")
        let view = BirthdayGreetingView(
            enlargedText: enlargedText,
            wishes: "愿这一年有更多好天气，也有更多值得记住的小事。",
            birthday: birthday,
            metrics: GiftCalendar.metrics(on: today, birthday: birthday, metOn: metOn),
            onEasterEgg: {}
        )
            .frame(width: size.width, height: size.height)
            .environment(\.colorScheme, scheme)
        guard let appearance = NSAppearance(named: scheme == .dark ? .darkAqua : .aqua) else {
            throw SnapshotError.pngEncodingFailed
        }
        var rendered: CGImage?
        appearance.performAsCurrentDrawingAppearance {
            let renderer = ImageRenderer(content: view)
            renderer.scale = 1
            rendered = renderer.cgImage
        }
        guard let image = rendered,
              let png = NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:]) else {
            throw SnapshotError.pngEncodingFailed
        }
        try png.write(to: output, options: .atomic)
    }
}
