---
id: T-0008
title: Compositor 派生编辑器构建与回归
milestone: M0
status: in-progress
priority: P0
modules: AppMac, GiftKit, MediaIO, VideoEngine
features: F-01, F-02, F-07, F-08, F-13, F-14, F-15
depends: T-0006, T-0202
verify: L0,L1,L2
owner: AI+用户
updated: 2026-11-20
---

# T-0008 · Compositor 派生编辑器构建与回归

## 目标

在 macOS 26+／arm64 对完整继承路线做第一段验证，确认派生应用能够在 Swift 6 中构建，并保留裁剪、调色、文档和导出链路。[T-0009](T-0009-compositor-prototype-gift-interface.md) 接中文与回忆，[T-0010](T-0010-compositor-prototype-offline-movie.md) 验证短片和离线交付。

## 背景与依据

- [D-12](../STATUS.md)、[R04](../docs/research/R04-compositor-reuse.md)、[ADR-0003](../docs/decisions/ADR-0003-target-platform.md)、[ADR-0005](../docs/decisions/ADR-0005-distribution.md)、[易用性原则](../docs/product/ux-principles.md)。

## 范围

固定上游 `4a17b264a93b6da5fa5ff81357e6194ef9ad61a2`，在隔离 Git 分支上验证派生应用。原型工作以已阅读源码和合成素材为输入，使用独立 App 标识。原型评审后另由用户决定是否正式迁移和调整主线部署下限。

## 验收标准

- [ ] AC1：L1/L2，原 IOSPS 的 47 个 SwiftPM 测试通过；派生目标用 Swift 6 严格并发、macOS 26.0、arm64 Release 实际构建，记录 run、SHA、Xcode、签名与耗时。
- [ ] AC2：L2，使用合成样本回归固定比例裁剪、旋转、曝光／饱和度、撤销重做、项目重开和原像素尺寸 PNG/JPEG 导出。核对源文件哈希、方向、ICC 和透明度。
- [ ] AC3：L2，CI 生成并校验原型 ad-hoc 签名 ZIP、SHA-256、权限和许可。上游 appcast、模型与无再分发依据的资产均排除。

## 实施要点

- 假设：用 `t-0008-compositor-prototype` 隔离分支及独立原型工作流和应用标识。核对固定源码、许可与资源来源后只把构建所需的派生代码放入 `app/`。上游下载目录仅供只读，原型使用仓库自己的 CI 命令，移除上游签名、更新和模型下载路径。
- 交付物：隔离分支上的 `app/Prototype/` 派生代码、`app/compositor-prototype.yml`、原型 CI 与许可登记。用 `xcodegen generate --spec compositor-prototype.yml` 生成工程，再以 `xcodebuild -project IOSPSCompositorPrototype.xcodeproj -scheme CompositorPrototype -configuration Release -destination 'platform=macOS' build` 构建。按同一 scheme 运行合成照片回归测试，0 失败。主线继续按 14.0 验收。

## 进度日志

- 2026-11-20：D-12 选定完整继承原型，从 T-0006 转入独立运行验收。静态证据和初始门槛见 R04。
- 2026-11-20：按运行依赖拆为三个可验收切片。原 AC2 的中文、画布交互、键盘和三类 UI 截图，以及 AC3 的生日和回忆验收移到 T-0009。原 AC3 的 MP4 和原 AC4 的断网真机验收、性能记录移到 T-0010。保留构建和编辑内核的回归要求。
