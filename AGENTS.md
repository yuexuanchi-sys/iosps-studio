# AGENTS.md

本仓库的会话协议和硬规则写在 **[CLAUDE.md](CLAUDE.md)**，对所有 AI 代理（Codex / GPT / Claude / 其他）同样适用。开始任何工作前请完整阅读：

1. [CLAUDE.md](CLAUDE.md) —— 会话协议与硬规则
2. [STATUS.md](STATUS.md) —— 当前状态
3. [docs/workflow/executor-prompt.md](docs/workflow/executor-prompt.md) —— 执行代理的工作方式（连续执行、质量标准、诚实规则、停止条件）

收尾前必须运行 `python tools/check_repo.py`，结果必须是 0 error。
