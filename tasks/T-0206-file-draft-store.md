---
id: T-0206
title: MediaIO 草稿原子替换与恢复
milestone: M2
status: done
priority: P0
modules: MediaIO
features: F-14
depends: T-0204
verify: L0,L2
owner: AI
updated: 2026-11-20
---

# T-0206 · MediaIO 草稿原子替换与恢复

## 目标

保存完整 Project 草稿，支持重新打开后恢复，区分缺失和读取失败。

## 背景与依据

- [工程草稿契约](T-0204-birthday-core-projects-and-history.md)、[PRD F-14](../docs/product/prd.md)、[模块卡](../docs/architecture/modules.md)。

## 验收标准

- [x] AC1：按项目 UUID 保存草稿，实例重新打开后恢复；没有文件时返回 nil。 证据见下方 run 44775125352。
- [x] AC2：同一项目重复写入和并发写入只产生完整快照；不同工程彼此独立。保存失败可报告给调用方。 证据见下方 run 44775125352。
- [x] AC3：损坏的 JSON 和与文件名不符的工程 ID 返回错误。 证据见下方 run 44775125352。
- [x] AC4：macOS 运行 `swift test --package-path app --filter FileDraftStoreTests`，全部通过。 证据见下方 run 44775125352。

## 实施要点

- 假设：草稿根目录由 App 提供，每个文件保存单个 Project，文件名使用工程 UUID，应用级单例 actor 串行化操作。
- 先写测试再实现 MediaIO 目标。使用 `Data.write(to:options: .atomic)` 替换文件，错误直接传播。[Apple 文件写入文档](https://developer.apple.com/documentation/technologyoverviews/files-and-directories)
- T-0204 的协议与数据类型已在工作区，可先为其编写适配，验收仍等 T-0204 和 macOS CI。

## 进度日志

- 2026-11-20：从 T-0205 拆出草稿存储与原验收要求，启动切片。
- 2026-11-20：`FileDraftStore`、SwiftPM 接线和 6 个测试已写齐，待验证（L2）。人工核对 actor 隔离、原子替换、UUID 核对及失败传播，无新增外部依赖。当前 Windows 找不到 `swift`，而该目标在 macOS；在 CI 运行 `swift test --package-path app --filter FileDraftStoreTests`，预期 6 个测试、0 失败，再逐项验收。
- 2026-11-20：静态扫描确认 macOS SwiftPM 目标及测试依赖已声明，app 内无实现占位符；`python tools/check_repo.py` 为 0 error。
- 2026-11-20：[run 44775125352](https://github.com/yuexuanchi-sys/iosps-studio/actions/runs/44775125352) 的 `swift test --package-path app`：`FileDraftStoreTests` 6/6，涵盖重新打开、并发、隔离、失败传播和损坏文档。 自查通过：验收及依赖已核对，L0 0 error，无实现占位符、越层依赖或新增未登记依赖／素材，模块、ADR 与看板同步。
