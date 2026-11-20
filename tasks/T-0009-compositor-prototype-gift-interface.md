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

## 进度日志

- 2026-11-20：从 T-0008 细化，承接原 AC2 的界面与原 AC3 的生日和回忆验收。
