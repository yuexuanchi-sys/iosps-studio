---
id: T-0003
title: 平台与分发 ADR 定稿
milestone: M0
status: done
priority: P0
modules: docs
features: none
depends: T-0001
verify: L0
owner: AI
updated: 2026-11-20
---

# T-0003 · 平台与分发 ADR 定稿

## 目标
根据 T-0002 的答案，把 ADR-0003（平台）和 ADR-0005（分发）从 Proposed 改为 Accepted，并把平台相关的信息同步到所有文档。

## 范围
**做：**
- ADR-0003：填写「决策」「后果」，确定部署目标（iOS 17.0 / macOS 版本）。
- ADR-0005：填写「决策」（Mac M-0 / M-1，或 iOS 的 TestFlight → Unlisted）。
- 同步：features.md 平台列、PRD §3 信息架构的平台形态、architecture/overview.md §4、modules.md 中 AppMac / AppiOS 的状态、ADR 索引、BOARD 中平台相关的 backlog 标题（例如 T-0705、T-0801）。
- 如果选了 Mac 且朋友的 Mac ≥ macOS 26 + Apple 芯片：把 T-0006 设为下一步；否则把 T-0006 标 `dropped`。

**不做：** 写代码。

## 验收标准
- [x] AC1：ADR-0003、ADR-0005 状态为 Accepted，「决策」一节可以直接执行。 证据：ADR-0003 与 ADR-0005 的决策和复核条件各有执行表述。
- [x] AC2：上面列出的同步项全部更新，文档之间没有矛盾（人工通读 + check_repo）。 证据：人工核对功能平台列、PRD §3、架构 §4、模块卡、ADR 索引及看板 T-0705/T-0801；check_repo 0 error。
- [x] AC3：STATUS.md 里 D-01 为 ✅；D-03、D-07 为 ✅（用户已答）或 ⚠️ 暂定（按默认值推进，并且在 ADR 里写明"用户回答后需要复核的点"）。 证据：STATUS 的 D-01、D-03、D-07 与两份 ADR 一致。
- [x] AC4：L0：check_repo 通过。 证据：`python tools/check_repo.py` 0 error、0 warning。

## 实施要点
- 假设：采用 Apple 芯片、macOS 14.0 和 M-0（D-03、D-07 未答，先按低成本路径推进）。
- 定稿平台与分发 ADR，统一功能、导航、架构、构建文档和看板，再逐项核对。

## 进度日志
- 2026-11-20：创建。
- 2026-11-20：用户已决定 D-01 = macOS，本任务不再等 T-0002，依赖改为 T-0001；D-03 / D-07 按 STATUS 的暂定默认值写，标 ⚠️。
- 2026-11-20：自查通过：AC1–AC4 已取证，相关文档已同步。文档切片未引入代码、依赖或素材。
- 2026-11-20：用户后来重开 T-0006 做只读预评估。部署目标仍按 ADR-0003，正式迁移或提高下限待 D-12。
