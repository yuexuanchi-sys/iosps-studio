# 架构总览

- **状态**：v0.1（2026-11-20）。分层规则已定（ADR-0006，Accepted）；首版采用 AppMac（ADR-0003）。
- **关联**：[modules.md](modules.md)、ADR-0001 / 0002 / 0004 / 0006

## 1. 分层

```
┌──────────────────────── L3 界面层（SwiftUI）───────────────────────┐
│                     AppMac（macOS 壳）                                 │
│              DesignSystem（共享组件、主题、动效）                  │
└───────────────────────────────┬────────────────────────────────────┘
                                │ 只能向下依赖
┌──────────────── L2 引擎层（Apple 框架，CI 上测试）────────────────┐
│  ImageEngine          VideoEngine           MediaIO               │
│  Core Image/Metal     AVFoundation          Photos/文件/权限       │
│  Vision 抠图/人脸      照片转视频/导出        缩略图               │
└───────────────────────────────┬────────────────────────────────────┘
┌──────────────── L1 纯逻辑层（纯 Swift，Windows 可测）──────────────┐
│  BirthdayCore     TemplateKit      TimelineKit      GiftKit        │
│  工程模型/撤销栈   模板 JSON/布局   时间轴/时长计算   日期/倒计时/彩蛋 │
└────────────────────────────────────────────────────────────────────┘
          资源：Assets（LUT、贴纸、字体、音乐、模板 JSON + 许可证登记）
```

**核心思想**：所有"编辑"都是对 L1 中一个 `Codable` 模型的修改（可撤销、可保存）；L2 引擎只负责把模型**渲染**成图片 / 视频；L3 只负责展示模型和发出命令。

## 2. 数据流（以修图为例）

```
用户拖动"亮度"滑杆
  → L3 发出命令 SetAdjustment(.brightness, 0.2)
  → L1 BirthdayCore：命令进入撤销栈，修改 PhotoEditDocument（配方 recipe）
  → L2 ImageEngine：根据 recipe 生成 CIImage 滤镜链 → 渲染预览代理图
  → L3 刷新画布
保存时：ImageEngine 用原图分辨率渲染 → MediaIO 写入相册 / 文件
```

回忆短片 / 剪辑同理：`TemplateKit` + `TimelineKit` 生成 `Timeline` 模型 → `VideoEngine` 构建 AVComposition 预览 / 导出。

## 3. 代码目录与规划

SwiftPM 已接入四个纯逻辑模块和 macOS 专用 DesignSystem。AppMac 用 XcodeGen 生成工程，共用冒烟首屏快照组件；L2 引擎与正式快照用例随各自切片接入。

```
app/
├── Package.swift            # SwiftPM：L1 + L2 + DesignSystem
├── project.yml              # XcodeGen：App target（AppMac）
├── Sources/
│   ├── BirthdayCore/  TemplateKit/  TimelineKit/  GiftKit/        # L1
│   ├── ImageEngine/   VideoEngine/  MediaIO/                       # L2 规划
│   ├── BirthdaySmokeSnapshot/                                     # 首屏 PNG 入口
│   └── DesignSystem/                                               # L3 共享
├── Apps/
│   └── Mac/                 # AppMac 壳
├── Resources/               # 可以公开的内置素材（LUT、贴纸、模板、字体、音乐）
└── Tests/
    ├── BirthdayCoreTests/ …                                         # L1：Windows + CI
    ├── ImageEngineTests/ …                                          # L2：CI
    └── SnapshotTests/                                               # L3：CI 截图
.github/workflows/ci.yml     # 仓库根目录（T-0005 / T-0202）
```

个人素材在目标 Mac 独立导入，包结构见 [素材清单](../../content/README.md)。

## 4. macOS 交互适配

| 方面 | macOS |
|---|---|
| 导航 | 侧栏切换、顶部工具栏、菜单和键盘快捷键 |
| 选图 | Finder 选择与拖拽、可选照片图库入口 |
| 画布 | 触控板 / 滚轮缩放，鼠标拖动 |
| 保存 | 系统保存面板写文件，可使用系统分享 |
| 生日体验 | App 打开时展示祝福，可手动重播 |

## 5. 关键技术风险（跟踪在对应任务里）

| 风险 | 应对 | 任务 |
|---|---|---|
| 大图内存（4800 万像素） | 预览用代理图，导出时再按原图分辨率分块渲染 | T-0401 |
| 色彩空间 / EXIF 方向 | 统一用 Display P3 工作空间，导入时校正方向 | T-0205 |
| 视频导出发热 / 被系统杀掉 | 进度显示、可取消、分段写入 | T-0505 |
| 没有 Mac 预览 UI | 截图验证管线 | T-0203 |
