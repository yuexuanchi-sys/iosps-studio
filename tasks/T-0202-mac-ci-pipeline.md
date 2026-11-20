---
id: T-0202
title: macOS 正式测试和 CI 打包
milestone: M2
status: in-progress
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

## 实施要点

- 假设：沿用 run 44775125352 已实测的 `macos-26`、XcodeGen 2.48.0、arm64 ad-hoc 签名，runner 实际工具版本继续打印。私有仓库在目标为 `main` 的 PR、`main` 上的代码／构建配置变更以及手动 dispatch 时运行。
- 交付物：`.github/workflows/ci.yml` 的常规测试与 ZIP；`app/project.yml` 的 AppMac 测试目标和 `app/Tests/AppMacTests/AppMacTests.swift`。先写 App-hosted 测试，核验 bundle 标识和 DesignSystem 资源可从正常主包访问。使用 Debug 跑 `xcodebuild test`，已有 Release App 单独签名并打包。修改验证文档与本卡，L3 快照扩展由 T-0203 完成。
- 验收：`python tools/check_repo.py` 为 0 error，YAML 结构与 Bash 语法通过；推送代码后的实际 run 的事件为 `push`，`swift test --package-path app` 47 通过，AppMac XCTest 执行 1 次且 0 失败，AppMac Release 成功；解包后 `codesign --verify --deep --strict`、本地 ZIP 结构、arm64 和 SHA-256 均通过。上传路径为指定产物文件，checkout 无持久凭据，workflow 只读仓库内容且不引用密钥。

## 进度日志
- 2026-11-20：从看板滚动细化。
