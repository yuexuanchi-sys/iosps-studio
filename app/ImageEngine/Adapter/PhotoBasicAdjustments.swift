import CoreGraphics
import CoreImage
import Foundation

/// Offline Core Image parameters for F-08 basic photo adjustments (zero external binary LUT dependencies).
nonisolated struct PhotoBasicAdjustments: Codable, Equatable, Hashable, Sendable {
    static let signedRange: ClosedRange<Double> = -100...100
    static let exposureRange: ClosedRange<Double> = -2...2
    static let positiveRange: ClosedRange<Double> = 0...100

    /// Brightness (-100...100).
    var brightness: Double = 0
    /// Contrast (-100...100).
    var contrast: Double = 0
    /// Saturation (-100...100; -100 is grayscale).
    var saturation: Double = 0
    /// Exposure in EV stops (-2...2).
    var exposure: Double = 0
    /// Color temperature (-100 cool ... +100 warm).
    var temperature: Double = 0
    /// Highlights recovery / lift (-100...100).
    var highlights: Double = 0
    /// Shadows lift / deepen (-100...100).
    var shadows: Double = 0
    /// Unsharp mask sharpening strength (0...100).
    var sharpen: Double = 0
    /// Radial corner darkening vignette strength (0...100).
    var vignette: Double = 0

    var isIdentity: Bool {
        let s = normalized
        return s.brightness == 0
            && s.contrast == 0
            && s.saturation == 0
            && s.exposure == 0
            && s.temperature == 0
            && s.highlights == 0
            && s.shadows == 0
            && s.sharpen == 0
            && s.vignette == 0
    }

    var normalized: Self {
        func clamp(_ value: Double, _ range: ClosedRange<Double>) -> Double {
            value.isFinite ? min(range.upperBound, max(range.lowerBound, value)) : 0
        }
        return Self(
            brightness: clamp(brightness, Self.signedRange),
            contrast: clamp(contrast, Self.signedRange),
            saturation: clamp(saturation, Self.signedRange),
            exposure: clamp(exposure, Self.exposureRange),
            temperature: clamp(temperature, Self.signedRange),
            highlights: clamp(highlights, Self.signedRange),
            shadows: clamp(shadows, Self.signedRange),
            sharpen: clamp(sharpen, Self.positiveRange),
            vignette: clamp(vignette, Self.positiveRange)
        )
    }

    /// Renders all active basic adjustments offline via Core Image while guaranteeing exact pixel identity when zero.
    func apply(to image: CGImage, scale: CGFloat = 1) throws -> CGImage {
        let s = normalized
        guard !s.isIdentity else { return image }

        let width = image.width
        let height = image.height
        let extent = CGRect(x: 0, y: 0, width: width, height: height)
        var current = CIImage(cgImage: image)

        if s.exposure != 0 {
            current = current.applyingFilter("CIExposureAdjust", parameters: [
                kCIInputEVKey: s.exposure,
            ])
        }

        if s.brightness != 0 || s.contrast != 0 || s.saturation != 0 {
            let brightnessParam = s.brightness / 200.0
            let contrastParam = 1.0 + (s.contrast / 150.0)
            let saturationParam = max(0.0, 1.0 + (s.saturation / 100.0))
            current = current.applyingFilter("CIColorControls", parameters: [
                kCIInputBrightnessKey: brightnessParam,
                kCIInputContrastKey: contrastParam,
                kCIInputSaturationKey: saturationParam,
            ])
        }

        if s.temperature != 0 {
            let t = s.temperature / 100.0
            let rGain = CGFloat(1.0 + t * 0.22)
            let gGain = CGFloat(1.0 + t * 0.03)
            let bGain = CGFloat(1.0 - t * 0.22)
            current = current.applyingFilter("CIColorMatrix", parameters: [
                "inputRVector": CIVector(x: rGain, y: 0, z: 0, w: 0),
                "inputGVector": CIVector(x: 0, y: gGain, z: 0, w: 0),
                "inputBVector": CIVector(x: 0, y: 0, z: bGain, w: 0),
                "inputAVector": CIVector(x: 0, y: 0, z: 0, w: 1),
                "inputBiasVector": CIVector(x: 0, y: 0, z: 0, w: 0),
            ])
        }

        if s.highlights != 0 || s.shadows != 0 {
            let shadowY = min(0.45, max(0.05, 0.25 + (s.shadows / 100.0) * 0.16))
            let highlightY = min(0.95, max(0.55, 0.75 + (s.highlights / 100.0) * 0.16))
            current = current.applyingFilter("CIToneCurve", parameters: [
                "inputPoint0": CIVector(x: 0, y: 0),
                "inputPoint1": CIVector(x: 0.25, y: shadowY),
                "inputPoint2": CIVector(x: 0.50, y: 0.50),
                "inputPoint3": CIVector(x: 0.75, y: highlightY),
                "inputPoint4": CIVector(x: 1, y: 1),
            ])
        }

        if s.sharpen > 0 {
            let radius = max(0.5, 2.0 * Double(scale))
            let intensity = (s.sharpen / 100.0) * 1.5
            current = current
                .clampedToExtent()
                .applyingFilter("CIUnsharpMask", parameters: [
                    kCIInputRadiusKey: radius,
                    kCIInputIntensityKey: intensity,
                ])
                .cropped(to: extent)
        }

        if s.vignette > 0 {
            let intensity = (s.vignette / 100.0) * 2.0
            current = current
                .applyingFilter("CIVignette", parameters: [
                    kCIInputIntensityKey: intensity,
                    kCIInputRadiusKey: 1.0,
                ])
                .cropped(to: extent)
        }

        return try PixelAdjust.render(current.cropped(to: extent), width: width, height: height, isMask: false)
    }
}
