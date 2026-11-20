# ADR-0003：目标平台为 macOS

- 状态：**Accepted**
- 日期：2026-11-20
- 关联：[R02](../research/补充分析-iOS安装难度与Mac版方案.md)、[R03](../research/R03-fact-check-2026-11-20.md)、[ADR-0005](ADR-0005-distribution.md)、[ADR-0006](ADR-0006-shared-core-architecture.md)

## 决策

| 项 | 执行基线 |
|---|---|
| 目标平台 | 用户于 2026-11-20 确认 macOS。iOS 是否后补另行决定。 |
| 部署目标 | ⚠️ macOS 14.0：兼顾旧系统覆盖和前景分割能力。 |
| CPU 架构 | ⚠️ Apple 芯片 `arm64`：首版构建和验收只覆盖此架构。 |
| Compositor | 当前不纳入评估，T-0006 关闭。 |

D-07 回答后核对朋友 Mac 的芯片及系统。若遇到 Intel，先验证 Xcode 能否构建目标架构，再决定是否交付通用版。若系统低于 14.0，先确认可以升级，再评估降低部署目标所需的功能降级。即使符合 Compositor 条件，也要按功能缺口重新评估收益。

## 背景与后果

Mac 版适合键鼠和大屏编辑，可按 ADR-0005 直接交付。iOS 优先会增加分发前置条件，两端并行会分散首版投入。构建使用 macOS CI；工程只建 AppMac 壳，通用数据和业务逻辑按 ADR-0006 保持可移植。交付按目标机做 L4 验收。

## 修订记录

- 2026-11-20：用户确认按常见 M 系列 MacBook 做交付目标。首版仍构建 `arm64`，部署下限保持 macOS 14.0。选 MacBook Air M1、8 GB 做较低配置的性能参考。具体机型、内存和安装的系统版本由 T-0803 真机验收记录。[Apple M1 MacBook Air 技术规格](https://support.apple.com/en-ie/111883) · [Apple macOS Sonoma 兼容清单](https://support.apple.com/en-ie/105113)
