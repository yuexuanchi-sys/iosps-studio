# CLAUDE.md — 生日礼物 App 项目（IOSPS）

> 本文件在每次 Claude Code 会话开始时自动加载，是"在这个仓库里怎么干活"的唯一入口。
> 细则在 [docs/workflow/](docs/workflow/)；当前进度永远以 [STATUS.md](STATUS.md) 为准。

## 项目一句话

给朋友做一个**生日礼物 App**：生日主题体验 + 实用 P图 + 一键回忆短片 + 基础视频剪辑，**简单易用优先**。
目标平台：**macOS**（用户 2026-11-20 决定，见 [ADR-0003](docs/decisions/ADR-0003-target-platform.md)；iOS 是否后补待定）。
开发机是 **Windows（无 Mac）**：代码在 Windows 上写，Apple 平台的构建/测试/打包交给云端 macOS（GitHub Actions，见 [ADR-0004](docs/decisions/ADR-0004-build-pipeline.md)）。

## 会话开始（必做，按顺序）

1. 读 [STATUS.md](STATUS.md)：当前阶段、当前任务、阻塞、**待用户决策**。
2. 读 [logs/HANDOFF.md](logs/HANDOFF.md) **最上面一条**：上次做到哪、有什么坑。
3. 打开当前任务卡 `tasks/T-xxxx-*.md`：目标、范围、验收标准、进度日志。
4. 任务依赖没完成，或卡在用户决策 → **先问用户，不要猜**。
5. 用户本次给了新指令 → 以用户为准；和任务卡冲突时，**先改任务卡再动手**。

## 工作中

- **WIP = 1**：同一时间只允许一个 `in-progress` 任务。
- 范围变了 → 改任务卡；技术选型/架构变了 → 写或改 ADR（[docs/decisions/](docs/decisions/)）；功能变了 → 改 [docs/product/features.md](docs/product/features.md)。
- 不确定的事实标「待核实」，**不编造**。[docs/research/](docs/research/) 下的调研报告是**只读快照**，更正写进新的复核文件。
- 代码放 `app/`（M2 阶段创建），遵守 [docs/architecture/modules.md](docs/architecture/modules.md) 的模块依赖规则。
- 验证按 [docs/workflow/verification.md](docs/workflow/verification.md) 的层级（L0–L4）；做不到的验证要明确写出来，不能假装通过。

## 会话结束（必做）

1. 更新任务卡：`status` + 进度日志（做了什么、没做什么、验证证据）。
2. 同步 [tasks/BOARD.md](tasks/BOARD.md) 中的状态。
3. 更新 [STATUS.md](STATUS.md)：当前任务、下一步、阻塞、待决策、更新日期。
4. 在 [logs/HANDOFF.md](logs/HANDOFF.md) **顶部**追加一条交接记录（模板见该文件）。
5. 运行 `python tools/check_repo.py`，**必须通过**（0 error）。
6. Git：按 [STATUS.md 的 D-05](STATUS.md) 执行。用户于 2026-11-20 授权初始化、创建私有远端、首次提交和推送，以及本轮 CI 修复和后续任务的提交、推送。后续会话从 D-05 核对授权范围。

## 硬规则

- **语言**：文档与沟通用中文；代码标识符和代码注释用英文；新建文件名用英文/ASCII（历史调研文档除外）。
- **日期**一律写绝对日期 `YYYY-MM-DD`。
- **ID 永不复用、永不改号**：任务 `T-MMNN`（MM = 里程碑号）、ADR `ADR-NNNN`、功能 `F-NN`、决策 `D-NN`。
- **隐私**：朋友的照片、祝福、语音等个人素材只放 `content/private/`（已 gitignore），**绝不进仓库、不进 CI**。
- **许可证**：依赖和素材只用 MIT / BSD / Apache-2.0 / OFL / CC0 等宽松许可；GPL、LGPL、非商用（NC）一律不用。
- **不碰**：企业证书分发、越狱、共享 Apple 账号、私有 API。
- **称呼**：用户没说明过朋友的性别，文档里统一写「朋友」。

## 仓库地图

```
CLAUDE.md            ← 你在这里：会话协议与硬规则
AGENTS.md            ← 给其他 AI 代理的入口（指向本文件）
STATUS.md            ← 当前状态快照（每次会话必读、必更新）
README.md            ← 给人看的项目总览
docs/
  charter.md         ← 项目章程：目标、约束、成功标准
  decisions/         ← ADR 架构决策记录（含索引）
  product/           ← PRD、功能清单 features.md、易用性原则
  architecture/      ← 架构总览、模块卡 modules.md
  workflow/          ← 会话协议、任务体系、验证矩阵、约定、执行代理提示词 executor-prompt.md
  research/          ← 调研报告（只读快照）+ 事实复核
tasks/
  BOARD.md           ← 任务看板（里程碑 → 切片 → 状态）
  _TEMPLATE.md       ← 任务卡模板
  T-xxxx-*.md        ← 任务卡（一个切片一个文件）
logs/HANDOFF.md      ← 会话交接日志（新的在上）
content/             ← 礼物素材说明；private/ 放个人素材（不入库）
tools/               ← check_repo.py（仓库自检）、md_to_docx.py（Markdown 转 Word）
app/                 ← 代码（M2 阶段创建）
```
