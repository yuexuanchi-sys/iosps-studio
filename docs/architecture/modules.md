# 模块卡（Module Catalog）

> 每个模块一张卡。动某个模块之前先读它的卡；接口或状态变了要同步更新这里。
> **状态**：`planned`（只有设计）→ `scaffolded`（已接入工程，具备首批可调用实现）→ `active`（开发中）→ `stable`（功能完整、测试覆盖）。
> **验证层级** L0–L4 见 [verification.md](../workflow/verification.md)。

## L1 纯逻辑层（禁止 import Apple 专有框架）

### BirthdayCore
- **状态**：active（工程模型与命令历史经首次 CI 验证）
- **职责**：通用基础 —— 工程文件模型（`Project`、`PhotoEditDocument`、`VideoProject`）、命令模式 + 撤销 / 重做栈、草稿自动保存协议、ID / 时间工具。
- **对外接口**：`Project` v1 封装照片或视频草稿，`MediaID` 引用本地库；`EditCommand<State>` 在值语义状态上执行，`UndoStack<State>` 保留 20 步；`DraftStore` 为 Sendable 异步协议，磁盘存储由 MediaIO 实现。
- **依赖**：无。
- **验证**：L1 单测（Windows / CI）。
- **任务**：T-0204

### TemplateKit
- **状态**：active（短片模板 v1 经首次 CI 验证）
- **职责**：模板 JSON 的格式定义、解析和校验 —— 回忆短片模板（每一幕的时长、转场、Ken Burns 运镜、文字、滤镜、音乐段落）、海报 / 贺卡模板、拼图模板；布局计算（输出纯几何数据）。
- **依赖**：BirthdayCore。
- **接口**：`MemoryTemplate` 按 v1 解码、循环镜头、约束过渡区间并保存音乐资源引用。字段和示例见 [短片模板 v1](../product/memory-template-format.md)。
- **验证**：L0（JSON 结构）+ L1 单测。
- **任务**：T-0501、T-0702、T-0704

### TimelineKit
- **状态**：active（单轨整数帧模型经首次 CI 验证）
- **职责**：视频时间轴模型与时间计算 —— 片段（素材引用、入点出点、变速）、转场重叠、总时长、按音乐时长 / 节拍给照片分配时长、分割和排序操作（都以命令的形式提供）。
- **依赖**：BirthdayCore。
- **接口**：`TimelineClip` 保存源区间，`Timeline` 校验切点／叠化并生成起始帧及总时长；帧率和时长上限由 BirthdayCore 的 `VideoTiming` 提供。
- **验证**：L1 单测（时间计算必须有充分的边界测试）。
- **任务**：T-0501、T-0504、T-0601 ~ T-0603

### GiftKit
- **状态**：active（日期计算和回忆包清单经首次 CI 验证）
- **职责**：生日体验的逻辑 —— 生日 / 年龄 / 倒计时 / 相识天数计算、"是不是生日当天"的判断、彩蛋触发规则（连点次数、暗号匹配）、回忆内容清单（`memories.json`）的模型和解析。
- **依赖**：跨平台 Foundation；目前无需链接 BirthdayCore。
- **接口**：`LocalDay` 与 `GiftCalendar.metrics(on:birthday:metOn:)` 处理公历自然日和闰日周年；`GiftManifest` 解析 v1 回忆包、排序事件并限制相对路径。文件系统验证由导入层完成。
- **验证**：L1 单测（日期计算覆盖时区、闰年 2 月 29 日）。
- **任务**：T-0301 ~ T-0306

## L2 引擎层（Apple 框架，CI 上验证）

### ImageEngine
- **状态**：planned
- **职责**：把 `PhotoEditDocument` 的配方渲染成图片 —— Core Image 滤镜链、调整、LUT（`CIColorCube`）、裁剪旋转、文字 / 贴纸 / 涂鸦合成、马赛克；Vision 抠图、人脸检测；预览代理图与原图分辨率导出。
- **依赖**：BirthdayCore、TemplateKit；Core Image、Metal、Vision、CoreText。
- **验证**：L2（CI 单测：用固定测试图渲染，比对像素或哈希）+ L3（截图）。
- **任务**：T-0401 ~ T-0408、T-0701 ~ T-0704

### VideoEngine
- **状态**：planned
- **职责**：把 `Timeline` 渲染成视频 —— 构建 AVComposition / VideoComposition / AudioMix、自定义 compositor（转场、滤镜、文字）、照片转视频（AVAssetWriter，Ken Burns）、预览用 PlayerItem、导出（进度、取消）。
- **依赖**：BirthdayCore、TimelineKit、TemplateKit、ImageEngine（共用滤镜）；AVFoundation、Core Image。
- **验证**：L2（CI 上导出短视频，检查时长、分辨率、帧数，抽帧截图）。
- **任务**：T-0502 ~ T-0505、T-0602 ~ T-0606

### MediaIO
- **状态**：active（磁盘草稿、素材发布和 JPEG 方向经首次 CI 验证；全格式、色彩与 Finder 集成待验收）
- **职责**：素材导入导出和权限 —— macOS 文件选择与拖拽、可选照片图库入口、保存到文件、缩略图生成、EXIF 方向和色彩空间规范化、`DraftStore` 的文件实现。**唯一允许出现 `#if os()` 的 L2 模块**。
- **接口**：`FileDraftStore(directory:)` 用 actor 串行化草稿操作，按项目 UUID 原子替换完整 JSON。App 将其放在应用数据目录并共享同一个实例。
- **接口**：`MediaLibrary(directory:)` 保留源文件副本，用 `MediaID` 恢复引用。导入成功时发布最多 512 像素的 Display P3 PNG 和原件，失败时逐项反馈。
- **依赖**：BirthdayCore；Foundation、ImageIO、CoreGraphics、AVFoundation、UniformTypeIdentifiers。
- **验证**：L2 + L4（权限弹窗只能在真机上验证）。
- **任务**：T-0205、T-0206、T-0207、T-0408

## L3 界面层

### DesignSystem
- **状态**：active（首屏基础组件经 CI 构建及冒烟截图回读）
- **职责**：共享的 SwiftUI 组件 —— 主题（颜色、字体、圆角）、按钮、滑杆、底部工具栏、空状态、进度视图、生日动效（烟花、彩带）。
- **依赖**：SwiftUI。
- **验证**：L3 快照截图。
- **任务**：T-0103（规范）、T-0201（脚手架）、各 UI 任务

### AppMac / AppiOS（平台壳）
- **状态**：AppMac active（arm64 Release 经 CI 构建）；AppiOS 延后，见 [ADR-0003](../decisions/ADR-0003-target-platform.md)。
- **职责**：App 入口、导航、各页面组装、Mac 菜单、快捷键和全屏生日模式。
- **依赖**：所有下层模块。
- **验证**：L2 构建 + L3 UI 测试截图 + L4 真机验收。
- **任务**：T-0201、T-03xx、T-0705、T-08xx
- **隔离原型**：T-0009 的 SwiftUI 礼物界面调用 GiftKit、Compositor 画布和工程控制器。App 持有工作区，生日和回忆页面切换时保留编辑会话。照片工程由 Compositor 的 `.comp` 文件包管理。

## 资源：Assets
- **状态**：planned
- **职责**：内置 LUT、贴纸、字体、音乐、模板 JSON；`app/Resources/LICENSES.md` 登记每一项素材的来源和许可证（F-26 的数据来源）。
- **规则**：没有登记许可证的素材不许放进来。
- **任务**：T-0103、T-0404、T-0406、T-0506、T-0706
