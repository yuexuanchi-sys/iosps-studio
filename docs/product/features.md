# 功能清单（Feature Matrix）

> 功能 ID `F-NN` 永不复用。优先级：**P0** = 生日前必须有；**P1** = 尽量有，可以生日后更新；**P2** = 有余力再做。
> “任务”列指向 [任务看板](../../tasks/BOARD.md)。平台列以 [ADR-0003](../decisions/ADR-0003-target-platform.md) 为准，— 表示当前版本范围外。

## A. 生日体验层

| ID | 功能 | 优先级 | 模块 | 任务 | 平台 | 说明 |
|---|---|---|---|---|---|---|
| F-01 | 生日主页：祝福语 + 照片墙 + 倒计时 / 年龄 / 相识天数 | P0 | GiftKit, DesignSystem | T-0301 | Mac | 打开 App 的第一屏 |
| F-02 | 回忆时间轴：按年份 / 事件浏览照片 | P0 | GiftKit, MediaIO | T-0302 | Mac | 内容来自 独立本地导入包，素材只放 content/private |
| F-03 | 隐藏彩蛋：连点爱心与键盘等价入口 | P0 | GiftKit, DesignSystem | T-0303 | Mac | 至少 1 个 |
| F-04 | 生日歌 / 语音祝福播放 | P0 | GiftKit | T-0304 | Mac | 用户自己录制，可离线播放 |
| F-05 | 生日当天全屏祝福动画 | P0 | GiftKit, DesignSystem | T-0303 | Mac | App 打开时触发 |
| F-25 | 从 App 内主动进入全屏生日模式 | P1 | App 壳 | T-0705 | Mac | |
| F-27 | 心愿清单 / 时光胶囊 | P2 | GiftKit | — | Mac | |

## B. 照片编辑（P图）

| ID | 功能 | 优先级 | 模块 | 任务 | 平台 | 说明 |
|---|---|---|---|---|---|---|
| F-06 | 导入照片 / 视频（相册 / 文件） | P0 | MediaIO | T-0205, T-0207 | Mac | Finder 文件选择与拖拽，照片图库作为补充入口 |
| F-14 | 撤销 / 重做（≥ 20 步）+ 草稿自动保存 | P0 | BirthdayCore, MediaIO | T-0204, T-0206, T-0401 | Mac | |
| F-07 | 裁剪 / 旋转 / 翻转 / 比例 | P0 | ImageEngine | T-0402 | Mac | |
| F-08 | 基础调整：亮度、对比度、饱和度、曝光、色温、高光阴影、锐化、暗角 | P0 | ImageEngine | T-0403 | Mac | Core Image |
| F-09 | 滤镜预设（≥ 12 个，基于 LUT） | P0 | ImageEngine, Assets | T-0404 | Mac | LUT 自己生成，保证许可干净 |
| F-10 | 文字（字体、颜色、描边、阴影） | P0 | ImageEngine, DesignSystem | T-0405 | Mac | 字体：系统苹方 + OFL 字体 |
| F-11 | 贴纸（内置生日贴纸包） | P0 | ImageEngine, Assets | T-0406 | Mac | 自绘 / CC0 |
| F-12 | 涂鸦 + 马赛克 | P0 | ImageEngine | T-0407 | Mac | |
| F-13 | 保存到文件、系统分享 | P0 | MediaIO | T-0408 | Mac | |
| F-21 | 一键抠图 + 换背景 | P1 | ImageEngine（Vision） | T-0701 | Mac | macOS 前景分割 |
| F-22 | 生日海报 / 贺卡模板 | P1 | TemplateKit, ImageEngine | T-0702 | Mac | |
| F-23 | 美颜：磨皮 / 美白 | P1 | ImageEngine（Vision 人脸） | T-0703 | Mac | |
| F-24 | 拼图（九宫格 / 自由拼 / 长图） | P1 | TemplateKit, ImageEngine | T-0704 | Mac | |
| F-28 | AI 超分 / 老照片修复 | P2 | ImageEngine（Core ML） | — | Mac | 模型许可证要逐个核实 |

## C. 视频

| ID | 功能 | 优先级 | 模块 | 任务 | 平台 | 说明 |
|---|---|---|---|---|---|---|
| F-15 | **一键回忆短片**：选照片 / 视频 → 选模板 → 自动成片（≥ 8 个模板） | P0 | TemplateKit, TimelineKit, VideoEngine | T-0501 ~ T-0506 | Mac | 核心卖点 |
| F-16 | 多段拼接、裁剪、分割、排序 | P1 | TimelineKit, VideoEngine | T-0602 | Mac | |
| F-17 | 变速（0.25x–4x） | P1 | TimelineKit, VideoEngine | T-0603 | Mac | |
| F-18 | 转场（叠化、推拉、擦除等） | P1 | VideoEngine | T-0604 | Mac | |
| F-19 | 背景音乐、原声混合、淡入淡出、录音配音 | P1 | VideoEngine | T-0605 | Mac | 内置音乐必须是 CC0 或自录 |
| F-20 | 字幕 / 文字 | P1 | VideoEngine | T-0606 | Mac | |
| F-30 | 画中画 | P2 | VideoEngine | — | Mac | |

## D. 基础设施类

| ID | 功能 | 优先级 | 模块 | 任务 | 平台 | 说明 |
|---|---|---|---|---|---|---|
| F-26 | 开源许可 / 素材致谢页 | P0 | DesignSystem, Assets | T-0706 | Mac | 宽松许可也要求保留声明 |
| F-29 | AR 生日蛋糕 | P2 | — | — | — | 仅保留功能编号 |

## 变更记录
- 2026-11-20：根据 R01 §5.2 / §5.5 建立初版。
- 2026-11-20：按 macOS PRD v1.0 统一平台和交付入口，保留 P0 全量，基础视频剪辑作为 P1 更新。
