import CoreGraphics
import Foundation

/// Built-in photo crop aspect presets exposed behind the ImageEngine adapter boundary.
nonisolated enum PhotoCropAspect: String, CaseIterable, Identifiable, Equatable, Hashable, Sendable {
    case free = "Free"
    case original = "Canvas"
    case square = "1:1"
    case fourThree = "4:3"
    case threeFour = "3:4"
    case threeTwo = "3:2"
    case sixteenNine = "16:9"
    case nineSixteen = "9:16"
    case twoOne = "2:1"

    var id: String { rawValue }
    var compositorChoice: String { rawValue }

    var displayTitle: String {
        switch self {
        case .free: "自由"
        case .original: "原图"
        case .square: "1:1"
        case .fourThree: "4:3"
        case .threeFour: "3:4"
        case .threeTwo: "3:2"
        case .sixteenNine: "16:9"
        case .nineSixteen: "9:16"
        case .twoOne: "2:1"
        }
    }

    var accessibilityTitle: String {
        switch self {
        case .free: "自由裁剪"
        case .original: "原图比例裁剪"
        case .square: "正方形裁剪"
        case .fourThree: "四比三裁剪"
        case .threeFour: "三比四裁剪"
        case .threeTwo: "三比二裁剪"
        case .sixteenNine: "十六比九裁剪"
        case .nineSixteen: "九比十六裁剪"
        case .twoOne: "二比一裁剪"
        }
    }

    var accessibilityID: String {
        switch self {
        case .free: "photo-editor-crop-free"
        case .original: "photo-editor-crop-original"
        case .square: "photo-editor-crop-square"
        case .fourThree: "photo-editor-crop-4-3"
        case .threeFour: "photo-editor-crop-3-4"
        case .threeTwo: "photo-editor-crop-3-2"
        case .sixteenNine: "photo-editor-crop-16-9"
        case .nineSixteen: "photo-editor-crop-9-16"
        case .twoOne: "photo-editor-crop-wide"
        }
    }

    /// Validates and normalizes user-entered `W:H` ratio strings (e.g. `" 5 : 4 "` -> `"5:4"`).
    static func normalizedCustomRatio(_ raw: String) -> (choice: String, ratio: CGFloat)? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let parsed = CropGeometry.ratio(trimmed) else { return nil }
        let normalized = trimmed.split(separator: ":", omittingEmptySubsequences: false).map {
            $0.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: ",", with: ".")
        }.joined(separator: ":")
        return (normalized, parsed)
    }

    /// Resolves the numeric width/height ratio for any built-in or custom crop choice string.
    static func resolvedRatio(for choice: String, canvasSize: CGSize) -> CGFloat? {
        switch choice {
        case PhotoCropAspect.free.compositorChoice:
            return nil
        case PhotoCropAspect.original.compositorChoice:
            guard canvasSize.width > 0, canvasSize.height > 0 else { return nil }
            return canvasSize.width / canvasSize.height
        default:
            return CropGeometry.ratio(choice)
        }
    }

    /// Computes the largest centered integer-pixel crop rectangle matching `ratio` strictly inside `canvasSize`.
    static func centeredCropRect(in canvasSize: CGSize, ratio: CGFloat?) -> CGRect {
        guard canvasSize.width >= 1, canvasSize.height >= 1 else {
            return CGRect(x: 0, y: 0, width: 1, height: 1)
        }
        guard let ratio, ratio.isFinite, ratio > 0 else {
            return CGRect(origin: .zero, size: CGSize(width: canvasSize.width.rounded(), height: canvasSize.height.rounded()))
        }
        let width = min(canvasSize.width, canvasSize.height * ratio)
        let height = width / ratio
        let raw = CGRect(
            x: (canvasSize.width - width) / 2,
            y: (canvasSize.height - height) / 2,
            width: width,
            height: height
        )
        return clampedToCanvas(CropGeometry.snapped(raw), canvasSize: canvasSize)
    }

    /// Clamps an integer-pixel crop rectangle so it stays completely inside `[0, canvasWidth] x [0, canvasHeight]`.
    static func clampedToCanvas(_ rect: CGRect, canvasSize: CGSize) -> CGRect {
        let maxW = max(1, canvasSize.width.rounded())
        let maxH = max(1, canvasSize.height.rounded())
        let standardized = rect.standardized
        let minX = min(max(0, standardized.minX.rounded()), maxW - 1)
        let minY = min(max(0, standardized.minY.rounded()), maxH - 1)
        let maxX = min(maxW, max(minX + 1, standardized.maxX.rounded()))
        let maxY = min(maxH, max(minY + 1, standardized.maxY.rounded()))
        return CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }
}
