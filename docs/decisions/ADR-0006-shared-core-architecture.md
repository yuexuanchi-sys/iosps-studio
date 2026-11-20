# ADR-0006：跨平台核心 + 薄平台壳的分层架构

- 状态：Accepted
- 日期：2026-11-20
- 关联：[R02 §5.1](../research/补充分析-iOS安装难度与Mac版方案.md)、[R03 §3.1](../research/R03-fact-check-2026-11-20.md)、[architecture/overview.md](../architecture/overview.md)、[modules.md](../architecture/modules.md)

## 背景

1. 平台还没定（ADR-0003），但很多工作和平台无关，现在就可以设计。
2. 没有 Mac 时，**能在 Windows 本地测试的代码越多，反馈越快**。
3. 以后可能 Mac 和 iOS 都要做，核心逻辑应该复用。

## 决策

把代码分成三层，用 SwiftPM 多模块实现（目录 `app/`）：

| 层 | 模块 | 允许依赖 | 在哪里测试 |
|---|---|---|---|
| **L1 纯逻辑层** | `BirthdayCore`、`TemplateKit`、`TimelineKit`、`GiftKit` | 只能用 Swift 标准库 + Foundation 里**跨平台可用**的部分 | Windows 本地 `swift test` + CI |
| **L2 引擎层** | `ImageEngine`、`VideoEngine`、`MediaIO` | L1 + Apple 框架（Core Image、Metal、AVFoundation、Vision、Photos） | CI（macOS） |
| **L3 界面层** | `DesignSystem`（共享 SwiftUI 组件）、`AppMac` / `AppiOS`（平台壳） | L1 + L2 + SwiftUI / AppKit / UIKit | CI 构建 + 截图 |

硬性规则：
- 依赖**只能从上往下**（L3 → L2 → L1），同层之间尽量不互相依赖；
- L1 **禁止** `import` 任何 Apple 专有框架（CoreImage、AVFoundation、UIKit、AppKit、SwiftUI、Photos、Vision…），也禁止使用 Foundation 中仅 Apple 平台可用的 API；
- 平台差异（`#if os(iOS)` / `#if os(macOS)`）只允许出现在 L2 的 `MediaIO` 和 L3；
- 业务数据（工程文件、模板、时间轴）全部用 L1 的 `Codable` 模型表示，引擎层只负责"把模型渲染出来"。

## 备选方案

| 方案 | 结论 |
|---|---|
| 单一 App target，所有代码放一起 | ❌ 没法在 Windows 上测，以后也难以复用 |
| 每个功能一个模块（几十个模块） | ❌ 对这个规模来说太重 |

## 后果

- ✅ 平台没定之前，L1 模块就可以开工（只要 M1 产品定义完成）。
- ✅ 以后补另一端，只需要新增一个 L3 平台壳 + 少量 `MediaIO` 适配。
- ⚠️ 需要纪律：`tools/check_repo.py` 后续会加一条检查 L1 有没有 import 违规（T-0201）。

## 修订记录

- 2026-11-20：本轮平台壳为 AppMac，见 [ADR-0003](ADR-0003-target-platform.md)。
