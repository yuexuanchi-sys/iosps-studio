# ADR 架构决策记录

> ADR = Architecture Decision Record。每个"以后有人会问为什么这么做"的决定写一份。

## 索引

| ID | 标题 | 状态 | 日期 |
|---|---|---|---|
| [ADR-0001](ADR-0001-native-swift-stack.md) | 采用 Apple 原生 Swift 技术栈 | Accepted | 2026-11-20 |
| [ADR-0002](ADR-0002-no-ffmpeg.md) | 视频处理不使用 FFmpeg，只用 AVFoundation | Accepted | 2026-11-20 |
| [ADR-0003](ADR-0003-target-platform.md) | 目标平台为 macOS | Accepted | 2026-11-20 |
| [ADR-0004](ADR-0004-build-pipeline.md) | 构建流水线：Windows 写代码 + GitHub Actions macOS + XcodeGen | Proposed | 2026-11-20 |
| [ADR-0005](ADR-0005-distribution.md) | macOS 礼物分发 | Accepted | 2026-11-20 |
| [ADR-0006](ADR-0006-shared-core-architecture.md) | 跨平台核心 + 薄平台壳的分层架构 | Accepted | 2026-11-20 |

## 状态含义

- **Proposed**：方案已写好，等用户或前置条件确认；**不能基于它写代码**，但可以写文档和准备工作。
- **Accepted**：已确认，按它执行。
- **Superseded by ADR-XXXX**：被新决策替代，原文保留不删。
- **Rejected**：评估后放弃，原文保留，记录理由。

## 规则

1. 新 ADR 编号顺延，**不复用**；文件名 `ADR-NNNN-英文短横线标题.md`。
2. Accepted 之后不改正文，只能追加"修订记录"，或者新写一份 ADR 替代它。
3. 在本索引里登记；`tools/check_repo.py` 会检查索引和文件是否一致。

## 模板

```markdown
# ADR-NNNN：标题

- 状态：Proposed | Accepted | Superseded by ADR-XXXX | Rejected
- 日期：YYYY-MM-DD
- 关联：任务 / 功能 / 调研章节

## 背景
（为什么需要做这个决定，有哪些约束）

## 决策
（决定了什么，写成可执行的规则）

## 备选方案
| 方案 | 优点 | 缺点 | 结论 |

## 后果
（好处、代价、后续要做的事）

## 修订记录
- YYYY-MM-DD：…
```
