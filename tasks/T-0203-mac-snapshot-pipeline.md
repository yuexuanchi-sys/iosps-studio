---
id: T-0203
title: macOS 快照验证管线
milestone: M2
status: ready
priority: P0
modules: DesignSystem, infra
features: none
depends: T-0202
verify: L0,L3
owner: AI
updated: 2026-11-20
---

# T-0203 · macOS 快照验证管线

## 目标
让 CI 对共享 UI 产生可下载、可检查的固定尺寸快照。

## 背景与依据
- [验证矩阵](../docs/workflow/verification.md)、[易用性原则](../docs/product/ux-principles.md)、[T-0005](T-0005-ci-smoke-test.md)。

## 验收标准
- [ ] AC1：复用实测成功的冒烟快照入口，用虚构数据分别渲染浅色、深色和放大字号。
- [ ] AC2：CI 上传实际 PNG，下载到 artifacts/ 后逐图检查焦点、对比度、文本和布局，给出 run 与文件路径。

## 进度日志
- 2026-11-20：从看板滚动细化。
