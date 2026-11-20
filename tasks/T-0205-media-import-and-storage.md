---
id: T-0205
title: MediaIO 导入与缩略图
milestone: M2
status: ready
priority: P0
modules: MediaIO
features: F-06
depends: T-0201, T-0207
verify: L0,L2,L4
owner: AI
updated: 2026-11-20
---

# T-0205 · MediaIO 导入与缩略图

## 目标
把 Finder 选择或拖放的媒体变成本地库引用，提供可显示的缩略图。草稿存储单独在 [T-0206](T-0206-file-draft-store.md) 验收。

## 背景与依据
- [PRD F-06 与 F-14](../docs/product/prd.md)、[模块卡](../docs/architecture/modules.md)、[T-0204](T-0204-birthday-core-projects-and-history.md)。

## 范围
接入 macOS 文件选择和拖入，利用 [T-0207](T-0207-local-media-library.md) 的素材库和缩略图。在同一批次处理中反馈逐项结果；用全部目标格式验证端到端导入。

## 验收标准
- [ ] AC1：常见 JPEG/PNG/HEIC/MOV/MP4 加载成功，混合批次逐项报告结果，源媒体保持只读。
- [ ] AC2：CI 固定样本验证照片方向／色彩和视频缩略图；原 AC2 的草稿原子替换和解码失败测试见 T-0206 的 AC2/AC3。
- [ ] AC3：目标 Mac 验证 Finder 选取、拖放及权限反馈。

## 进度日志
- 2026-11-20：从看板滚动细化。
- 2026-11-20：将草稿文件持久化及其原验收要求移到 T-0206，先验证 Foundation 文件行为，T-0205 保留媒体导入、缩略图和真机验收。
- 2026-11-20：素材库、逐项结果和缩略图实现拆成 T-0207。本卡保留全部格式的集成验收和 Finder 入口。
