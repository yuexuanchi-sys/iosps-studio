---
id: T-0001
title: 调研复核与项目库搭建
milestone: M0
status: done
priority: P0
modules: docs
features: none
depends: none
verify: L0
owner: AI
updated: 2026-11-20
---

# T-0001 · 调研复核与项目库搭建

## 目标
确认 DeepSeek 调研资料的可信度，并把仓库改造成可以持续接续任务的项目库（结构、文档、任务体系、工作流、自检工具）。

## 范围
**做：** 复核关键事实；整理调研文件；建立 CLAUDE.md / STATUS / BOARD / HANDOFF / ADR / PRD 草案 / 功能清单 / 模块卡 / 工作流文档；编写 `tools/check_repo.py`。
**不做：** 写任何 App 代码；替用户做平台决定；初始化 Git（需要用户授权）。

## 验收标准
- [x] AC1：16 个开源仓库的 License、★、归档状态复核完毕（R03 §1.1）。
- [x] AC2：Compositor 的系统要求从 README 原文确认（R03 §1.2）。
- [x] AC3：Xcode 27 / macOS 27 / GitHub runner / Gatekeeper 相关事实复核并给出来源（R03）。
- [x] AC4：调研文件移到 `docs/research/`，失效链接已修复，`md_to_docx.py` 的默认路径已更新。
- [x] AC5：项目库结构、文档、任务卡建立完毕。
- [x] AC6：L0：`python tools/check_repo.py` 0 error。

## 进度日志
- 2026-11-20：完成复核（GitHub API 匿名额度当天用完，后半段改用 raw.githubusercontent 和网页搜索）。建立项目库全部文档，自检通过。平台等 7 项决策交给 T-0002。
