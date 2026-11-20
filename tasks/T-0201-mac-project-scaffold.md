---
id: T-0201
title: macOS 多模块工程骨架
milestone: M2
status: blocked
priority: P0
modules: BirthdayCore, DesignSystem, AppMac
features: none
depends: T-0003
verify: L0,L1,L2
owner: AI
updated: 2026-11-20
---

# T-0201 · macOS 多模块工程骨架

## 目标
建立 Swift 6 可扩展工程与 Mac 应用入口，Windows 单独运行纯逻辑包。

## 背景与依据
- [模块目录](../docs/architecture/modules.md)、[ADR-0003](../docs/decisions/ADR-0003-target-platform.md)、[ADR-0006](../docs/decisions/ADR-0006-shared-core-architecture.md)。

## 范围
引入 BirthdayCore 的项目 ID、DesignSystem 的首屏祝福组件和 AppMac。其余目标随各自首个功能切片加入；任何目标都要有可调用实现。扩展 L0 检查 L1 仅使用批准的模块。T-0005 用同一工程做冒烟。

## 验收标准
- [x] AC1：SwiftPM 产品、AppMac/XcodeGen、应用入口与许可登记俱全；L0 拒绝 L1 中越层或 Apple 专有 import。 证据：YAML 和字符串目录可解析；临时 GiftKit 文件允许 Foundation/BirthdayCore，AppKit、SwiftUI scoped import、TimelineKit 在正确行被拒绝。
- [ ] AC2：`swift test --package-path app` 的 ID 用例通过。
- [ ] AC3：在 macOS CI 运行 `xcodegen generate` 与 `xcodebuild -project IOSPS.xcodeproj -scheme AppMac -configuration Release -destination 'platform=macOS' build`，生成 arm64 App。

## 实施要点
- 假设：先接入有实际实现的 BirthdayCore、DesignSystem 和 AppMac；其余目标随首次切片加入，避免空壳。
- 先写 ID 编解码测试，再加 SwiftPM、XcodeGen 和 SwiftUI 入口。加入 L0 进口约束并注入反例验证。

## 进度日志
- 2026-11-20：从看板滚动细化。
- 2026-11-20：工程已写齐，待验证（L1/L2）。L0 check_repo 0 error；Swift 测试命令找不到 swift，T-0005 首次 CI 验证时须 AC2/AC3 一并取证。逐文件人工核对目标、导入、局部资源与主线程隔离。
