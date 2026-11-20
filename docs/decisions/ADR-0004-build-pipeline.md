# ADR-0004：构建流水线 —— Windows 写代码 + GitHub Actions macOS + XcodeGen

- 状态：**Accepted**（T-0004/T-0005 已完成首次私有仓库与 macOS 冒烟回读）
- 日期：2026-11-20
- 关联：[R03 §3.1–3.3](../research/R03-fact-check-2026-11-20.md)、ADR-0006、[verification.md](../workflow/verification.md)

## 背景

- 开发机只有 Windows，使用 macOS runner 上的 Xcode 构建 Apple 平台产物。
- 不买、不借 Mac 的前提下，所有 Apple 平台的编译、测试、打包都要在云端完成。
- `.xcodeproj` 是机器生成的格式，在 Windows 上手写容易损坏。

## 决策

1. **代码托管**：用户于 2026-11-20 确认在 GitHub 用户账号下建**私有仓库**，本轮 Git 操作按 [D-05](../../STATUS.md) 执行。个人素材留在本地。
2. **CI**：GitHub Actions，冒烟配置先用官方 `macos-26` arm64 标签，实测 runner、Xcode 与耗时后再确认（T-0005）。流水线：
   - `swift test`：纯 Swift 模块的单元测试；
   - `xcodegen generate` → `xcodebuild build test`：App 和 Apple 框架相关模块；
   - 快照测试 / UI 测试生成**截图**，作为 artifact 上传（视觉验证，见 verification.md L3）；
   - 打包：macOS `.app.zip`（ADR-0005）。
3. **工程生成**：**XcodeGen**（`app/project.yml`）；生成的 `.xcodeproj` 不入库。纯逻辑模块用 `app/Package.swift`（SwiftPM）。
4. **本地（Windows）**：可选安装 Swift for Windows 工具链，本地跑纯 Swift 模块的单测，加快反馈（T-0007）。
5. **读取 CI 结果**：在 Windows 上安装 GitHub CLI（`gh`），让 AI 可以触发流水线、读日志、下载截图（T-0004）。

## 备选方案

| 方案 | 优点 | 缺点 | 结论 |
|---|---|---|---|
| Codemagic | 有 macOS 免费额度，对移动端友好 | 多一个平台账号；日志和产物不如 gh CLI 好集成 | 备选 |
| 租用云 Mac（MacinCloud 等） | 有真实的 Xcode 和模拟器界面 | 每月 ¥150–700；远程桌面 AI 操作不了 | 只在截图管线不够用时考虑 |
| 借 / 买二手 Mac mini | 体验最好 | 一次性 ¥2000+ | 用户自己决定 |
| Xcode Cloud | 官方 | 需要 $99 账号，配置也要在 Xcode 里操作 | 本轮不采用 |

## 后果

- ✅ 无需新增硬件；构建与测试在 GitHub Actions 留存日志。
- ⚠️ 每轮反馈 5–15 分钟 → 任务切片要尽量让纯逻辑先在本地测完，减少 CI 往返。
- ⚠️ 私有仓库使用账号的 Actions 额度，计量和超额处理以 [GitHub Actions 账单说明](https://docs.github.com/en/billing/concepts/product-billing/github-actions) 和账户设置为准。

## 首次实测

- 2026-11-20，私有仓库 `main` 的 [run 44775125352](https://github.com/yuexuanchi-sys/iosps-studio/actions/runs/44775125352) 成功。标签 `macos-26`，镜像 `macos-26-arm64` `20261117.0516.1`，macOS `26.7.2`，Xcode `26.6` (`17F113`)，Swift `6.3.3`，XcodeGen `2.48.0`。
- `swift test --package-path app` 通过 47 个测试。AppMac Release 构建 21.852 秒，runner job 53 秒，从触发到 run 完成共 67 秒。已回读首屏 PNG、arm64 ad-hoc ZIP 及 SHA-256。覆盖范围、文件路径和校验值见 [T-0005](../../tasks/T-0005-ci-smoke-test.md)。
