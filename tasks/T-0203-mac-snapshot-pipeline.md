---
id: T-0203
title: macOS 快照验证管线
milestone: M2
status: in-progress
priority: P0
modules: DesignSystem, infra
features: none
depends: T-0202
verify: L0,L3
owner: AI
updated: 2026-11-21
---

# T-0203 · macOS 快照验证管线

## 目标
让 CI 对共享 UI 产生可下载、可检查的固定尺寸快照。

## 背景与依据
- [验证矩阵](../docs/workflow/verification.md)、[易用性原则](../docs/product/ux-principles.md)、[T-0005](T-0005-ci-smoke-test.md)。

## 验收标准
- [ ] AC1：复用实测成功的冒烟快照入口，用虚构数据分别渲染浅色、深色和放大字号。
- [ ] AC2：CI 上传实际 PNG，下载到 artifacts/ 后逐图检查焦点、对比度、文本和布局，给出 run 与文件路径。

## 实施要点

- 假设：用 T-0005 的生日文案作为合成首屏，固定 1280×800，无需素材。浅色、深色用实际配色环境，放大组用显式字号。当前首屏只有静态标题，页面加入交互控件时再检查其焦点状态。
- 先在 `.github/workflows/ci.yml` 写三张 PNG 的尺寸与差异检查，保留 720×480 冒烟输出。再扩展 `app/Sources/BirthdaySmokeSnapshot/BirthdaySmokeSnapshot.swift` 的目录模式和 `app/Sources/DesignSystem/BirthdayGreetingView.swift` 的字号输入。
- 验收：`swift run --package-path app BirthdaySmokeSnapshot --variants "$RUNNER_TEMP/snapshots"`，三张 1280×800 PNG，三组摘要不同。CI 使用 `macos-26` runner，AppMac 仍以 macOS 14.0／arm64 构建。下载 `iosps-macos-build` 后逐图看文字、对比度、尺寸与布局。

## 进度日志
- 2026-11-20：从看板滚动细化。
- 2026-11-21：[run 44921911658](https://github.com/yuexuanchi-sys/iosps-studio/actions/runs/44921911658)（`4eaa479df6431c07497c701552b57d7b0ece6a2e`）保留 720×480 冒烟输出，并按预期在新增的 `--variants` 路径报 `SnapshotError.missingOutputPath`。日志 `artifacts/snapshots/44921911658/failed.log`。
