---
id: T-0104
title: 礼物素材清单与收集
milestone: M1
status: blocked
priority: P0
modules: GiftKit
features: F-01, F-02, F-03, F-04, F-05
depends: T-0101
verify: L0
owner: 用户
updated: 2026-11-20
---

# T-0104 · 礼物素材清单与收集

## 目标
列出礼物体验需要的全部个人素材，用户按清单收集好，放进 `content/private/`（不入库），并约定好目录结构，方便后续由程序读取。

## 范围
**做：**
- 在 [content/README.md](../content/README.md) 中写好素材清单和目录约定（AI）；
- 用户收集：合照 / 回忆照片（按年份或事件分组）、每组照片的一句话说明、生日祝福文字、生日歌 / 语音祝福录音、彩蛋暗号和彩蛋内容、重要日期（生日、相识纪念日）；
- 定义 `content/private/memories.json` 的格式（GiftKit 会读取）。

**不做：** 把素材打包进 App（T-0302）。

## 验收标准
- [x] AC1：content/README.md 里有完整清单和 memories.json 的格式示例（示例里不出现真实信息）。 证据：content/README.md 的完整清单与 JSON 示例已交叉核对，Python 解析成功，引用均为相对路径且 .gitignore 包含 content/private/。
- [ ] AC2：用户确认素材已经放好（AI 只检查文件结构和数量，不把内容写进任何会入库的文件）。

## 需要用户提供 / 确认
- 全部个人素材。**提示**：可以从现在开始陆续收集，不用等到这个任务开工。

## 实施要点
- 假设：礼物是本地文件夹，提供带 schemaVersion 的清单、相对路径规则和无真实信息的最小示例。
- 定义原子替换、日期和排序，检查忽略规则；等待用户仅确认目录结构与数量。

## 进度日志
- 2026-11-20：创建。
- 2026-11-20：依赖 T-0101 的 v1.0 执行稿；按本次连续推进授权，产品确认保留在 AC，稿件进入 review 后可继续该切片。
- 2026-11-20：AC1 完成；AC2 需要用户提供并确认素材。用户可在仓库 PowerShell 中运行 `New-Item -ItemType Directory -Force content/private/memories, content/private/audio`，按清单准备并只报数量。未访问个人目录。
