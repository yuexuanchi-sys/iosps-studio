---
id: T-0005
title: CI 冒烟测试：云端 macOS 构建出最小 App
milestone: M0
status: blocked
priority: P0
modules: infra
features: none
depends: T-0003, T-0004
verify: L2,L3
owner: AI
updated: 2026-11-20
---

# T-0005 · CI 冒烟测试

## 目标
**验证整条"Windows 写代码 → 云端构建 → 拿到产物"的链路是通的**。这是整个项目最大的技术前提，越早验证越好。

## 背景与依据
- [ADR-0004](../docs/decisions/ADR-0004-build-pipeline.md)、[verification.md](../docs/workflow/verification.md)、[R03 §3.2](../docs/research/R03-fact-check-2026-11-20.md)

## 范围
**做：**
1. 最小 SwiftPM 包（1 个纯 Swift 函数 + 1 个单测）→ CI 上 `swift test`。
2. 最小 SwiftUI App（显示「生日快乐」）→ `project.yml` + XcodeGen → CI 上 `xcodebuild build`。平台按 ADR-0003。
3. 用快照入口渲染实际 App 首屏组件，上传 PNG artifact。
4. 把 Mac `.app` 打成 zip 作为 artifact，附签名与校验信息。
5. 在本地用 `gh run download` 拿到截图和产物，AI 读截图确认。
6. 记录：用的 runner 标签、Xcode 版本、一次构建耗时（用来估算以后的 CI 成本）。

复用 T-0201 的工程和 L1 单测。流程保持手动触发，T-0202 负责正式触发与回归。

## 验收标准
- [ ] AC1：L2：CI 上 `swift test` 通过（贴出 run 编号）。
- [ ] AC2：L2：CI 上 App 构建成功。
- [ ] AC3：L3：截图 artifact 已下载到本地 `artifacts/`，AI 读图确认显示了"生日快乐"。
- [ ] AC4：（Mac 版）zip 产物下载后结构正确（`.app/Contents/MacOS/…`），并用 `codesign -dv` 的日志确认是 ad-hoc 签名（在 CI 里执行）。
- [ ] AC5：ADR-0004 改为 Accepted，补上实测的 runner / Xcode 版本 / 耗时。

## 实施要点
- 假设：直接复用 T-0201 工程以减少维护两个 App；实际运行仍依赖 T-0004。
- 采用 macos-26 arm64 手动流程，锁定官方工具版本及校验值。配置在 `.github/workflows/ci.yml`，生成的 PNG、签名报告、ZIP 和 SHA-256 在 `artifacts/` 回读。首个运行结束前保留失败步骤日志与提交对应关系。

### CI 验证与回读

`macos-26` 为 GitHub 官方 arm64 runner 标签，Xcode 以实际镜像打印的版本为准。[GitHub runner 参考](https://docs.github.com/en/actions/reference/runners/github-hosted-runners)

在 T-0004 完成并将配置推到默认分支后执行，`$iospsRepo` 为经核验的 `owner/repo`：

```powershell
$iospsSha = git rev-parse HEAD
gh workflow run ci.yml --repo $iospsRepo --ref main
gh run list --repo $iospsRepo --workflow ci.yml --branch main --event workflow_dispatch --commit $iospsSha --json databaseId,headBranch,headSha,status,conclusion,url
```

将实际编号赋给 PowerShell 变量 `$iospsRun`，执行 `gh run watch $iospsRun --repo $iospsRepo --exit-status` 与 `gh run download $iospsRun --repo $iospsRepo --name iosps-macos-smoke --dir "artifacts/smoke/$iospsRun"`。预期 run 为 success；artifact 中有 720×480 的 `birthday-smoke.png`、`IOSPS.app.zip` 及校验文件。读图确认显示「生日快乐」，从日志取测试计数、arm64、runner、Xcode 与耗时。用 `tar -tf "artifacts/smoke/$iospsRun/IOSPS.app.zip"` 核对 App 包体，`Get-FileHash "artifacts/smoke/$iospsRun/IOSPS.app.zip" -Algorithm SHA256` 比对随包 SHA-256，并核对 `signature.txt` 中的 `Signature=adhoc`。

## 进度日志
- 2026-11-20：创建。
- 2026-11-20：配置和截图入口已写齐，待验证（L2/L3）。Python 静态核对 YAML 的触发、权限、runner、固定 SHA 和五个输出；check_repo 0 error。需要 D-04/D-05、登录和远端；执行本卡 CI 回读命令后补 AC1–AC5。
- 2026-11-20：对 YAML 中五段 runner 脚本运行 Git for Windows Bash 的 `-n` 语法检查，退出码 0；该检查不产生 CI 运行或产物。
- 2026-11-20：`gh auth status --hostname github.com` 联网核验已通过；剩余前置条件为 T-0004 的 D-04/D-05 和首次上传。
- 2026-11-20：冒烟 SwiftPM 测试步骤已包含 T-0206/T-0207 的 9 个 macOS 用例，当前共 47 个测试声明。运行后以 CI 报告的实际数量为证据。
