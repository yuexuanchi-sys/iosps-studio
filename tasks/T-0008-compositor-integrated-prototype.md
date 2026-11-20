---
id: T-0008
title: Compositor 派生编辑器构建与回归
milestone: M0
status: done
priority: P0
modules: AppMac, GiftKit, MediaIO, VideoEngine
features: F-01, F-02, F-07, F-08, F-13, F-14, F-15
depends: T-0006, T-0202
verify: L0,L1,L2
owner: AI+用户
updated: 2026-11-20
---

# T-0008 · Compositor 派生编辑器构建与回归

## 目标

在 macOS 26+／arm64 对完整继承路线做第一段验证，确认派生应用能够在 Swift 6 中构建，并保留裁剪、调色、文档和导出链路。[T-0009](T-0009-compositor-prototype-gift-interface.md) 接中文与回忆，[T-0010](T-0010-compositor-prototype-offline-movie.md) 验证短片和离线交付。

## 背景与依据

- [D-12](../STATUS.md)、[R04](../docs/research/R04-compositor-reuse.md)、[ADR-0003](../docs/decisions/ADR-0003-target-platform.md)、[ADR-0005](../docs/decisions/ADR-0005-distribution.md)、[易用性原则](../docs/product/ux-principles.md)。

## 范围

固定上游 `4a17b264a93b6da5fa5ff81357e6194ef9ad61a2`，在隔离 Git 分支上验证派生应用。原型工作以已阅读源码和合成素材为输入，使用独立 App 标识。原型评审后另由用户决定是否正式迁移和调整主线部署下限。

## 验收标准

- [x] AC1：L1/L2，[run 44784457809](https://github.com/yuexuanchi-sys/iosps-studio/actions/runs/44784457809) 在 `xcode-27-arm64`（macOS 27.0.1、Xcode 27.1、Swift 6.4）完成 47 个基线测试及 Swift 6 严格并发 arm64 Release，部署目标 26.0。SHA `8001a93bf62f5bc58c6365d3aec8782424f06ecf`，构建 75.863 秒，runner job 164 秒。
- [x] AC2：L2，同一 run 的 3 个合成回归通过，涵盖 2:1 裁剪、旋转、撤销重做、项目重开、原件 SHA-256、裁剪后像素尺寸、sRGB、透明度、曝光与饱和度变化、JPEG 方向。
- [x] AC3：L2，本地回读 `artifacts/prototype/44784457809/IOSPSCompositorPrototype.app.zip`，CRC、arm64 Mach-O、26.0、独立包 ID、MIT 声明、SHA-256 与精确签名权限均通过。CI 核对完整包和解包后的 ad-hoc 签名，Release 只有 App Sandbox 与用户选取文件的读写权限。包内无 Sparkle、模型、待核实色表或测试 bundle。

## 实施要点

- 假设：用 `t-0008-compositor-prototype` 隔离分支及独立原型工作流和应用标识。核对固定源码、许可与资源来源后只把构建所需的派生代码放入 `app/`。上游下载目录仅供只读，原型使用仓库自己的 CI 命令，移除上游签名、更新和模型下载路径。
- 交付物：隔离分支上的 `app/Prototype/` 派生代码、`app/compositor-prototype.yml`、原型 CI 与许可登记。用 `xcodegen generate --spec compositor-prototype.yml` 生成工程，再以 `xcodebuild -project IOSPSCompositorPrototype.xcodeproj -scheme CompositorPrototype -configuration Release -destination 'platform=macOS' build` 构建。按同一 scheme 运行合成照片回归测试，0 失败。主线继续按 14.0 验收。

## 进度日志

- 2026-11-20：D-12 选定完整继承原型，从 T-0006 转入独立运行验收。静态证据和初始门槛见 R04。
- 2026-11-20：按运行依赖拆为三个可验收切片。原 AC2 的中文、画布交互、键盘和三类 UI 截图，以及 AC3 的生日和回忆验收移到 T-0009。原 AC3 的 MP4 和原 AC4 的断网真机验收、性能记录移到 T-0010。保留构建和编辑内核的回归要求。
- 2026-11-20：在 `artifacts/worktrees/t-0008-compositor-prototype` 建隔离工作树，清洁基线为 `0e5ad89`，主线采用原 CI 和 macOS 14.0。原型提交 `3bd953b2c89cb83d206a9f7f4393fdfbea41f2b6` 仅在私有原型分支。源码清单、许可、离线 plist、YAML/Bash 和 L0 已核对。首个 [run 44779572982](https://github.com/yuexuanchi-sys/iosps-studio/actions/runs/44779572982) 的 IOSPS 项目脚手架与 SwiftPM 测试步骤成功，继续跟踪派生编辑器。
- 2026-11-20：原型首个 run 的 Release 步骤失败，日志 `artifacts/prototype/44779572982/failed.log`。Swift 6 拒绝默认 MainActor 推断出的 Core Image 和 AppKit override、跨隔离域属性、`CGPath` 和共享 C 指针。只移除派生目标的隐式 MainActor 默认值做对照，主线配置和 Swift 6 严格检查继续保留。
- 2026-11-20：对照 [run 44779977224](https://github.com/yuexuanchi-sys/iosps-studio/actions/runs/44779977224) 同样失败，唯一诊断从 55 增至 63，并出现编辑会话丢失主线程保护后的调用错误。恢复默认 MainActor，分别标注无状态工具／框架回调、拷贝不可变轮廓以及同步 C 回调指针。保留合成图像验收。
- 2026-11-20：[run 44780701953](https://github.com/yuexuanchi-sys/iosps-studio/actions/runs/44780701953) 终态失败，编译诊断降至 5 条。日志 `artifacts/prototype/44780701953/failed.log`，定位 AppKit 事件监视器清理、滤镜任务捕获、Metal 互斥区和原生菜单回调。针对 5 处继续修复。
- 2026-11-20：[run 44781252241](https://github.com/yuexuanchi-sys/iosps-studio/actions/runs/44781252241) 仅剩 3 个 `MTLBuffer` 非 Sendable 诊断，详见 `artifacts/prototype/44781252241/failed.log`。将受互斥锁保护的私有缓存明确标注 `@unchecked Sendable`，命令等待完成后才放锁，保留 Swift 6 严格并发校验。
- 2026-11-20：[run 44781564043](https://github.com/yuexuanchi-sys/iosps-studio/actions/runs/44781564043) 进入 Swift IRGen，Swift 6.3.3 为编译器生成的闭包 thunk 发出 LLVM 栈回溯并退出。保留 Release 优化和并发检查，将原型切换到增量编译以隔离 whole-module 优化路径。日志 `artifacts/prototype/44781564043/failed.log`。
- 2026-11-20：[run 44782166840](https://github.com/yuexuanchi-sys/iosps-studio/actions/runs/44782166840) 复现 IRGen 崩溃，把编译请求定位到 `LayerAppearanceControls.swift`。该控件把主线程数值读取闭包传给 `arrowSteps`。统一其回调的参数和存储类型为显式 MainActor，复验该路径。日志 `artifacts/prototype/44782166840/failed.log`。
- 2026-11-20：[run 44782535675](https://github.com/yuexuanchi-sys/iosps-studio/actions/runs/44782535675) 仍在 IRGen 崩溃，位置推进到 `GridSettingsSheet.swift` 的 Int 访问闭包。根据两处同类 thunk，将原型 CI 切换到 GitHub 的 `xcode-27` runner 验证新版编译器。原型部署目标仍为 26.0；主线继续使用已验证的 `macos-26`。日志 `artifacts/prototype/44782535675/failed.log`。[官方 runner 标签](https://docs.github.com/en/actions/reference/runners/github-hosted-runners)
- 2026-11-20：[run 44782860918](https://github.com/yuexuanchi-sys/iosps-studio/actions/runs/44782860918) 的 Xcode 27 在源码检查阶段报告 `HueArrow: Shape` 的隔离诊断。该 Shape 仅按输入矩形计算路径，显式去除其继承的 MainActor 隔离后复验。日志 `artifacts/prototype/44782860918/failed.log`。
- 2026-11-20：[run 44783206026](https://github.com/yuexuanchi-sys/iosps-studio/actions/runs/44783206026) 通过 Shape 的编译检查，发现 `EffectsSheet` 把未标注隔离的数值回调传给主线程控件。给该回调标注 MainActor，进入下次复验。日志 `artifacts/prototype/44783206026/failed.log`。
- 2026-11-20：[run 44783539914](https://github.com/yuexuanchi-sys/iosps-studio/actions/runs/44783539914) 终态成功。Xcode 27.1／Swift 6.4 下 Release 90.229 秒，既有 47 个及新增 3 个回归全部通过。下载核对 arm64、26.0、许可及 SHA-256，额外发现 Xcode 注入的 `get-task-allow`。参考 Apple 指引关闭原型 Release 基础权限注入，并让 CI 比对签名权限与声明、解包后验签。日志 `artifacts/prototype/44783539914/run.log`。[Apple 签名说明](https://developer.apple.com/documentation/security/resolving-common-notarization-issues)
- 2026-11-20：[run 44784457809](https://github.com/yuexuanchi-sys/iosps-studio/actions/runs/44784457809) 成功，修复后的 ZIP SHA-256 `0d93f468fade741577debc060277f329990216e9948efc63eeea9f2ef265c52e`。完整日志在 `artifacts/prototype/44784457809/run.log`。自查通过：AC1–AC3、隔离分支与主线部署边界均核对，源码无实现占位符，外部来源和随包 MIT 许可已登记，BOARD、STATUS 和 ADR 已同步，`python tools/check_repo.py` 为 0 error。原型有上游 Metal 和 AppKit 弃用 API 编译警告，T-0009/T-0010 继续验证界面、媒体连通和真机。
