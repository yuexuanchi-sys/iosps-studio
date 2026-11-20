# 约定（Conventions）

## 语言与命名

| 对象 | 约定 | 例子 |
|---|---|---|
| 文档内容、和用户沟通 | 中文 | — |
| 新建文件名、目录名 | 英文小写 + 短横线（ASCII） | `session-protocol.md` |
| 历史调研文档 | 保留原中文文件名（只读快照） | `调研报告.md` |
| Swift 类型 / 函数 | 英文，遵循 Swift API Design Guidelines | `PhotoEditDocument`、`apply(to:)` |
| 代码注释 | 英文，只解释"为什么" | — |
| 界面文案 | 中文，集中放在 `Localizable.xcstrings` | — |
| 日期 | 绝对日期 `YYYY-MM-DD` | 2026-11-20 |

## 文档写法

- 结论写在最前面；尽量用表格和清单，少写大段文字。
- 引用外部事实时附上来源链接；没有来源的写「待核实」。
- 一份文档只回答一类问题；同一个事实只在一个地方写详细，其他地方用链接引用。
- 文档之间用**相对链接**；`check_repo.py` 会检查链接是否失效。

## Git（T-0004 初始化之后生效）

- 默认分支 `main`；每个任务一个分支 `t-MMNN-short-title`，完成后合并回 `main`（也可以按用户的意愿直接在 `main` 上提交，D-05 决定）。
- 提交信息：`T-MMNN: 动词开头的简述`，例如 `T-0204: add UndoStack with tests`。
- 永远不提交：`content/private/`、证书和密钥（`*.p12`、`*.p8`、`*.mobileprovision`）、`.env`、生成的 `.xcodeproj`、构建产物、`artifacts/`。
- 依据 [STATUS.md 的 D-05](../../STATUS.md) 核对提交与推送权限。2026-11-20 授权覆盖首次上传及本轮 CI 修复和后续任务。

## 隐私

- 朋友的照片、视频、语音、祝福文字 → 只放 `content/private/`（已 gitignore）。
- 截图、日志、测试数据里**不能出现**朋友的真实照片和个人信息；测试用 CC0 示例图。
- 公开仓库的名字和描述不要暴露礼物对象（避免剧透，也保护隐私）。

## 依赖与素材

- 新增第三方依赖前：在任务卡里写明理由、许可证、维护状态，并在 `app/Resources/LICENSES.md` 登记。
- 依赖版本锁定（SwiftPM 用 `exact` 或 `upToNextMinor`）。
- 素材（字体 / 音乐 / 贴纸 / LUT）同样要登记来源和许可证。
