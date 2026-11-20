---
id: T-0008
title: Compositor 完整继承隔离原型
milestone: M0
status: ready
priority: P0
modules: AppMac, GiftKit, MediaIO, VideoEngine
features: F-01, F-02, F-07, F-08, F-13, F-14, F-15
depends: T-0006, T-0202
verify: L0,L1,L2,L3,L4
owner: AI+用户
updated: 2026-11-20
---

# T-0008 · Compositor 完整继承隔离原型

## 目标

在 macOS 26+／arm64 验证能否使用完整 Compositor 编辑器作为礼物原型的底座，同时保留现有 IOSPS 的工程和部署基线。

## 背景与依据

- [D-12](../STATUS.md)、[R04](../docs/research/R04-compositor-reuse.md)、[ADR-0003](../docs/decisions/ADR-0003-target-platform.md)、[ADR-0005](../docs/decisions/ADR-0005-distribution.md)、[易用性原则](../docs/product/ux-principles.md)。

## 范围

固定上游 `4a17b264a93b6da5fa5ff81357e6194ef9ad61a2`，在隔离 Git 分支上验证派生应用。原型工作以已阅读源码和合成素材为输入，使用独立 App 标识。原型评审后另由用户决定是否正式迁移和调整主线部署下限。

## 验收标准

- [ ] AC1：L1/L2，原 IOSPS 的 47 个 SwiftPM 测试通过；派生目标用 Swift 6 严格并发、macOS 26.0、arm64 Release 实际构建，记录 run、SHA、Xcode、签名与耗时。
- [ ] AC2：L2/L3，简体中文编辑入口完成 JPEG/PNG 选择、画布平移缩放、固定比例裁剪、90° 旋转、曝光、饱和度、撤销重做、项目重开和原像素尺寸 PNG/JPEG 导出。核对源文件哈希、方向、ICC 和透明度，查看浅色、深色、放大字号截图及键盘结果。
- [ ] AC3：L2/L3，首屏展示生日信息，读取虚构回忆包。编辑结果通过 `MediaID` 提供给短片入口，用单模板导出可播放的 3 秒／30 fps／90 帧无声 MP4。
- [ ] AC4：L2/L4，下载并核对 ad-hoc ZIP、SHA-256、权限和许可证；目标机断网首次启动、修图与短片导出、退出重开。记录 12 MP 样本用时和峰值内存，区分 CI 与真机证据。

## 实施要点

- 假设：用 `t-0008-compositor-prototype` 隔离分支及独立原型工作流和应用标识。核对固定源码、许可与资源来源后只把构建所需的派生代码放入 `app/`。上游下载目录仅供只读，原型使用仓库自己的 CI 命令，移除上游签名、更新和模型下载路径。
- 顺序：先验证原有编辑器构建和图像工作流，再接中文导航、`GiftKit`／`MediaIO`、短片入口与产物回读。每次开始代码改动前将所涉文件、实际验收命令与预期输出补入本卡。主线继续按 14.0 验收。

## 进度日志

- 2026-11-20：D-12 选定完整继承原型，从 T-0006 转入独立运行验收。静态证据和初始门槛见 R04。
