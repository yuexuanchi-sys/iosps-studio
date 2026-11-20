---
id: T-0010
title: Compositor 原型短片和离线真机验收
milestone: M0
status: ready
priority: P0
modules: AppMac, MediaIO, TemplateKit, TimelineKit, VideoEngine
features: F-13, F-15
depends: T-0009, T-0501
verify: L0,L2,L3,L4
owner: AI+用户
updated: 2026-11-20
---

# T-0010 · Compositor 原型短片和离线真机验收

## 目标

验证派生编辑器导出照片进入 IOSPS 短片，以及派生 App 的离线交付。

## 背景与依据

- [R04](../docs/research/R04-compositor-reuse.md)、[T-0009](T-0009-compositor-prototype-gift-interface.md)、[ADR-0005](../docs/decisions/ADR-0005-distribution.md)。

## 验收标准

- [ ] AC1：将派生编辑器导出结果登记为 `MediaID`，以虚构素材和单模板导出可播放的 3 秒／30 fps／90 帧无声 MP4，回读帧率、帧数和时长。
- [ ] AC2：下载并校验最终原型 ZIP 的签名、SHA-256、权限与许可。目标机断网首开，完成修图和短片导出，退出重开可恢复。
- [ ] AC3：用 12 MP 合成照片记录等待时间和峰值内存，分别注明 CI、参考机与目标机环境。

## 进度日志

- 2026-11-20：从 T-0008 细化，承接原 AC3 的短片与原 AC4 的目标机验收。
