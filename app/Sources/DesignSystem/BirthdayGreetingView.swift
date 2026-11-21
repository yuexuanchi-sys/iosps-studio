import AppKit
import GiftKit
import SwiftUI

/// Shares the app's initial greeting with the visual smoke test.
@MainActor
public struct BirthdayGreetingView: View {
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
        GeometryReader { proxy in
            ScrollView {
                VStack(spacing: 16) {
                    Text("生日快乐", bundle: .module)
                        .font(enlargedText ? .system(size: 44, weight: .semibold) : .largeTitle.weight(.semibold))
                        .accessibilityAddTraits(.isHeader)
                        .accessibilityIdentifier("birthday-title")
                    if let wishes, !wishes.isEmpty {
                        Text(verbatim: wishes)
                            .font(.title3)
                    }
                    dateMetrics
                    if let onEasterEgg {
                        Button(action: onEasterEgg) {
                            Label {
                                Text("打开彩蛋", bundle: .module)
                            } icon: {
                                Image(systemName: "heart")
                            }
                        }
                        .buttonStyle(.bordered)
                        .accessibilityIdentifier("birthday-easter-egg")
                    }
                    if configurationFailed {
                        Text("生日素材读取失败，可从「生日」菜单重试。", bundle: .module)
                            .foregroundStyle(.secondary)
                    }
                }
                .multilineTextAlignment(.center)
                .frame(maxWidth: 560)
                .padding(24)
                .frame(maxWidth: .infinity, minHeight: proxy.size.height)
            }
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .frame(minWidth: 360, minHeight: 240)
    }

    @ViewBuilder
    private var dateMetrics: some View {
        if let metrics, birthday != nil || metrics.daysSinceMeeting != nil {
            VStack(spacing: 6) {
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
            .foregroundStyle(.secondary)
        }
    }
}
