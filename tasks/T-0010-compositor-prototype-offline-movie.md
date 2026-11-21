---
id: T-0010
title: Compositor 原型短片和离线真机验收
milestone: M0
status: in-progress
priority: P0
modules: AppMac, MediaIO, TemplateKit, TimelineKit, VideoEngine
features: F-13, F-15
depends: T-0009, T-0501
verify: L0,L2,L3,L4
owner: AI+用户
updated: 2026-11-21
---

# T-0010 · Compositor 原型短片和离线真机验收

## 目标

验证派生编辑器导出照片进入 IOSPS 短片，以及派生 App 的离线交付。

## 背景与依据

- [R04](../docs/research/R04-compositor-reuse.md)、[T-0009](T-0009-compositor-prototype-gift-interface.md)、[ADR-0005](../docs/decisions/ADR-0005-distribution.md)、[原型离线清单](../docs/workflow/prototype-offline-acceptance.md)。

## 验收标准

- [ ] AC1：将派生编辑器导出结果登记为 `MediaID`，以虚构素材和单模板导出可播放的 3 秒／30 fps／90 帧无声 MP4，回读帧率、帧数和时长。
- [ ] AC2：下载并校验最终原型 ZIP 的签名、SHA-256、权限与许可。目标机断网首开，完成修图和短片导出，退出重开可恢复。
- [ ] AC3：用 12 MP 合成照片记录等待时间和峰值内存，分别注明 CI、参考机与目标机环境。

## 实施要点

- 假设：修图后的当前画布是短片的唯一素材。导出菜单用一个 720p 静帧模板，等比容纳整张照片，保持 30 fps、3 秒和无声。初版短片可用系统播放器打开，工程恢复继续走 `.comp` 文件。
- 影响文件：`app/Prototype/Editor/IO/ProjectController.swift` 接已有照片编码和系统保存面板，`app/Prototype/Editor/Gift/` 添加短片入口与模板组装，`app/Prototype/VideoEngine/` 接 AVFoundation 写入和文件回读。沿用本地 `MediaIO`、`BirthdayCore`、`TemplateKit`、`TimelineKit`；在 `app/compositor-prototype.yml` 声明依赖。离线清单独立置于 `docs/workflow/`。
- 先写测试：同一份合成照片经过现有编辑会话、PNG 导出及 `MediaLibrary` 发布与回读，模板转换成引用该 `MediaID` 的单片段时间轴。用 AVFoundation 从输出文件逐帧解码，预期一个视频轨、零音轨、30 fps、90 帧、3.0 秒。用 4000×3000 合成照片分别计量选图到可编辑、保存工程、MP4 导出和工程重开，并注明进程峰值内存的测量口径。
- 验收：在原型工作树运行 `python tools/check_repo.py`，预期 0 error。在 `xcode-27` 用原型 scheme 执行 Debug 测试和 arm64 Release。按同一个 SHA 下载 MP4、证据摘要和 ZIP。CI 查 ZIP 包内架构、26.0 下限、完整许可、签名权限和解包后的签名，本地核对归档及 SHA-256。参考机和目标机各自回填离线清单。

## 进度日志

- 2026-11-20：从 T-0008 细化，承接原 AC3 的短片与原 AC4 的目标机验收。
- 2026-11-21：T-0009 客观测试通过，等待用户界面评审。先验证短片和可离线交付的候选包，再用目标机证据验收。
