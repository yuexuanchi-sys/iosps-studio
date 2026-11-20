# ADR-0001：采用 Apple 原生 Swift 技术栈

- 状态：Accepted
- 日期：2026-11-20
- 关联：[R01 §6](../research/调研报告.md)、[R02 §5](../research/补充分析-iOS安装难度与Mac版方案.md)、F-全部

## 背景

App 的核心是图像编辑和视频剪辑，对 GPU 渲染、内存、编解码性能都很敏感；目标设备是 iPhone 14 或朋友的 MacBook，都是 Apple 平台。

## 决策

- 语言：**Swift 6.x**；界面：**SwiftUI**（复杂画布用 UIKit/AppKit 包一层，或直接用 Metal 视图）。
- 图像：**Core Image**（主力）+ 自定义 Metal kernel（复杂效果）；抠图和人脸检测用 **Vision**。
- 视频：**AVFoundation**（编辑、预览、导出），逐帧处理用 Core Image（见 ADR-0002）。
- 第三方依赖**越少越好**，只引入 MIT / BSD / Apache-2.0 许可的库，通过 SwiftPM 引入，并锁定版本。候选：ZLPhotoBrowser（仅 iOS）、Brightroom、MetalPetal、TOCropViewController、PryntTrimmerView —— **默认不引入**，等某个任务确实需要时再在任务卡里论证。
- 最低系统版本：iOS **17.0**；macOS 待定（跟 ADR-0003 一起确定，建议 14.0 起）。

## 备选方案

| 方案 | 优点 | 缺点 | 结论 |
|---|---|---|---|
| WKWebView 嵌 Web 编辑器 | 开发快 | Canvas 约 1600 万像素上限、大图内存压力大、交互割裂、视频弱 | ❌ 否决（最多用来做彩蛋页） |
| Flutter / React Native | Windows 上也能写 | 图像/视频插件生态弱，重活还是要写原生桥接 | ❌ 否决 |
| 移植 Compositor / PhotoCraft | 功能现成 | 技术栈和 UI 差异巨大；Compositor 只支持 macOS 26+ 和 Apple 芯片，而且是专业 PS 式界面 | ❌ 不移植；Mac 版可以**参考**它的实现（视 D-07 而定） |

## 后果

- ✅ 性能、体积、体验最好；Mac 版和 iOS 版可以共享核心代码（ADR-0006）。
- ⚠️ 必须有 macOS 构建环境 → ADR-0004。
- ⚠️ Swift 写 Apple 框架相关代码无法在 Windows 上编译验证，只能靠 CI。

## 修订记录

- 2026-11-20：当前交付平台及部署目标以 [ADR-0003](ADR-0003-target-platform.md) 为准。
- 2026-11-20：用户要求优先完成 Compositor 只读预评估，见 [R04](../research/R04-compositor-reuse.md)。修图底座的正式迁移待 [D-12](../../STATUS.md) 确认，新增自研修图引擎代码暂缓。
