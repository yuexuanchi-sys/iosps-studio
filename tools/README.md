# tools/

| 工具 | 作用 | 用法 |
|---|---|---|
| `check_repo.py` | **仓库自检**：必备文件、任务卡字段、看板与任务卡状态一致性、WIP=1、ADR 索引、相对链接是否失效 | `python tools/check_repo.py`（每次会话结束必须 0 error） |
| `md_to_docx.py` | 把 Markdown 报告转成排版好的 Word 文档（依赖 `python-docx`） | `python tools/md_to_docx.py <输入.md> [输出.docx]`，不传参数时默认转换 `docs/research/调研报告.md` |

扩展 `check_repo.py` 时，在这里同步更新说明。计划中的检查（T-0201 起）：L1 模块禁止 import Apple 专有框架；`app/Resources/LICENSES.md` 素材登记完整性。
