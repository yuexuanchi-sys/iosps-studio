---
id: T-0006
title: Compositor 修图底座只读预评估
milestone: M0
status: review
priority: P0
modules: docs
features: F-07, F-08, F-13, F-14, F-21
depends: T-0003, T-0005
verify: L0
owner: AI
updated: 2026-11-20
---

# T-0006 · Compositor 修图底座只读预评估

## 目标

评估能否优先复用 Compositor 的画布、裁剪、调色和导出，并接入简单中文界面、生日主页、回忆与一键短片。比较以 Compositor 为应用主体和以 IOSPS 为应用主体的两条路线。

## 背景与依据

- [R02 §4](../docs/research/补充分析-iOS安装难度与Mac版方案.md)、[R03 §1.2](../docs/research/R03-fact-check-2026-11-20.md)、[ADR-0001](../docs/decisions/ADR-0001-native-swift-stack.md)、[ADR-0003](../docs/decisions/ADR-0003-target-platform.md)、[ADR-0005](../docs/decisions/ADR-0005-distribution.md)。

## 范围

固定并只读审阅上游源码。梳理平台、画布、裁剪、调整、导出、Vision、撤销和工程文件，比较中文界面改造、生日与视频模块接入、许可及离线打包的代价。外部源码仅在独立临时目录阅读。正式迁移和部署目标变更等待用户确认，T-0401 及依赖它的自研修图代码暂缓开始。

## 验收标准

- [x] AC1：[R04](../docs/research/R04-compositor-reuse.md) 固定源码 `4a17b264`，比发行 `v1.6.14` 多一笔 appcast 更新。项目工程、画布、裁剪、滤镜、导出、历史和许可均附源码证据。
- [x] AC2：[R04 两条路线](../docs/research/R04-compositor-reuse.md#两条路线) 比较了中文编辑器、IOSPS 模块接入、维护和离线分发。若目标机可用 26+，优先验证完整继承；保留 14.0 时优先 IOSPS 定点复用。
- [x] AC3：本卡与 [STATUS](../STATUS.md) 记录 D-12 和原型验收门槛，[R04](../docs/research/R04-compositor-reuse.md#最小原型验收门槛) 给出验证层级与证据。静态复核和 L0 自查见进度日志。

## 实施要点

- 假设：产品基线为 macOS 14.0／arm64，完整继承的设备条件待确认。
- 用 `gh api` 核对仓库、发布和提交。下载固定 SHA 源码到独立临时目录，读取 Xcode 工程、依赖锁、关键实现和发行配置，仅改评估、ADR 修订记录和任务状态。运行 `python tools/check_repo.py`，预期 0 error。

## 最小原型与决策

- D-12 先由用户确认目标 Mac 实际 macOS 版本、是否接受 26.0 下限，以及先试哪条路线。A 在授权后用隔离分支验证完整编辑器，B 在现有模块边界验证兼容片段。
- 原型通过标准为 arm64／Swift 6 Release 和既有 47 个基线测试通过；合成样本经简体中文入口完成画布操作、裁剪、曝光、饱和度、撤销与 PNG/JPEG 导出；导出进入回忆短片，3 秒／30 fps MP4 可播放；断网打开已校验签名的 ZIP、编辑、保存并重开。详见 [R04](../docs/research/R04-compositor-reuse.md#最小原型验收门槛)。
- 上游 Swift 5 模式、macOS 26 专有 API、专业 UI 耦合、色表来源及网络组件需在原型逐条验证。现有 IOSPS 证据来自 run 44775125352。上游源码仅作静态审阅。

## 进度日志

- 2026-11-20：创建（条件性）。
- 2026-11-20：D-07 尚无 Apple 芯片及 macOS 26+ 的确认，当前部署基线为 14.0，按 T-0003 条件关闭。
- 2026-11-20：用户要求优先评估 Compositor。T-0005 已到 `success` 并回读产物，重开本卡。用户确认前保留部署基线与现有代码，暂缓自研修图引擎。
- 2026-11-20：完成源码和许可核对，汇总两条路线与四组原型验收，进入 `review` 等 D-12。自查通过：三项静态验收有证据；应用和 CI 配置无差异，未引入实现占位符、依赖或资源；研究索引、ADR 修订记录、STATUS 和 BOARD 已同步；`python tools/check_repo.py` 为 0 error。
