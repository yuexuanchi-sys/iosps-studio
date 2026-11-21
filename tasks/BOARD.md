# 任务看板（BOARD）

> 任务状态的**索引**。状态必须和任务卡 front matter 一致（`python tools/check_repo.py` 会检查）。
> 状态：`backlog` 待细化（没有卡片）· `ready` 可开工 · `in-progress` 进行中（最多 1 个）· `blocked` 卡住 · `review` 待用户验收 · `done` 完成 · `dropped` 放弃。
> 规则详见 [docs/workflow/task-system.md](../docs/workflow/task-system.md)。**最小礼物路径**：M0 → M1 → M2 → M3 → M4 → M5 → M8。

## M0 决策与环境

| ID | 标题 | 状态 | 优先级 | 模块 | 依赖 | 功能 |
|---|---|---|---|---|---|---|
| [T-0001](T-0001-research-review-and-repo-setup.md) | 调研复核与项目库搭建 | done | P0 | docs | none | — |
| [T-0002](T-0002-collect-decisions.md) | 关键决策收集（D-01 ~ D-07） | blocked | P0 | docs | T-0001 | — |
| [T-0003](T-0003-finalize-platform-and-distribution.md) | 平台与分发 ADR 定稿 | done | P0 | docs | T-0001 | — |
| [T-0004](T-0004-git-and-github-setup.md) | Git 初始化 + GitHub 仓库 + gh CLI | done | P0 | infra | T-0001 | — |
| [T-0005](T-0005-ci-smoke-test.md) | CI 冒烟测试：云端 macOS 构建出最小 App | done | P0 | infra | T-0003, T-0004 | — |
| [T-0006](T-0006-compositor-reuse-spike.md) | Compositor 修图底座只读预评估 | done | P0 | docs | T-0003, T-0005 | F-07, F-08, F-13, F-14, F-21 |
| [T-0007](T-0007-windows-swift-toolchain.md) | Windows 本地 Swift 工具链（L1 本地测试） | blocked | P1 | infra | none | — |
| [T-0008](T-0008-compositor-integrated-prototype.md) | Compositor 派生编辑器构建与回归 | done | P0 | AppMac, GiftKit, MediaIO, VideoEngine | T-0006, T-0202 | F-01, F-02, F-07, F-08, F-13, F-14, F-15 |
| [T-0009](T-0009-compositor-prototype-gift-interface.md) | Compositor 原型中文编辑、生日和回忆 | review | P0 | AppMac, DesignSystem, GiftKit, MediaIO | T-0008 | F-01, F-02, F-07, F-08, F-13, F-14 |
| [T-0010](T-0010-compositor-prototype-offline-movie.md) | Compositor 原型短片和离线真机验收 | blocked | P0 | AppMac, MediaIO, TemplateKit, TimelineKit, VideoEngine | T-0009, T-0501 | F-13, F-15 |

## M1 产品定义

| ID | 标题 | 状态 | 优先级 | 模块 | 依赖 | 功能 |
|---|---|---|---|---|---|---|
| [T-0101](T-0101-finalize-prd.md) | PRD 定稿 | review | P0 | docs | T-0003 | 全部 |
| [T-0102](T-0102-ux-flows-and-wireframes.md) | 交互流程与线框图 | review | P0 | docs | T-0101 | 全部 |
| [T-0103](T-0103-visual-style-and-assets-policy.md) | 视觉风格、命名图标、素材规范 | review | P0 | DesignSystem, Assets | T-0101 | F-26 |
| [T-0104](T-0104-gift-content-checklist.md) | 礼物素材清单与收集 | blocked | P0 | GiftKit | T-0101 | F-01 ~ F-05 |

## M2 工程骨架与 CI

| ID | 标题 | 状态 | 优先级 | 模块 | 依赖 | 功能 |
|---|---|---|---|---|---|---|
| [T-0201](T-0201-mac-project-scaffold.md) | 多模块工程骨架（Package.swift + XcodeGen project.yml + Mac 祝福首屏 + L1 import 检查） | done | P0 | 全部 | T-0003 | — |
| [T-0202](T-0202-mac-ci-pipeline.md) | CI 正式流水线：swift test + xcodebuild test + 打包产物 | done | P0 | infra | T-0201 | — |
| [T-0203](T-0203-mac-snapshot-pipeline.md) | 截图验证管线（快照测试 → artifact → 本地下载查看） | done | P0 | DesignSystem, infra | T-0202 | — |
| [T-0204](T-0204-birthday-core-projects-and-history.md) | BirthdayCore：工程模型 + 命令 / 撤销栈 + 草稿协议 | done | P0 | BirthdayCore | T-0201 | F-14 |
| [T-0205](T-0205-media-import-and-storage.md) | MediaIO：Finder 选图、拖入与权限验收 | ready | P0 | MediaIO | T-0201, T-0207 | F-06 |
| [T-0206](T-0206-file-draft-store.md) | MediaIO：草稿原子替换与恢复 | done | P0 | MediaIO | T-0204 | F-14 |
| [T-0207](T-0207-local-media-library.md) | MediaIO：本地素材库与缩略图 | in-progress | P0 | MediaIO | T-0201 | F-06 |

## M3 礼物体验

| ID | 标题 | 状态 | 优先级 | 模块 | 依赖 | 功能 |
|---|---|---|---|---|---|---|
| [T-0301](T-0301-birthday-home.md) | 生日主页 + 倒计时 / 年龄 / 相识天数 | ready | P0 | GiftKit, DesignSystem, App | T-0203, T-0305 | F-01 |
| T-0302 | 回忆时间轴（memories.json + 照片墙） | backlog | P0 | GiftKit, MediaIO, App | T-0301, T-0104, T-0306 | F-02 |
| T-0303 | 彩蛋 + 生日当天全屏祝福动画 | backlog | P0 | GiftKit, DesignSystem | T-0301, T-0306 | F-03, F-05 |
| T-0304 | 生日歌 / 语音祝福播放 | backlog | P0 | GiftKit, App | T-0301, T-0104, T-0306 | F-04 |

| [T-0305](T-0305-gift-calendar.md) | GiftKit 公历生日、倒计时与相识自然日 | done | P0 | GiftKit | T-0201 | F-01, F-05 |
| [T-0306](T-0306-gift-manifest.md) | GiftKit 回忆包清单校验与排序 | done | P0 | GiftKit | T-0201, T-0305 | F-02, F-03, F-04 |

## M4 照片编辑

T-0401 及其依赖链的新增自研修图引擎暂停，等待 [D-12](../STATUS.md) 的原型证据与正式迁移决定。

| ID | 标题 | 状态 | 优先级 | 模块 | 依赖 | 功能 |
|---|---|---|---|---|---|---|
| T-0401 | 编辑器框架：画布、预览代理图、配方模型、撤销接入 | backlog | P0 | ImageEngine, BirthdayCore, App | T-0204, T-0205, T-0206 | F-14 |
| T-0402 | 裁剪 / 旋转 / 翻转 / 比例 | backlog | P0 | ImageEngine | T-0401 | F-07 |
| T-0403 | 基础调整（亮度、对比度、饱和度等 8 项） | backlog | P0 | ImageEngine | T-0401 | F-08 |
| T-0404 | 滤镜预设（LUT 生成 + 12 个预设） | backlog | P0 | ImageEngine, Assets | T-0403 | F-09 |
| T-0405 | 文字工具 | backlog | P0 | ImageEngine, DesignSystem | T-0401 | F-10 |
| T-0406 | 贴纸工具 + 生日贴纸包 | backlog | P0 | ImageEngine, Assets | T-0405 | F-11 |
| T-0407 | 涂鸦 + 马赛克 | backlog | P0 | ImageEngine | T-0401 | F-12 |
| T-0408 | 原图分辨率导出 + 保存 / 分享 | backlog | P0 | ImageEngine, MediaIO | T-0401 | F-13 |

## M5 一键回忆短片

| ID | 标题 | 状态 | 优先级 | 模块 | 依赖 | 功能 |
|---|---|---|---|---|---|---|
| [T-0501](T-0501-memory-templates-and-timeline.md) | 短片模板格式（TemplateKit）+ 时间轴模型（TimelineKit） | done | P0 | TemplateKit, TimelineKit | T-0204 | F-15 |
| T-0502 | 照片转视频渲染器（Ken Burns，AVAssetWriter） | backlog | P0 | VideoEngine | T-0501 | F-15 |
| T-0503 | 转场 + 文字叠加 | backlog | P0 | VideoEngine | T-0502 | F-15 |
| T-0504 | 音乐：时长 / 节拍分配、淡入淡出 | backlog | P0 | TimelineKit, VideoEngine | T-0502 | F-15 |
| T-0505 | 预览 + 导出（进度、取消、失败恢复） | backlog | P0 | VideoEngine, App | T-0503, T-0504 | F-15 |
| T-0506 | 8 个模板内容 + 短片界面流程 | backlog | P0 | Assets, App | T-0505 | F-15 |

## M6 视频剪辑

| ID | 标题 | 状态 | 优先级 | 模块 | 依赖 | 功能 |
|---|---|---|---|---|---|---|
| T-0601 | 剪辑时间轴模型与命令（分割 / 删除 / 排序） | backlog | P1 | TimelineKit | T-0501 | F-16 |
| T-0602 | 多段导入拼接 + 裁剪界面 | backlog | P1 | VideoEngine, App | T-0601, T-0505 | F-16 |
| T-0603 | 变速 | backlog | P1 | TimelineKit, VideoEngine | T-0602 | F-17 |
| T-0604 | 转场 | backlog | P1 | VideoEngine | T-0602 | F-18 |
| T-0605 | BGM / 原声混合 / 录音配音 | backlog | P1 | VideoEngine | T-0602 | F-19 |
| T-0606 | 字幕 / 文字 | backlog | P1 | VideoEngine | T-0602 | F-20 |

## M7 增强功能

| ID | 标题 | 状态 | 优先级 | 模块 | 依赖 | 功能 |
|---|---|---|---|---|---|---|
| T-0701 | 一键抠图 + 换背景（Vision） | backlog | P1 | ImageEngine | T-0401 | F-21 |
| T-0702 | 生日海报 / 贺卡模板 | backlog | P1 | TemplateKit, ImageEngine | T-0405, T-0406 | F-22 |
| T-0703 | 美颜（磨皮 / 美白） | backlog | P1 | ImageEngine | T-0403 | F-23 |
| T-0704 | 拼图 | backlog | P1 | TemplateKit, ImageEngine | T-0401 | F-24 |
| T-0705 | Mac 全屏生日模式 | backlog | P1 | App | T-0301 | F-25 |
| T-0706 | 开源许可 / 素材致谢页 | backlog | P0 | DesignSystem, Assets | T-0201 | F-26 |

## M8 打包分发与交付

| ID | 标题 | 状态 | 优先级 | 模块 | 依赖 | 功能 |
|---|---|---|---|---|---|---|
| [T-0801](T-0801-mac-release-zip.md) | Mac 签名与打包（ZIP，可选公证） | ready | P0 | infra | T-0003, T-0202 | — |
| T-0802 | 图文安装说明 | backlog | P0 | docs | T-0801 | — |
| T-0803 | 目标设备验收（L4 清单） | backlog | P0 | 全部 | T-0801 | — |
| T-0804 | 礼物交付与生日当天预案 | backlog | P0 | docs | T-0803 | — |
