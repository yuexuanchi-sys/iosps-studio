import AppKit
import GiftKit
import SwiftUI

/// Shares the app's initial greeting with the visual smoke test.
@MainActor
public struct BirthdayGreetingView: View {
    @Environment(\.colorScheme) private var colorScheme

    private static let artwork = Bundle.module.url(forResource: "birthday-card-art", withExtension: "png")
        .flatMap { NSImage(contentsOf: $0) }

    private let enlargedText: Bool
    private let wishes: String?
    private let birthday: LocalDay?
    private let metrics: GiftMetrics?
    private let configurationFailed: Bool
    private let onEasterEgg: (() -> Void)?

    /// Renders the greeting and optional civil-day metrics supplied by the app.
    public init(
        enlargedText: Bool = false,
        wishes: String? = nil,
        birthday: LocalDay? = nil,
        metrics: GiftMetrics? = nil,
        configurationFailed: Bool = false,
        onEasterEgg: (() -> Void)? = nil
    ) {
        self.enlargedText = enlargedText
        self.wishes = wishes
        self.birthday = birthday
        self.metrics = metrics
        self.configurationFailed = configurationFailed
        self.onEasterEgg = onEasterEgg
    }

    public var body: some View {
        ViewThatFits(in: .vertical) {
            card
            ScrollView {
                card
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .frame(minWidth: 360, minHeight: 240)
        .background {
            LinearGradient(colors: [backgroundHighlight, backgroundBase], startPoint: .topLeading, endPoint: .bottomTrailing)
        }
    }

    private var card: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 28) {
                greetingContent
                    .frame(idealWidth: 282, maxWidth: .infinity, alignment: .leading)
                illustration(size: 240)
            }
            .padding(.horizontal, 36)
            .padding(.vertical, 28)
            .frame(minWidth: 600, maxWidth: 836)

            VStack(alignment: .leading, spacing: 16) {
                illustration(size: 153)
                    .frame(maxWidth: .infinity)
                greetingContent
            }
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(paper, in: RoundedRectangle(cornerRadius: 24))
        .overlay {
            RoundedRectangle(cornerRadius: 24)
                .strokeBorder(accent.opacity(0.24), lineWidth: 1)
                .allowsHitTesting(false)
        }
        .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.20 : 0.09), radius: 20, x: 0, y: 10)
        .fixedSize(horizontal: false, vertical: true)
        .padding(22)
    }

    private var greetingContent: some View {
        VStack(alignment: .leading, spacing: 13) {
            Capsule()
                .fill(accent)
                .frame(width: 27, height: 3)
                .accessibilityHidden(true)
            Text("生日快乐", bundle: .module)
                .font(.system(size: enlargedText ? 51 : 41, weight: .semibold, design: .serif))
                .foregroundStyle(ink)
                .accessibilityAddTraits(.isHeader)
                .accessibilityIdentifier("birthday-title")
            greetingWish
                .font(.system(size: enlargedText ? 19 : 16))
                .foregroundStyle(secondaryInk)
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("birthday-wishes")
            dateMetrics
            if let onEasterEgg {
                Button(action: onEasterEgg) {
                    Label {
                        Text("打开彩蛋", bundle: .module)
                    } icon: {
                        Image(systemName: "heart")
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(buttonTint)
                .controlSize(.large)
                .accessibilityIdentifier("birthday-easter-egg")
            }
            if configurationFailed {
                Text("生日素材读取失败，可从「生日」菜单重试。", bundle: .module)
                    .font(.footnote)
                    .foregroundStyle(secondaryInk)
            }
        }
    }

    private var greetingWish: Text {
        if let wishes, !wishes.isEmpty {
            return Text(verbatim: wishes)
        }
        return Text("愿新的一岁，有好天气，也有值得珍藏的小日子。", bundle: .module)
    }

    private func illustration(size: CGFloat) -> some View {
        ZStack {
            Circle()
                .fill(RadialGradient(colors: [artGlow, paper.opacity(0)], center: .center,
                                     startRadius: 0, endRadius: size * 0.52))
                .frame(width: size, height: size)
            if let artwork = Self.artwork {
                Image(nsImage: artwork)
                    .resizable()
                    .scaledToFit()
            }
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
        .allowsHitTesting(false)
    }

    @ViewBuilder
    private var dateMetrics: some View {
        if let metrics, birthday != nil || metrics.daysSinceMeeting != nil {
            VStack(alignment: .leading, spacing: 4) {
                if let birthday {
                    Text("生日 \(birthday.month) 月 \(birthday.day) 日", bundle: .module)
                }
                if let days = metrics.daysUntilBirthday {
                    if metrics.isBirthday {
                        Text("今天是生日", bundle: .module)
                    } else {
                        Text("距离生日还有 \(days) 天", bundle: .module)
                    }
                }
                if let age = metrics.age {
                    Text("年龄 \(age) 岁", bundle: .module)
                }
                if let days = metrics.daysSinceMeeting {
                    Text("已相识 \(days) 天", bundle: .module)
                }
            }
            .font(.system(size: enlargedText ? 15 : 13))
            .foregroundStyle(secondaryInk)
        }
    }

    private var backgroundHighlight: Color { themed(0xFCF0DE, 0x382A27) }
    private var backgroundBase: Color { themed(0xEBCDC1, 0x1C181A) }
    private var paper: Color { themed(0xFFF9EE, 0x2D2423) }
    private var ink: Color { themed(0x35241F, 0xFFF2E6) }
    private var secondaryInk: Color { themed(0x674D45, 0xDEC2B5) }
    private var accent: Color { themed(0xA5483F, 0xF0A391) }
    private var buttonTint: Color { themed(0x903730, 0x983D33) }
    private var artGlow: Color { themed(0xF5DFCD, 0x5A3832) }

    private func themed(_ light: UInt32, _ dark: UInt32) -> Color {
        let rgb = colorScheme == .dark ? dark : light
        return Color(red: Double((rgb >> 16) & 0xff) / 255,
                     green: Double((rgb >> 8) & 0xff) / 255,
                     blue: Double(rgb & 0xff) / 255)
    }
}
