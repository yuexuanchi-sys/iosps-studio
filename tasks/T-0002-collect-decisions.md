---
id: T-0002
title: 关键决策收集（D-01 ~ D-07）
milestone: M0
status: blocked
priority: P0
modules: docs
features: none
depends: T-0001
verify: L0
owner: AI+用户
updated: 2026-11-20
---

# T-0002 · 关键决策收集

## 目标
拿到用户对 D-01 ~ D-07 的回答，写进 STATUS 和相关文档，解除 M1 及以后任务的阻塞。

## 背景与依据
- 问题清单：[STATUS.md 待用户决策](../STATUS.md)
- 分析依据：[R03 §4](../docs/research/R03-fact-check-2026-11-20.md)、[ADR-0003](../docs/decisions/ADR-0003-target-platform.md)、[ADR-0005](../docs/decisions/ADR-0005-distribution.md)

## 范围
**做：** 向用户解释每个问题的影响，记录答案；答案不完整时，给出推荐默认值并请用户确认。
**不做：** 定稿 ADR（那是 T-0003）。

## 验收标准
- [ ] AC1：D-01 ~ D-07 每一项都有答案或明确的"暂定默认值"，记录在 STATUS.md（状态改为 ✅ 或 ⚠️暂定）。
- [ ] AC2：生日日期（D-02）写进 charter.md §6，并倒排出里程碑的粗略日期。
- [x] AC3：如果 D-05 授权了 Git，同步更新 CLAUDE.md「会话结束」第 6 步和 conventions.md。证据：两处均链接 STATUS 的 D-05 并注明授权范围。
- [ ] AC4：L0：check_repo 通过。

## 需要用户提供 / 确认
- D-01 ~ D-07 的答案（见 STATUS.md）。D-07 的查看方法：Mac → 左上角苹果菜单 →「关于本机」，看「芯片」和「macOS」版本；iPhone → 设置 → 通用 → 关于本机 →「iOS 版本」。**问朋友时注意别剧透。**

## 进度日志
- 2026-11-20：创建；已在会话中向用户提出问题，等待回答。
- 2026-11-20：用户回答 D-01 = **macOS**。D-02、D-03、D-06、D-07 先按默认值推进（见 STATUS，标 ⚠️ 暂定）；D-04、D-05 未回答 → 状态改为 `blocked`，不阻塞 T-0003 及 M1 文档类任务。
- 2026-11-20：用户确认 D-07 按常见 M 系列 MacBook 开发。选 M1 MacBook Air、8 GB 作为性能参考；部署目标仍为 macOS 14.0。准确机型和当前系统版本在 T-0803 记录。
- 2026-11-20：用户确认 D-04 为私有，并授予 D-05 首次上传及本轮 CI 修复与后续任务的 Git 权限。已同步 STATUS、构建 ADR 和 Git 约定。
