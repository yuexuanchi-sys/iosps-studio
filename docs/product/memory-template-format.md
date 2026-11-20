# 回忆短片模板 v1

模板是可在本机使用的 UTF-8 JSON。应用用同一套 30 fps 整数帧解释持续时间和转场，单片最长 10 分钟。模板给出重复的镜头样式，时间轴引用用户实际选中的素材。

```json
{
  "formatVersion": 1,
  "id": "sample-sundays",
  "name": "周日回忆",
  "scenes": [
    {
      "frames": 90,
      "transitionFrames": 12,
      "motion": "zoomIn",
      "caption": "那天",
      "filterID": "warm"
    },
    {
      "frames": 60,
      "transitionFrames": 0,
      "motion": "panRight"
    }
  ],
  "music": {
    "assetID": "sample-piano",
    "startFrame": 30,
    "frames": 120
  }
}
```

| 字段 | 规则 |
|---|---|
| `formatVersion` | 目前为整数 1 |
| `id`、`name` | 非空。内置清单使用唯一 ID |
| `scenes` | 至少一个镜头。按素材索引循环取模板镜头，直到素材用完 |
| `frames` | 正整数且 ≤ 18,000；视频源区间须由渲染端按可用素材时长约束 |
| `transitionFrames` | 从该镜头到下一镜头的叠化帧数，0 表示切换；最后输出镜头没有下一个素材时省去。每个镜头的两侧叠化不能重合 |
| `motion` | `still`、`zoomIn`、`zoomOut`、`panLeft`、`panRight` |
| `caption`、`filterID` | 可省略。滤镜 ID 由内置许可登记的资源表解析 |
| `music` | 可省略。指定许可表中的音频 ID 与帧范围，`startFrame` 从 0 起，`frames` 为正整数 |

示例中的资源 ID 用于说明字段。T-0506 负责成品模板和对应的许可资源。音频超出范围、素材比模板镜头短等源文件条件由 T-0502/T-0504 的组装层校验。短片导出的用户验收见 [PRD F-15](prd.md)。
