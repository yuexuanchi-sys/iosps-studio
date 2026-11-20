---
id: T-0006
title: （条件性）Compositor 复用评估
milestone: M0
status: dropped
priority: P2
modules: docs
features: F-07, F-08, F-21
depends: T-0003
verify: L0
owner: AI
updated: 2026-11-20
---

# T-0006 · Compositor 复用评估（spike）

## 目标
**仅当**选了 Mac 版、并且朋友的 Mac 是 Apple 芯片 + macOS 26 及以上时执行：评估 Compositor（MIT）中哪些代码 / 思路值得借用，避免重复造轮子。否则在 T-0003 中把本任务标为 `dropped`。

## 背景与依据
- [R02 §4](../docs/research/补充分析-iOS安装难度与Mac版方案.md)、[R03 §1.2](../docs/research/R03-fact-check-2026-11-20.md)、[ADR-0001](../docs/decisions/ADR-0001-native-swift-stack.md)

## 范围
**做：** 只读源码（把仓库下载到独立的临时目录，不在其中执行任何脚本 / 构建）；梳理：渲染管线、调整 / 滤镜实现、选区和主体选择（Vision）、撤销机制、工程文件格式；输出"可借用清单"（文件 / 函数、许可证要求、改造成本）。
**不做：** fork 它的界面；把它整个塞进本项目。

## 验收标准
- [ ] AC1：`docs/research/R04-compositor-reuse.md`：架构摘要 + 可借用清单（每项注明：用在哪个模块、改造成本、需要保留的版权声明）。
- [ ] AC2：明确结论：借用 / 只参考 / 不用，并说明理由。

## 进度日志
- 2026-11-20：创建（条件性）。
- 2026-11-20：D-07 尚无 Apple 芯片及 macOS 26+ 的确认，当前部署基线为 14.0，按 T-0003 条件关闭。
