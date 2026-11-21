---
id: T-0801
title: 主线 Mac 签名与 ZIP 交付
milestone: M8
status: ready
priority: P0
modules: infra
depends: T-0003, T-0202
verify: L0,L2
owner: AI
updated: 2026-11-21
---

# T-0801 · 主线 Mac 签名与 ZIP 交付

## 目标

在主线 macOS 14.0／arm64 交付链上核对每份候选 ZIP 的完整性、签名与许可。

## 背景与依据

- [分发决定](../docs/decisions/ADR-0005-distribution.md)、[主线 CI](T-0202-mac-ci-pipeline.md)、[验证矩阵](../docs/workflow/verification.md)。
- [隔离原型离线验收](T-0010-compositor-prototype-offline-movie.md) 的签名及解包检查可供复用。

## 验收标准

- [ ] AC1：主线 CI 压缩实际 arm64 Release App，核对 macOS 14.0、ad-hoc 签名、精确权限、完整许可和 SHA-256。
- [ ] AC2：下载候选 ZIP 后重算 SHA-256 并检查包体，CI 在解包后运行 `codesign --verify --deep --strict`。任务卡记录 SHA、run 与产物路径。

## 实施要点

- 假设：D-03 继续采用 M-0。CI 重用 T-0202 的 macOS runner 和包产物，增加部署版本与权限断言。首开、安全提示和目标机体验由 T-0802、T-0803 验收。
- 影响 `.github/workflows/ci.yml`、主线 App 签名设置和许可文档。预期主线 `xcodebuild … -configuration Release build`、解包签名和 SHA-256 比对均成功。

## 进度日志

- 2026-11-21：从看板细化，保留原分发门槛。
