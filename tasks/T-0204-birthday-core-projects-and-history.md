---
id: T-0204
title: BirthdayCore 工程、撤销与草稿协议
milestone: M2
status: blocked
priority: P0
modules: BirthdayCore
features: F-14
depends: T-0201
verify: L0,L1
owner: AI
updated: 2026-11-20
---

# T-0204 · BirthdayCore 工程、撤销与草稿协议

## 目标
定义可保存的编辑工程和纯逻辑命令历史，让照片和短片有统一的草稿边界。

## 背景与依据
- [模块卡](../docs/architecture/modules.md)、[PRD F-14](../docs/product/prd.md)、[ADR-0006](../docs/decisions/ADR-0006-shared-core-architecture.md)。

## 范围
带版本的照片／视频工程、相对媒体 ID、可失败的命令和 20 步默认历史、异步草稿协议。具体图像配方在 T-0401 延展，视频时间轴在 T-0501 延展，磁盘草稿库在 T-0205 实现。

## 验收标准
- [ ] AC1：两类工程可用 Codable 无损往返，未知版本拒绝，素材顺序保留。
- [ ] AC2：空历史、20 步上限、撤销重做、分支编辑、失败原子性有单测。
- [x] AC3：DraftStore 定义按工程 ID 加载及保存整份快照的异步契约，跨隔离域可用。 证据：DraftStore.swift 明确整份快照、原子替换、缺失与 I/O 错误区分，接口和 Project 具备 Sendable 约束。
- [ ] AC4：`swift test --package-path app` 通过。

## 实施要点
- 假设：草稿工程 v1 以明确 kind 区分照片和视频，媒体用本地库解析的 UUID 引用，视频空序列可作为新草稿。\n- 先写编解码和历史反例测试，再实现 Project、UndoStack、DraftStore；磁盘实现交由 T-0205。

## 进度日志
- 2026-11-20：从看板滚动细化。
- 2026-11-20：代码与 10 个相关单测已写齐，待验证（L1）。`swift test --package-path app` 在当前机找不到 swift；工具链或 CI 可用后运行，预期 ProjectTests 和 UndoStackTests 共 10 用例、0 失败，再核对 AC1/AC2/AC4。L0 为 0 error；人工检查了 Codable、泛型命令状态副本和 Sendable。
