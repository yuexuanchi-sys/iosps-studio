---
id: T-0305
title: GiftKit 生日与相识日期
milestone: M3
status: blocked
priority: P0
modules: GiftKit
features: F-01,F-05
depends: T-0201
verify: L0,L1
owner: AI
updated: 2026-11-20
---

# T-0305 · GiftKit 生日与相识日期

## 目标
让礼物在朋友所在时区按自然日显示倒计时、年龄、相识天数与生日当天状态。

## 背景与依据
- [PRD F-01/F-05](../docs/product/prd.md)、[素材清单](../content/README.md)、[模块卡](../docs/architecture/modules.md)。

## 验收标准
- [ ] AC1：严格接受公历 YYYY-MM-DD；非法日期和越界值拒绝，编码往返稳定。
- [ ] AC2：倒计时和年龄在生日、跨年、闰日、时区与夏令时边界可复现；缺日期及未来日期行为明确。
- [ ] AC3：`swift test --package-path app --filter GiftCalendarTests` 通过。

## 实施要点
- 假设：闰日生日在平年 2 月 28 日庆祝（避免跨月）；按公历日序计算，免受夏令时影响。
- 测试先覆盖非法日期、世纪和回退、跨年、两地时区、DST、缺失及未来日期，再实现纯逻辑。

## 进度日志
- 2026-11-20：从看板滚动细化。
- 2026-11-20：日期实现与 8 个单测已写齐，待验证（L1）。`swift test --package-path app --filter GiftCalendarTests` 当前找不到 swift；工具链或 CI 可用后预期 8 用例、0 失败。人工检查自然日、闰年和年份上界，L0 0 error。
