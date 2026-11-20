---
id: T-0207
title: MediaIO 本地素材库与缩略图
milestone: M2
status: blocked
priority: P0
modules: MediaIO
features: F-06
depends: T-0201
verify: L0,L2
owner: AI
updated: 2026-11-20
---

# T-0207 · MediaIO 本地素材库与缩略图

## 目标

从本地文件 URL 导入素材，保留原件，生成方向正确的受限大小缩略图，以媒体 UUID 恢复引用。

## 背景与依据

- [产品需求 F-06](../docs/product/prd.md)、[模块卡](../docs/architecture/modules.md)、[T-0205 Finder 导入](T-0205-media-import-and-storage.md)。

## 验收标准

- [ ] AC1：批量导入保持请求顺序，正确报告不支持与损坏项。读回已入库文件与源文件的字节一致。
- [ ] AC2：JPEG/PNG/HEIC 的缩略图应用源方向，MOV/MP4 应用视频首帧方向；缩略图长边不超过 512 像素，输出 Display P3 PNG。
- [ ] AC3：失败项不会发布可读取的半成品，同一 UUID 可重开读取。用 `swift test --package-path app --filter MediaLibraryTests` 运行本切片用例；视频和 HEIC 回归样本另由 T-0205 在 macOS 验证。

## 实施要点

- 假设：每项先写到应用数据目录的临时子目录，生成缩略图后同卷移动到 UUID 目录。批次中互不影响，权限只在复制源文件时需要。原件以字节保留，后续引擎按自己的色彩空间渲染。
- ImageIO 处理静态图方向，AVAssetImageGenerator 处理视频方向与首帧。禁止视频外部引用。512 像素缩略图用于小屏和 8 GB 参考机的媒体列表。[Apple ImageIO](https://developer.apple.com/documentation/imageio/cgimagesourcecreatethumbnailatindex%28_%3A_%3A_%3A%29) · [Apple 视频缩略图](https://developer.apple.com/documentation/avfoundation/avassetimagegenerator/image(at:))
- 先写合成图片、坏文件和批次边界测试，再实现文件与缩略图。Finder 的选择、拖放和权限交互由 T-0205 验收。

## 进度日志

- 2026-11-20：从 T-0205 细化引擎切片，保留 T-0205 的界面与全格式集成验收。
- 2026-11-20：`MediaLibrary`、`MediaThumbnailRenderer` 和 3 个测试已写齐，待验证（L2）。人工核对 UUID 发布路径、失败清理、Apple API 可用版本和 Swift actor 边界。合成 2×1 PNG 的块校验均通过。无外部依赖或素材；`check_repo` 为 0 error。本机没有 `swift`，在 macOS 跑 `swift test --package-path app --filter MediaLibraryTests`，预期 3 个测试、0 失败；HEIC、MOV、MP4 和 Display P3 ICC 的实际文件验收留在 T-0205。
