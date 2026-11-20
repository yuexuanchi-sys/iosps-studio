# ADR-0002：视频处理不使用 FFmpeg，只用 AVFoundation

- 状态：Accepted
- 日期：2026-11-20
- 关联：[R01 §4.3](../research/调研报告.md)、[R03 §1.1](../research/R03-fact-check-2026-11-20.md)、F-15 ~ F-20、F-30

## 背景

FFmpeg 是最常见的音视频工具，但在 iOS 上最常用的封装 ffmpeg-kit **已归档退役**（2026-07-02 复核：`archived = true`），而且是 **LGPL-3.0** 许可，App Store 分发的合规风险较高。

## 决策

- 剪辑、拼接、裁剪、变速、转场、字幕、BGM、画中画、导出：全部用 **AVFoundation**（`AVMutableComposition`、`AVMutableVideoComposition` + 自定义 compositor、`AVAssetExportSession`、`AVAssetReader/Writer`）。
- 逐帧滤镜和转场渲染：**Core Image**（必要时用 Metal）。
- 照片生成视频（回忆短片）：`AVAssetWriter` + `CVPixelBufferPool`。
- **不支持**冷门格式导入（MKV/AVI 等）；目标素材是 iPhone 拍摄的 HEVC / H.264。

## 备选方案

| 方案 | 结论 |
|---|---|
| ffmpeg-kit | ❌ 已归档 + LGPL |
| 自己编译 FFmpeg xcframework | ❌ 维护成本高，许可同样麻烦，而且这个项目用不上 |

## 后果

- ✅ 零第三方依赖，硬件编解码，性能好，许可干净。
- ⚠️ 导入格式受限（可以接受）。
