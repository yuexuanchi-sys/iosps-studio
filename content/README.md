# 礼物素材与回忆包

个人素材只放在 `content/private/`。该目录是要私下交付的回忆包根目录，已在项目的 `.gitignore` 中排除。准备好后可在目标 Mac 预先导入，或者由朋友在 App 中选择文件夹。基础 ZIP、CI、截图和测试数据只使用公开或虚构素材。见 [PRD §3](../docs/product/prd.md)。

## 准备清单

| 项 | 推荐准备 | 写到哪里 |
|---|---|---|
| 精选照片、时间轴照片 | 先选 3–10 张 JPEG、PNG 或 HEIC，每个事件挑一张代表照 | `memories/`，主图填 `featuredPhoto` |
| 回忆说明 | 分年份／事件写日期、短标题、一句话说明 | `memories.json` 的 `memories` |
| 生日祝福 | 自己写一段，UTF-8 纯文本，可换行 | `wishes.txt` |
| 生日歌或语音祝福 | m4a 或 mp3；自录并确认有分发权 | `audio/` |
| 彩蛋 | 一段私下的祝福、暗号或梗；首版连点爱心即可打开 | `easter-egg.txt` |
| 重要日期 | 出生日期和认识的那天，有意留空时可省略相应字段 | `memories.json` 的 `birthday`、`metOn` |

在 PowerShell 中创建目录：

```powershell
New-Item -ItemType Directory -Force content/private/memories, content/private/audio
```

## 回忆文件夹结构

```text
content/private/
├── memories.json
├── wishes.txt
├── easter-egg.txt
├── memories/
│   └── sample-event/
│       └── sample-photo.jpg
└── audio/
    └── sample-wish.m4a
```

## 清单 v1

这个示例完全虚构。实际使用时在私密目录中另存为 UTF-8 JSON，再替换日期、说明和路径。

```json
{
  "schemaVersion": 1,
  "birthday": "2000-02-29",
  "metOn": "2024-05-04",
  "wishesPath": "wishes.txt",
  "audioPath": "audio/sample-wish.m4a",
  "easterEggPath": "easter-egg.txt",
  "featuredPhoto": "memories/sample-event/sample-photo.jpg",
  "memories": [
    {
      "id": "sample-event",
      "date": "2024-06-15",
      "title": "示例公园",
      "note": "用来说明文件结构的一张示例图。",
      "photos": [
        "memories/sample-event/sample-photo.jpg"
      ]
    }
  ]
}
```

| 字段 | 约定 |
|---|---|
| `schemaVersion`、`memories` | 必填。版本整数 1，`memories` 可为空数组 |
| `birthday`、`metOn`、`date` | 公历日期 `YYYY-MM-DD`，不带时间或时区；前两者可省略，事件日期必填 |
| `id`、`title`、`note` | 事件 ID 唯一，推荐小写 ASCII 短横线；标题必填，说明可省略 |
| `photos` | 每个事件提供至少一张照片，照片显示顺序按数组；事件按日期降序，同日期保持录入顺序 |
| `wishesPath`、`audioPath`、`easterEggPath`、`featuredPhoto` | 可省略；提供时必须引用存在且类型正确的普通文件 |
| 路径 | 以包根目录为基准，用 `/` 分隔。使用真实文件大小写。不得含空段、`.`、`..`、冒号、绝对路径、反斜杠和 ASCII 控制字符；路径组件不可用空格或点结尾。导入层拒绝符号链接和逃逸根目录的解析结果 |

GiftKit 解析清单和字段；Mac 导入层检查路径、类型和文件存在，验证全部引用后才替换当前礼物。无法读取的版本、字段或素材用可操作的错误反馈，保留前一版礼物。缺少可选字段时隐藏相应入口或指标；无回忆时允许使用示例。生日与相识计算由 GiftKit 处理，本机时区下按公历自然日。2 月 29 日在平年以 2 月末预演，交付前可确认该习惯。

准备完毕后，只需确认「素材已放好」及照片和录音数量。真实日期、祝福和暗号留在此目录。
