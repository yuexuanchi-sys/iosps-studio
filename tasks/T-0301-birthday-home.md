---
id: T-0301
title: 主线生日主页与日期信息
milestone: M3
status: ready
priority: P0
modules: GiftKit, DesignSystem, AppMac
features: F-01
depends: T-0203, T-0305
verify: L0,L2,L3
owner: AI+用户
updated: 2026-11-21
---

# T-0301 · 主线生日主页与日期信息

## 目标

在主线 AppMac 的正常启动页接入可测试的本地日期模型和生日首页，保留 macOS 14.0。

## 背景与依据

- [产品需求](../docs/product/prd.md)、[易用性原则](../docs/product/ux-principles.md)、[生日日期逻辑](T-0305-gift-calendar.md)、[快照验证](T-0203-mac-snapshot-pipeline.md)。
- [隔离原型界面](T-0009-compositor-prototype-gift-interface.md) 提供三种外观的运行证据。

## 验收标准

- [ ] AC1：从 AppMac 正常启动，GiftKit 计算日期、倒计时、年龄和相识自然日。合成测试覆盖生日当天、缺失日期和 2 月 29 日。
- [ ] AC2：主线 CI 输出浅色、深色和放大字号 PNG，下载后核对文字、缩放和键盘可达性。

## 实施要点

- 假设：AppMac 注入当天和回忆包日期，DesignSystem 接收渲染所需数值。缺失日期显示祝福和引导。真实素材由 T-0104 与回忆任务接入。
- 在 `app/Apps/Mac/` 接入口，在 DesignSystem 更新生日页与快照，在 AppMac 宿主测试固定日期。预期 `swift test --package-path app` 和 AppMac scheme 测试零失败，三种尺寸与样式的 PNG 可回读。

## 进度日志

- 2026-11-21：从看板细化，等待 T-0203 快照基础。
