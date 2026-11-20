---
id: T-0306
title: GiftKit 回忆包清单
milestone: M3
status: blocked
priority: P0
modules: GiftKit
features: F-02,F-03,F-04
depends: T-0201, T-0305
verify: L0,L1
owner: AI
updated: 2026-11-20
---

# T-0306 · GiftKit 回忆包清单

## 目标
解析公开规范中的回忆包清单，为后续本地导入提供安全的相对路径和稳定排序。

## 背景与依据
- [清单 v1](../content/README.md)、[PRD](../docs/product/prd.md)、[模块卡](../docs/architecture/modules.md)。

## 范围
纯逻辑解码、版本/字段/相对路径检查、按日期排序。文件存在、符号链接、解码与复制在 T-0302 的导入层验证，可用虚构数据测试 L1。

## 验收标准
- [ ] AC1：最小和完整 v1 可解析；拒绝错版本、重复事件、空事件照片、非法日期及逃逸路径。
- [ ] AC2：事件日期降序，同日保持录入顺序，照片顺序保留。
- [ ] AC3：`swift test --package-path app --filter GiftManifestTests` 通过。

## 实施要点
- 假设：纯解析器只读 JSON，路径仅做词法与扩展名校验；由本地导入层处理文件实际类型、链接与复制。\n- 先写最小清单、稳定排序和失效字段测试，再接入 LocalDay 与 Decodable。

## 进度日志
- 2026-11-20：从看板滚动细化。
- 2026-11-20：回忆包解析与 7 个单测已写齐，待验证（L1）。`swift test --package-path app --filter GiftManifestTests` 当前找不到 swift；安装工具链或开通 CI 后执行，预期 7 用例 0 失败。已人工核对 Codable 字段、字节级路径校验、顺序规则与清单；L0 0 error。
