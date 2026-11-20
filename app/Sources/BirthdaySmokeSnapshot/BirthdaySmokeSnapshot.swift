import AppKit
import DesignSystem
import Foundation
import SwiftUI

private enum SnapshotError: Error {
    case missingOutputPath
    case pngEncodingFailed
}

@main
struct BirthdaySmokeSnapshot {
    @MainActor
    static func main() throws {
        guard CommandLine.arguments.count == 2 else {
            throw SnapshotError.missingOutputPath
        }
        let output = URL(fileURLWithPath: CommandLine.arguments[1])
        let view = BirthdayGreetingView()
            .frame(width: 720, height: 480)
            .environment(\.colorScheme, .light)
        let renderer = ImageRenderer(content: view)
        guard let image = renderer.cgImage,
              let png = NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:]) else {
            throw SnapshotError.pngEncodingFailed
        }
        try png.write(to: output, options: .atomic)
    }
}
