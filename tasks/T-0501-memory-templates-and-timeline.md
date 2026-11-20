---
id: T-0501
title: 回忆短片模板与时间轴核心
milestone: M5
status: blocked
priority: P0
modules: TemplateKit, TimelineKit
features: F-15
depends: T-0204
verify: L0,L1
owner: AI
updated: 2026-11-20
---

# T-0501 · 回忆短片模板与时间轴核心

## 目标
为照片／视频成片提供可复现的模板、剪辑区间和转场的帧级数学。

## 背景与依据
- [模块卡](../docs/architecture/modules.md)、[PRD F-15](../docs/product/prd.md)、[功能清单](../docs/product/features.md)。

## 范围
TemplateKit 解码带版本的成片模板，支持重复的一组镜头、镜头运动、过渡、叠字、滤镜和背景音乐片段引用。TimelineKit 表示有序素材区间、交界、合成起点与时长。L2 串接两者。实际渲染和八套成品模板由 T-0502 ~ T-0506 交付。

## 验收标准
- [ ] AC1：模板 v1 读取及结构校验，镜头顺序循环确定；坏版本、空镜头和非法范围有单测。
- [ ] AC2：时间轴可正确计算无转场与多段叠化，帧范围、空序列、精确边界及重复素材有单测。
- [ ] AC3：合法时间轴 Codable 往返，非法 JSON 通过同一验证拒绝。
- [ ] AC4：`swift test --package-path app` 运行所有模板与时间轴用例，0 失败。

## 实施要点
- 假设：首版渲染按 30 fps 整数帧计时，合成上限 10 分钟以保持预览和导出一致。
- 先写模板解析和时间轴边界用例，再实现两个独立 L1 模块。素材可重复引用；转场用帧数表示，拒绝三段同时重叠。

## 进度日志
- 2026-11-20：从看板滚动细化。
- 2026-11-20：两个 L1 模块与 10 个单测已写齐，待验证（L1）。文档示例 JSON 解析成功，L0 0 error；人工检查范围、转场重叠、Codable 恢复和模块依赖。工具链或 CI 可用后运行 `swift test --package-path app`，预期 MemoryTemplateTests 4、TimelineTests 6 用例，均 0 失败。
