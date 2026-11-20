# 生日礼物 App（IOSPS）

给朋友的生日礼物：一个**简单易用**、又能真正拿来用的 P图 + 视频剪辑 App，带生日主题体验（回忆、彩蛋、祝福）。

| 项 | 现状 |
|---|---|
| 阶段 | macOS 产品定义及工程准备，进展见 STATUS |
| 目标平台 | **macOS**（2026-11-20 决定），见 [ADR-0003](docs/decisions/ADR-0003-target-platform.md) |
| 技术栈 | Swift / SwiftUI / Core Image / Metal / AVFoundation / Vision |
| 构建方式 | Windows 上写代码 → GitHub Actions 云端 macOS 构建、测试、打包 |
| 当前进度 | 见 [STATUS.md](STATUS.md) |

## 从哪里开始看

- **想知道现在做到哪了** → [STATUS.md](STATUS.md)
- **想看所有任务** → [tasks/BOARD.md](tasks/BOARD.md)
- **想看调研结论** → [docs/research/README.md](docs/research/README.md)
- **想看产品要做什么** → [docs/product/prd.md](docs/product/prd.md)、[docs/product/features.md](docs/product/features.md)
- **想看技术怎么搭** → [docs/architecture/overview.md](docs/architecture/overview.md)
- **想了解工作流** → [docs/workflow/session-protocol.md](docs/workflow/session-protocol.md)
- **想让 AI 代理接着干** → [docs/workflow/executor-prompt.md](docs/workflow/executor-prompt.md)（复制提示词 + 启动语）
- **文档总索引** → [docs/README.md](docs/README.md)

## 给协作者（包括 AI）的规则

全部写在 [CLAUDE.md](CLAUDE.md)。每次会话：先读 STATUS → 读最新交接记录 → 打开当前任务卡 → 干活 → 更新卡片 / 看板 / STATUS / 交接日志 → `python tools/check_repo.py` 自检通过。
