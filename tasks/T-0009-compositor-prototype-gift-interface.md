---
id: T-0009
title: Compositor 原型中文编辑、生日和回忆
milestone: M0
status: ready
priority: P0
modules: AppMac, DesignSystem, GiftKit, MediaIO
features: F-01, F-02, F-07, F-08, F-13, F-14
depends: T-0008
verify: L0,L2,L3
owner: AI+用户
updated: 2026-11-20
---

# T-0009 · Compositor 原型中文编辑、生日和回忆

## 目标

在派生编辑器上呈现简体中文礼物首页、回忆与简单编辑入口，并回读实际画面。

## 背景与依据

- [R04](../docs/research/R04-compositor-reuse.md)、[T-0008](T-0008-compositor-integrated-prototype.md)、[易用性原则](../docs/product/ux-principles.md)。

## 验收标准

- [ ] AC1：简体中文入口完成 JPEG/PNG 选择、平移缩放、固定比例裁剪、90° 旋转、曝光、饱和度、撤销重做、工程重开和原像素尺寸 PNG/JPEG 导出。
- [ ] AC2：首屏显示生日信息，通过 GiftKit 读取合成回忆包并浏览照片，回到首页时编辑工程正确保留。
- [ ] AC3：下载浅、深色及放大字号截图，检查文案、焦点和布局，验证键盘能完成主流程。

## 实施要点

- 假设：在原型工作树复用 AppKit 画布和编辑会话，简体中文主界面提供「生日」「回忆」「修图」，修图首批操作按「选图」「裁剪」「调色」「保存」组织。保留打开工程与撤销快捷键，切换页面时持续持有当前编辑会话。
- 交付物：`app/Prototype/Editor/` 的中文原型入口，`app/compositor-prototype.yml` 的本地 SwiftPM 依赖与 UI 测试组。由 `GiftKit` 读取合成回忆包与日期，图片经本地文件访问，已编辑工程留在派生应用的文档边界。
- 验收：在 `xcode-27` 上重新执行原型构建和既有测试，再用 `xcodebuild -project IOSPSCompositorPrototype.xcodeproj -scheme CompositorPrototype -destination 'platform=macOS' test` 执行中文导航与编辑流程的 UI 检查。实际运行生成浅色、深色和放大字号 PNG，回读并对照易用性原则。原型代码继续留在隔离分支。

## 进度日志

- 2026-11-20：从 T-0008 细化，承接原 AC2 的界面与原 AC3 的生日和回忆验收。
