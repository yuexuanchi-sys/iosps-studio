// swift-tools-version: 6.0
import PackageDescription

var products: [Product] = [
    .library(name: "BirthdayCore", targets: ["BirthdayCore"]),
    .library(name: "GiftKit", targets: ["GiftKit"]),
    .library(name: "TimelineKit", targets: ["TimelineKit"]),
    .library(name: "TemplateKit", targets: ["TemplateKit"]),
]
var targets: [Target] = [
    .target(name: "BirthdayCore"),
    .testTarget(name: "BirthdayCoreTests", dependencies: ["BirthdayCore"]),
    .target(name: "GiftKit"),
    .testTarget(name: "GiftKitTests", dependencies: ["GiftKit"]),
    .target(name: "TimelineKit", dependencies: ["BirthdayCore"]),
    .testTarget(name: "TimelineKitTests", dependencies: ["TimelineKit", "BirthdayCore"]),
    .target(name: "TemplateKit", dependencies: ["BirthdayCore"]),
    .testTarget(name: "TemplateKitTests", dependencies: ["TemplateKit"]),
]

#if os(macOS)
products.append(.library(name: "MediaIO", targets: ["MediaIO"]))
targets.append(.target(name: "MediaIO", dependencies: ["BirthdayCore"]))
targets.append(.testTarget(name: "MediaIOTests", dependencies: ["BirthdayCore", "MediaIO"]))
products.append(.library(name: "DesignSystem", targets: ["DesignSystem"]))
targets.append(.target(name: "DesignSystem", dependencies: ["GiftKit"], resources: [.process("Resources")]))
targets.append(.executableTarget(name: "BirthdaySmokeSnapshot", dependencies: ["DesignSystem", "GiftKit"]))
products.append(.library(name: "VideoEngine", targets: ["VideoEngine"]))
targets.append(.target(name: "VideoEngine", dependencies: ["BirthdayCore", "TimelineKit"]))
#endif

let package = Package(
    name: "IOSPSModules",
    defaultLocalization: "zh-Hans",
    platforms: [.macOS(.v14)],
    products: products,
    targets: targets
)
