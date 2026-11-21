---
id: T-0207
title: MediaIO 本地素材库与缩略图
milestone: M2
status: done
priority: P0
modules: MediaIO
features: F-06
depends: T-0201
verify: L0,L2
owner: AI
updated: 2026-11-21
---

# T-0207 · MediaIO 本地素材库与缩略图

## 目标

从本地文件 URL 导入素材，保留原件，生成方向正确的受限大小缩略图，以媒体 UUID 恢复引用。

## 背景与依据

- [产品需求 F-06](../docs/product/prd.md)、[模块卡](../docs/architecture/modules.md)、[T-0205 Finder 导入](T-0205-media-import-and-storage.md)。

## 验收标准

- [x] AC1：批量导入保持请求顺序，正确报告不支持与损坏项。读回已入库文件与源文件的字节一致。run 44775125352 的 `orderedBatchPreservesOriginalAndSeparatesFailures` 通过。
- [x] AC2：[run 44922628475](https://github.com/yuexuanchi-sys/iosps-studio/actions/runs/44922628475)（`e4022477380b6a71b501309048dafa5fcb842761`）的 `swift test --package-path app` 通过 `supportedFormatsPublishOrientedDisplayP3Thumbnails`。合成 JPEG/HEIC 应用方向、PNG 正向、MOV/MP4 应用轨道 90° 变换，长边为 512，五张缩略图均是 Display P3 PNG，原件字节一致。日志 `artifacts/media/44922628475/run.log`。
- [x] AC3：失败项不会发布可读取的半成品，同一 UUID 可重开读取。run 44775125352 的 `swift test --package-path app` 实际执行了全部 3 个 `MediaLibraryTests`，含发布目录和重开检查。视频和 HEIC 回归样本仍为 AC2 与 T-0205 的验证项。

## 实施要点

- 假设：每项先写到应用数据目录的临时子目录，生成缩略图后同卷移动到 UUID 目录。批次中互不影响，权限只在复制源文件时需要。原件以字节保留，后续引擎按自己的色彩空间渲染。
- ImageIO 处理静态图方向，AVAssetImageGenerator 处理视频方向与首帧。禁止视频外部引用。512 像素缩略图用于小屏和 8 GB 参考机的媒体列表。[Apple ImageIO](https://developer.apple.com/documentation/imageio/cgimagesourcecreatethumbnailatindex%28_%3A_%3A_%3A%29) · [Apple 视频缩略图](https://developer.apple.com/documentation/avfoundation/avassetimagegenerator/image(at:))
- 先写合成图片、坏文件和批次边界测试，再实现文件与缩略图。Finder 的选择、拖放和权限交互由 T-0205 验收。
- 本次补测 `app/Tests/MediaIOTests/MediaLibraryTests.swift`。现场生成 768×384 PNG、JPEG、HEIC 和带 90° 轨道变换的 MOV、MP4，由 `MediaLibrary.importFiles` 导入，再回读原件和每张 P3 缩略图。预期原件字节一致，长边 512，JPEG／HEIC／视频变为竖图。主线 `swift test --package-path app --filter MediaLibraryTests` 预期五格式通过，其他 L2 验收沿用现有 CI。

## 进度日志

- 2026-11-20：从 T-0205 细化引擎切片，保留 T-0205 的界面与全格式集成验收。
- 2026-11-20：`MediaLibrary`、`MediaThumbnailRenderer` 和 3 个测试已写齐，待验证（L2）。人工核对 UUID 发布路径、失败清理、Apple API 可用版本和 Swift actor 边界。合成 2×1 PNG 的块校验均通过。无外部依赖或素材；`check_repo` 为 0 error。本机没有 `swift`，在 macOS 跑 `swift test --package-path app --filter MediaLibraryTests`，预期 3 个测试、0 失败；HEIC、MOV、MP4 和 Display P3 ICC 的实际文件验收留在 T-0205。
- 2026-11-20：[run 44775125352](https://github.com/yuexuanchi-sys/iosps-studio/actions/runs/44775125352) 中 3 个 `MediaLibraryTests` 通过，含 JPEG 旋转与 PNG 导入。AC2 仍需补合成 HEIC、MOV、MP4、超长边和 Display P3 色彩配置验证，在 macOS 跑 `swift test --package-path app --filter MediaLibraryTests`，预期所有格式方向、尺寸和 P3 profile 断言通过。T-0205 仍保留 Finder 与全格式集成验收。
- 2026-11-21：新增用例在 run 44922628475 用时 0.895 秒，SwiftPM 共 48 项、AppMac 宿主与 arm64 Release 均通过。自查通过：AC1–AC3 各有运行证据，无新增运行依赖、随包素材或越层调用，L0 0 error。T-0205 的 Finder、拖放及目标机权限门槛保留。
- 2026-11-21：`main` 源码 `524f39c41382d451212e5dc72a7d71b225e58813` 的自动 [run 44922945754](https://github.com/yuexuanchi-sys/iosps-studio/actions/runs/44922945754) 终态 success。
