# 验证矩阵（没有 Mac 的前提下怎么证明"真的做好了"）

> 原则：**没有证据就不能说完成**。做不到的验证要明确写出来，交给下一层或交给用户。

## 验证层级

| 层级 | 验证什么 | 在哪里做 | 工具 | 证据形式 | 谁来做 |
|---|---|---|---|---|---|
| **L0** 静态检查 | 文档一致性、JSON 模板格式、许可证登记、L1 import 规则 | Windows 本地 | `python tools/check_repo.py`（后续扩展） | 命令输出 0 error | AI |
| **L1** 纯逻辑单测 | L1 模块（BirthdayCore / TemplateKit / TimelineKit / GiftKit） | Windows 本地（装好 Swift 工具链后，T-0007）**或** CI | `swift test --package-path app` | 测试通过数 / 失败数 | AI |
| **L2** Apple 平台构建 + 单测 | L2 引擎、App 能编译、引擎单测（固定测试图渲染、导出视频检查时长 / 分辨率） | GitHub Actions macOS | `xcodegen` + `xcodebuild build test` | CI run 链接 / 编号 + 结果 | AI 触发、读日志 |
| **L3** 视觉验证 | UI 长什么样、渲染效果对不对 | GitHub Actions macOS 产出 PNG → 下载到本地 | 快照测试 / XCUITest 截图，作为 artifact 上传；`gh run download` | 截图文件路径；AI 看图检查 + 用户确认 | AI + 用户 |
| **L4** 真机体验 | 手感、性能、发热、权限弹窗、安装流程 | 目标设备（朋友的 Mac / iPhone，或用户自己的设备） | 按任务卡的验收清单手动操作 | 用户的反馈（文字 / 截图 / 录屏） | 用户 |

## 各层的限制（必须清楚）

- **L1** 只能证明逻辑正确，不能证明在 Apple 平台上的表现（Windows 上的 Foundation 是跨平台实现，个别 API 行为有差异 → L1 的测试也要在 CI 上跑一遍）。
- **L2** 只能证明能编译、单测能过；CI 机器的 GPU 是虚拟的，**性能数据不可信**。
- **L3** 截图是静态的：动画、手势、流畅度看不出来。
- **L4** 是唯一能验证体验的层级，但成本最高（要用户动手）→ 把需要 L4 验证的东西**攒成批**，每个里程碑结束时做一次。

## Windows L1 命令

在新 PowerShell 中先运行 `swift --version`。工程根目录运行 `swift build --package-path app` 与 `swift test --package-path app`。Windows 只构建跨平台部分。若安装要等用户处理，CI 使用同一 Swift 包跑 L1。安装依赖和最小冒烟命令见 [T-0007](../../tasks/T-0007-windows-swift-toolchain.md)。

## 每次 CI 往返的成本意识

- 一轮 CI 约 5–15 分钟；私有仓库还要花钱（ADR-0004）。
- 推代码之前：L0 + L1 先在本地跑通；一次推送尽量完成一个完整的切片，不要推一行改一行。
- CI 失败：先完整读日志、定位根因再改（遵守 systematic-debugging 的做法），不要盲目重试。

## 常规 macOS CI（T-0202）

`.github/workflows/ci.yml` 对目标分支为 `main` 的 PR 和 `main` 上的应用、工作流与检查配置变更自动运行，支持 `gh workflow run ci.yml --ref main` 手动触发。AppMac 的 Debug 测试由 `xcodebuild -project IOSPS.xcodeproj -scheme AppMac -configuration Debug -destination 'platform=macOS' test` 运行，Release 构建与测试目录按配置分开。从成功 run 下载 `iosps-macos-build`，用 `Get-FileHash -Algorithm SHA256` 核对 ZIP 与随包校验记录。首次冒烟的历史产物名和 run 见 [T-0005](../../tasks/T-0005-ci-smoke-test.md)。

## 截图验证管线（T-0203）

1. 主线 CI 在 `macos-26` 渲染实际 `BirthdayGreetingView`，保留 720×480 冒烟图并输出三张 1280×800 PNG。用 `swift run --package-path app BirthdaySmokeSnapshot --variants <目录>` 本地重跑。
2. `iosps-macos-build` 的 `snapshots/` 包含 `birthday-light.png`、`birthday-dark.png`、`birthday-large.png`，CI 校验三组分辨率和内容差异。
3. AI 用 `gh run download` 下载到 `artifacts/`（已 gitignore），用读图能力检查布局、文字截断、对比度。
4. 需要用户看的截图，在任务卡里列出路径，任务状态改为 `review`。静态快照用于核对视觉，交互页面用 UI 测试补焦点和键盘证据。隔离原型实际运行截图见 [T-0009](../../tasks/T-0009-compositor-prototype-gift-interface.md)。
