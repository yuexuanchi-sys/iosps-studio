---
id: T-0202
title: macOS 正式测试和 CI 打包
milestone: M2
status: ready
priority: P0
modules: infra
features: none
depends: T-0201
verify: L0,L1,L2
owner: AI
updated: 2026-11-20
---

# T-0202 · macOS 正式测试和 CI 打包

## 目标
从冒烟 run 推导可重复的常规测试及构建产物流程。

## 背景与依据
- [ADR-0004](../docs/decisions/ADR-0004-build-pipeline.md)、[验证矩阵](../docs/workflow/verification.md)、[T-0005](T-0005-ci-smoke-test.md)。

## 范围
复用冒烟流程，定稿触发条件和权限，运行 L0/L1 与 macOS build/test，打包并上传可校验的产物。正式配置取首个已实测的 runner、工具版本和耗时为基准。

## 验收标准
- [ ] AC1：CI 对代码变更自动运行，日志包含 L0、L1、AppMac 构建和测试。
- [ ] AC2：签名与 ZIP 校验通过，artifact 可下载；任务卡记录成功 run 和耗时。
- [ ] AC3：CI 权限、上传清单和密钥范围通过核对。

## 进度日志
- 2026-11-20：从看板滚动细化。
