---
id: T-0010
title: Compositor 原型短片和离线真机验收
milestone: M0
status: blocked
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

- [x] AC1：将派生编辑器导出结果登记为 `MediaID`，以虚构素材和单模板导出可播放的 3 秒／30 fps／90 帧无声 MP4。[run 44921126380](https://github.com/yuexuanchi-sys/iosps-studio/actions/runs/44921126380)，`4bbda3e40de12bb18aadad141a3da77534972620`，原型 scheme 的 `twelveMegapixelProjectAndMovieRoundTrip` 验证出库同一 `MediaID`、AVFoundation 可播放及逐帧解码。实际 UI 导出的 `artifacts/prototype/44921126380/retouched-memory.mp4` 另用 PyAV 解码 90 帧，时间戳为 0…89/30 秒，3.000 秒、30 fps、0 音轨，首帧已查看。
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
- 2026-11-21：`xcodebuild -project IOSPSCompositorPrototype.xcodeproj -scheme CompositorPrototype -destination 'platform=macOS' test` 在 [run 44921126380](https://github.com/yuexuanchi-sys/iosps-studio/actions/runs/44921126380) 通过，含 47 项基线、4 项宿主测试、3 项 UI 测试。Release 签名 ZIP 下载至 `artifacts/prototype/44921126380/iosps-compositor-prototype/`，6,258,591 字节，SHA-256 `7bb21dfe065495f8c0246a8b17636bb4f968909de5d004e70367d6969e9da40f`。核对 ZIP CRC、Mach-O arm64 与 26.0、包内许可和模板、ad-hoc 签名与两条精确权限。CI 解包后执行 `codesign --verify --deep --strict` 成功。AC2 余目标机断网首开、两条主流程及重开恢复。
- 2026-11-21：同一 run 的 `run.log` 中，`xcode-27` 的 macOS 27.0.1／arm64、Xcode 27.1／Swift 6.4 Debug 宿主用 12 MP 合成照片测得导入 0.185 秒、保存 0.354 秒、短片导出 0.853 秒、重开 0.254 秒，`getrusage(RUSAGE_SELF)` 进程峰值 522,813,440 字节，约 498.6 MiB，含文件解码回读。CI 测的是引擎调用，参考机和目标机的体验及性能仍待实测。参考机与目标机可使用 `artifacts/prototype/acceptance/landscape-12mp.jpg` 按离线清单回填，AC3 保持开放。
