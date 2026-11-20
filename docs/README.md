# 文档索引

| 目录 / 文件 | 内容 | 什么时候读 | 什么时候改 |
|---|---|---|---|
| [charter.md](charter.md) | 项目章程：目标、约束、成功标准、范围边界 | 第一次接触项目；判断"要不要做某件事" | 目标/约束/截止日期变化时 |
| [decisions/](decisions/README.md) | ADR 架构决策记录 | 想知道"为什么这样做" | 任何技术选型、架构、平台、分发相关决定 |
| [product/prd.md](product/prd.md) | 产品需求文档 | 做产品/UI 相关任务前 | 需求变化时 |
| [product/features.md](product/features.md) | 功能清单（F-NN）+ 优先级 + 模块/任务映射 | 拆任务、排优先级时 | 增删改功能或调整优先级时 |
| [product/ux-flows.md](product/ux-flows.md) | macOS 页面、线框、流程、快捷键 | 实现和验收 UI 时 | 交互变化时 |
| [product/visual-style.md](product/visual-style.md) | 配色、命名、图标和素材许可规范 | 实现主题与登记资源时 | 视觉和资源变化时 |
| [product/memory-template-format.md](product/memory-template-format.md) | 回忆短片模板字段及帧规则 | 制作模板及渲染时 | 文档格式变化时 |
| [product/ux-principles.md](product/ux-principles.md) | 易用性原则 + 明确不做的功能 | 做任何 UI 前 | 用户反馈改变原则时 |
| [architecture/overview.md](architecture/overview.md) | 架构总览：分层、目录规划、数据流 | 写代码前 | 架构变化时（同时写 ADR） |
| [architecture/modules.md](architecture/modules.md) | 模块卡：职责、接口、依赖、验证方式、状态 | 动某个模块前 | 模块接口/状态变化时 |
| [workflow/session-protocol.md](workflow/session-protocol.md) | 会话开始 / 进行中 / 结束的详细协议 | 每次会话（CLAUDE.md 是它的摘要） | 工作流调整时 |
| [workflow/task-system.md](workflow/task-system.md) | 里程碑、切片、任务卡、状态机、完成标准（DoD） | 新建/拆分任务时 | 任务体系调整时 |
| [workflow/verification.md](workflow/verification.md) | 没有 Mac 时的验证层级（L0–L4） | 声称"完成"之前 | 验证手段变化时 |
| [workflow/conventions.md](workflow/conventions.md) | 命名、语言、日期、Git、隐私等约定 | 新建文件/写代码时 | 约定变化时 |
| [workflow/executor-prompt.md](workflow/executor-prompt.md) | 执行代理提示词：连续执行、质量标准、诚实规则、停止条件 | 每次开新的 AI 会话时，复制给代理 | 工作流规则变化时（同步 CLAUDE.md） |
| [research/](research/README.md) | 调研报告（只读快照）+ 事实复核 | 需要背景资料/引用来源时 | 只新增复核文件，不改快照 |
