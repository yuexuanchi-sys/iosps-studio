---
id: T-0007
title: Windows 本地 Swift 工具链（L1 本地测试）
milestone: M0
status: blocked
priority: P1
modules: infra
features: none
depends: none
verify: L1
owner: AI+用户
updated: 2026-11-20
---

# T-0007 · Windows 本地 Swift 工具链

## 目标
在这台 Windows 电脑上能运行 `swift test`，让 L1 纯逻辑模块不用等 CI 就能拿到反馈（ADR-0006 的前提之一）。

## 范围
**做：**
1. 查官方当前推荐的 Windows 安装方式（swift.org，可能是 `winget install Swift.Toolchain` 或 swiftly，**以官网为准**），连同依赖（Visual Studio Build Tools 的 C++ 组件、Windows SDK）。
2. 用户执行安装（需要管理员权限，可能要几 GB 空间）。
3. 用一个临时的最小 SwiftPM 包验证 `swift build` / `swift test`。
4. 在 verification.md 里写下本地测试命令和已知限制。

**不做：** 尝试在 Windows 上编译任何 Apple 框架相关的代码（不可能）。

## 验收标准
- [ ] AC1：`swift --version` 有输出（记下版本，要和 CI 上的 Swift 大版本一致或兼容）。
- [ ] AC2：最小包上 `swift test` 通过。
- [x] AC3：verification.md 的 L1 一行补充本地命令。 证据：verification.md 的矩阵和 Windows L1 命令段已补齐。

## 需要用户提供 / 确认
- 是否愿意装（约几 GB）；需要用户执行安装命令。**不装也不影响项目**，只是 L1 测试都要走 CI，会慢一些。

## 实施要点
- 查 Swift.org 安装要求并核对当前会话可用工具；只有具备平台依赖和用户权限才执行安装。
- 补齐本地命令和 CI 回退；安装后先在临时库验证，再跑工程包。

### 在交互式 PowerShell 中安装和验证

`vswhere` 已定位到 Visual Studio Community 18，C++ x64 工具组件存在。先在 Visual Studio Installer 核对 Windows SDK 和 C++ ARM64 组件。按 Swift.org 指引启用开发者模式，再运行：

```powershell
winget install --id Swift.Toolchain --exact --source winget
```

当前会话的 `winget --version` 失败（系统无法访问 WindowsApps 别名）。若交互式终端也失败，使用官方手动安装页的 x86_64 安装器。Swift 当前安装页和手动页列出的 SDK 示例不同，优先核对现有 VS 的平台依赖与安装器要求。[Swift Windows 安装](https://www.swift.org/install/windows/) · [Swift Windows 手动安装](https://www.swift.org/install/windows/manual/)

开一个新 PowerShell 后，用临时库验证工具链：

```powershell
swift --version
$swiftSmoke = Join-Path ([System.IO.Path]::GetTempPath()) ("iosps-swift-" + [guid]::NewGuid())
New-Item -ItemType Directory -Path $swiftSmoke | Out-Null
Push-Location $swiftSmoke
try {
    swift package init --name IOSPSSmoke --type library
    swift build
    swift test
} finally {
    Pop-Location
}
```

预期 Swift 6.x、构建成功、初始单测 0 失败。

## 进度日志
- 2026-11-20：创建。
- 2026-11-20：当前会话找不到 swift，WinGet 别名无法启动，WSL 无已安装发行版。等待用户在可交互环境完成开发者模式及官方工具链安装；也可先用 CI。AC1/AC2 尚无 L1 证据。
