# STATUS — 项目当前状态

当前交付目标是 macOS。首次 macOS CI 成功，现优先评估以 Compositor 复用修图能力。

- **最后更新**：2026-11-20
- **当前阶段**：M0 私有仓库、macOS CI 和 Compositor 派生编辑器构建已验收；M1 产品定义待验收，M2 主线正式 CI 已通过
- **当前任务**：[T-0009 Compositor 原型中文编辑、生日和回忆](tasks/T-0009-compositor-prototype-gift-interface.md)（`ready`）。[T-0008](tasks/T-0008-compositor-integrated-prototype.md) 的 [run 44784457809](https://github.com/yuexuanchi-sys/iosps-studio/actions/runs/44784457809) 已通过并下载回读。
- **执行方式**：按 [executor-prompt.md](docs/workflow/executor-prompt.md) 连续推进，WIP = 1

## 下一步

1. **T-0009 → T-0010**：在 `artifacts/worktrees/t-0008-compositor-prototype` 的 `t-0008-compositor-prototype` 分支接中文礼物界面和回忆，再接短片和离线真机验收。派生编辑器的 47 个基线用例、3 个原型用例、Swift 6／arm64 Release 和 ZIP 已验证。按 [R04](docs/research/R04-compositor-reuse.md) 保留验收门槛。
2. **T-0203**：推进浅／深色及文字缩放快照。
3. **T-0207 → T-0205**：补齐 HEIC、视频、色彩与尺寸的运行验收，再接 Finder 选取、拖放和权限反馈。
4. **T-0301**：接生日主页与日期逻辑；T-0302/T-0304 使用回忆清单与用户素材。
5. **T-0101 / T-0102 / T-0103 / T-0104**：用户可同时验收 PRD、线框、视觉及命名，并按素材清单私下准备回忆包。D-02 确认后复核工期。

## 待用户决策

| ID | 问题 | 影响 | 关联 | 状态 |
|---|---|---|---|---|
| D-01 | 目标平台 | 技术与分发 | ADR-0003 | ✅ 用户于 2026-11-20 确认 macOS |
| D-02 | 最晚交付日期 | 倒排工期 | charter / PRD | ⚠️ 暂定：按最小礼物路径排序，生日日期写在本地回忆包 |
| D-03 | 是否使用付费开发者账号公证 | Mac ZIP 首开流程 | ADR-0005 | ⚠️ 暂定：免费 M-0（ad-hoc ZIP + 图文说明） |
| D-04 | GitHub 仓库公开还是私有 | CI 额度、项目可见范围 | ADR-0004 | ✅ 用户于 2026-11-20 确认私有 |
| D-05 | Git 初始化、提交与推送的授权范围 | 首次上传和触发 CI | T-0004 | ✅ 用户于 2026-11-20 授权初始化、创建私有远端、首次提交和推送，以及本轮 CI 修复与后续任务的提交、推送 |
| D-06 | 开发和验收分工 | 任务分配 | task-system | ⚠️ 暂定：AI 写代码，用户验收 |
| D-07 | 目标 MacBook 配置 | 部署目标及真机测试 | ADR-0003 | ✅ 用户确认按 M 系列 MacBook；采用 arm64、macOS 14.0 起，性能参考 M1／8 GB，真机信息在 T-0803 核对 |
| D-08 | 回忆如何交付 | 首次进入和隐私 | PRD §3 | ⚠️ 已按默认推进：本地回忆文件夹，可在目标 Mac 提前导入 |
| D-09 | 视觉方向、App 名称和图标 | DesignSystem 与交付外观 | T-0103 | ⚠️ 已按默认推进：暖色纸相册、拾光簿、叠放照片与星点 |
| D-10 | 2 月 29 日生日在平年何时祝福 | 倒计时、年龄、全屏祝福 | T-0305 | ⚠️ 已按默认推进：2 月 28 日 |
| D-11 | 短片首版帧率与时长 | 时间轴与导出 | T-0501 | ⚠️ 已按默认推进：30 fps 整数帧，最长 10 分钟 |
| D-12 | Compositor 原型与首版部署目标 | 修图底座、目标 Mac 兼容性 | T-0008 / ADR-0001 / ADR-0003 | ✅ 用户于 2026-11-20 确认目标机可用 macOS 26+，先验证完整继承原型。正式迁移及提高主线部署下限仍待确认 |

## 阻塞

- **修图路线**：T-0401 及后续自研修图代码暂缓。先用隔离原型验证完整继承，正式迁移和主线部署下限按原型证据再确认。
- **本地 L1**：当前机器无 `swift`，WinGet 别名无法启动。Windows 安装见 [T-0007](tasks/T-0007-windows-swift-toolchain.md)，L1 已在 macOS CI 验证。
- **个人素材**：T-0104 的格式和清单已写好，用户将素材放进 `content/private/` 后只需确认目录与数量。T-0302/T-0304 的真实内容验收需素材。
- **产品与目标机验收**：T-0101/T-0102/T-0103 在 review，安装与体验要在朋友目标 Mac 做 L4。

## 环境和边界

- 冒烟 [run 44775125352](https://github.com/yuexuanchi-sys/iosps-studio/actions/runs/44775125352) 为 `success`，47 个测试通过，AppMac arm64 Release 和签名通过，已打开首屏 PNG 并验证 ZIP，详见 [T-0005](tasks/T-0005-ci-smoke-test.md)。
- 主线正式 CI [run 44777973616](https://github.com/yuexuanchi-sys/iosps-studio/actions/runs/44777973616) 跑过 47 个 SwiftPM 用例、1 个 AppMac 宿主用例及 Release 签名包回读，详见 [T-0202](tasks/T-0202-mac-ci-pipeline.md)。
- 隔离原型产物 `artifacts/prototype/44784457809/IOSPSCompositorPrototype.app.zip` 已核对。编译使用 Xcode 27.1／Swift 6.4，原型下限 26.0。主线构建使用 macOS 14.0／arm64 部署目标。
- Windows 11 有 git、Python 和 Node；Apple 构建使用 macOS GitHub runner。
- Swift 6、SwiftUI、Core Image/Metal、AVFoundation、Vision；工程先做 AppMac，L1 模块保持跨平台。
- 构建只含公开资源；个人目录由 `.gitignore` 排除。最低平台见 [ADR-0003](docs/decisions/ADR-0003-target-platform.md)，签名路径见 [ADR-0005](docs/decisions/ADR-0005-distribution.md)。
