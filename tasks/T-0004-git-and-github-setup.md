---
id: T-0004
title: Git 初始化 + GitHub 仓库 + gh CLI
milestone: M0
status: done
priority: P0
modules: infra
features: none
depends: T-0001
verify: L0
owner: AI+用户
updated: 2026-11-20
---

# T-0004 · Git 初始化 + GitHub 仓库 + gh CLI

## 目标
仓库纳入版本控制并托管到 GitHub，AI 可以在 Windows 上通过 `gh` 推送、触发 CI、读取日志和下载产物。

## 背景与依据
- [ADR-0004](../docs/decisions/ADR-0004-build-pipeline.md)、[conventions.md §Git](../docs/workflow/conventions.md)
- 依赖决策：D-04（公开 / 私有）、D-05（提交授权）

## 范围
**做：**
1. 本地 `git init -b main`；确认 `.gitignore` / `.gitattributes` 生效（个人素材、密钥、构建产物不会被跟踪）。
2. 安装 GitHub CLI：用户执行 `winget install GitHub.cli`，然后在本会话里 `! gh auth login` 完成登录（交互式，必须用户自己操作）。
3. 创建 GitHub 仓库（名字要中性，不暴露礼物对象），按 D-04 设公开 / 私有。
4. 首次提交并推送（**必须有 D-05 授权**）。

**不做：** CI 配置（T-0005）。

## 验收标准
- [x] AC1：首次提交后 `git status --porcelain` 无输出；`git check-ignore -v` 命中 `content/private/x.jpg` 等 19 个路径探针。审计 93 条实际暂存路径，扫描常见凭据格式无命中。
- [x] AC2：`gh auth status --hostname github.com` 显示已登录，退出码 0；`gh --version` 为 2.105.0。
- [x] AC3：`gh repo view` 返回 `PRIVATE`、默认分支 `main`；`git ls-remote origin refs/heads/main` 返回 `8e8f61d14a5c0ed4214ec9b2af3d3d24ae21b083`，与首次提交一致。远端为 [iosps-studio](https://github.com/yuexuanchi-sys/iosps-studio)。
- [x] AC4：CLAUDE.md「会话结束」第 6 步按 D-05 改写并链接 STATUS。

## 用户决定及授权
- 2026-11-20 用户确认 D-04 为私有。D-05 授权在 `D:\IOSPS` 初始化、创建私有远端、首次提交与推送，并允许本轮 CI 修复和后续任务提交推送。用户已完成 GitHub 登录。

## 实施要点

- 先验证 GitHub 登录，再依据 D-04/D-05 启动 Git 初始化与远端创建。首次提交前检查所有待跟踪路径、忽略规则和签名密钥文件扩展名。运行 T-0005 前检查默认分支和 workflow 文件。
- 假设使用中性名称 `iosps-studio` 和 `main` 启动首次冒烟。交付物为本地仓库、私有 `origin`、`main` 首次同步和 Git 授权文档。影响 `.gitignore`（如审计发现缺口）、CLAUDE.md、Git 约定、STATUS、BOARD 和 ADR-0004。
- 验收运行 `git check-ignore -v` 检查个人素材、凭据、签名文件和构建产物，核对 `git diff --cached --name-status` 及暂存内容。提交后 `git status --porcelain` 应为空，`gh repo view --json visibility,defaultBranchRef` 应为 `PRIVATE` 和 `main`，`git ls-remote origin refs/heads/main` 应返回推送的 SHA。

## 进度日志
- 2026-11-20：创建。`.gitignore` / `.gitattributes` 已在 T-0001 中提前写好。
- 2026-11-20：`git rev-parse --show-toplevel` 显示未初始化，`gh --version` 找不到命令。等待 D-04/D-05；获授权后可运行 `winget install --id GitHub.cli --exact --source winget`，再由用户运行 `gh auth login`。
- 2026-11-20：本地发现 `gh` 2.105.0。沙箱内 API DNS 解析失败；同一个 `gh auth status --hostname github.com` 经联网复核显示当前账号已登录，退出码 0，具备 `repo`、`workflow` 授权范围。`git rev-parse --show-toplevel` 仍显示未初始化，等 D-04/D-05。
- 2026-11-20：将任务依赖改为已完成的 T-0001，保留本卡的 D-04/D-05 前置条件。T-0002 的生日和交付排期可以独立确认。
- 2026-11-20：收到 D-04/D-05，建立私有 `origin/main`。Git 全局代理指向不可达的回环端口，首次推送用单次 `git -c http.proxy=` 与 gh 凭据助手直连。仓库提交邮箱使用已登录账号的 GitHub noreply 地址。自查通过：验收逐条有证据，暂存差异白空格检查通过，无新增实现占位符、依赖变更或新增素材，授权和可见性已同步，`python tools/check_repo.py` 为 0 error。
