# 00 · Lead 亲自核实的关键事实（截至 2026-11-20）

> 本文件是《调研报告》的事实底稿：所有"已核实"条目均于 2026-11-20 直接抓取 GitHub API 或 Apple 官方页面确认；标注"待核实"的条目未拿到一手证据，报告中会明确区分。

## A. 你看到的"把 PS 重构成 8MB 小开源程序"是什么

### A1. 最可能的项目：Compositor（MIT，Swift，macOS）
- 仓库：https://github.com/robbietilton/Compositor
- 作者：Robbie Tilton（前 Apple / Google 设计师、工程师，参与过 Google Glass、Apple Vision Pro 相关项目）
- 一句话描述：**"The Photoshop alternative for Mac"**
- 实测数据（GitHub API）：语言 **Swift**；License **MIT**；★ **18,763**；fork 1,864；创建于 2026-09-16；最近推送 2026-11-19。
- 最新 Release：v1.6.14（2026-11-19），安装包 `Compositor.dmg` 大小 **8,941,446 字节 ≈ 8.5 MiB（约 8.9 MB）**——这就是"很小的程序 / 8MB"的来源。
- 系统要求：**macOS 26 Tahoe 及以上 + Apple Silicon**；源码构建需 Xcode 26+；官方**仅 macOS**，没有 iOS / Windows 官方版（Windows/Linux 有民间移植）。
- 能力（README 原文归纳）：图层与文件夹、Photoshop 全套混合模式、图层蒙版/剪贴蒙版、调整图层、滤镜图层、图层效果、选区（魔棒/对象选择/主体选择/内容感知填充）、画笔/修复/克隆/模糊/渐变/形状/文字、Camera Raw、PSD/PSB 导入、PNG/JPEG/PDF/GIF 导出、可被 AI Agent 编辑的 `.comp` 项目格式。
- 报道来源（可作为你回忆的印证）：
  - 波兰 ITHARDWARE：https://ithardware.pl/aktualnosci/stworzyli_darmowy_klon_photoshopa-54249.html （2026-09-21，"8 MB 的 Photoshop 对手"）
  - 中文头条文章：https://m.toutiao.com/article/7687818878855971370/ （"仅 7MB，这个平替 Photoshop 的开源神器，在 GitHub 上火了"）
  - GitCode 博客：https://blog.gitcode.com/5b88e4c85ef96d2e348c934ed87d4726.html
  - Habr：https://habr.com/ru/news/1084464/

### A2. 不能 100% 确认时，其他候选（2026 年同样很火）
| 项目 | 链接 | 语言 | License | ★（实测） | 备注 |
|---|---|---|---|---|---|
| PhotoCraft | https://github.com/storytold/photocraft | Rust | MIT / Apache-2.0 | 80,653 | "Clean-room 重写 Photoshop"，早期 alpha，支持 macOS/Windows/Linux/Web |
| PhotoSplice | https://github.com/eolix/PhotoSplice | Rust | Apache-2.0 | 86 | 主打 PSD/PSB 1:1 兼容，含网页版 |
| Graphite | https://github.com/GraphiteEditor/Graphite | Rust | Apache-2.0 | 27,990 | 程序化 2D 矢量+位图编辑器，常被称"开源 PS 替代" |
| Photopea | https://www.photopea.com | JS（网页） | **非开源（闭源免费）** | — | 网页版 PS 平替，但**不是**开源项目，别当开源用 |

> 判断：你记忆里的"很小 + GitHub 开源 + 重构 PS"三要素与 **Compositor（8.9MB、MIT、Swift）** 吻合度最高；如果你记得的是"Rust 重写"，那可能是 PhotoCraft/Graphite。建议你把当时看到的链接发我，最终可 100% 锁定。

### A3. 这件事对我们的真正意义
1. 它是**桌面/网页技术栈**（Swift/AppKit 或 Rust/Web），**不能直接装到 iPhone 上**，不存在"下载开源项目→改成 iOS App"的捷径。
2. 但它证明了：**"文档模型 + 图层 + 命令/撤销栈 + GPU 渲染"** 这套架构可以做得又小又快——这正是我们 iOS 版可以借鉴的骨架。
3. 它的 MIT/Apache 许可允许我们**阅读、学习、复用代码思路**（甚至移植少量通用算法），但不能把 macOS UI 骨架直接搬去 iOS。
4. 结论：**灵感项目 = 架构教材，不是代码底座**；iPhone 版要基于 iOS 原生框架重新组合实现。

## B. 开发与分发相关事实（Apple 官方，2026-11 抓取）

| 事实 | 内容 | 来源 |
|---|---|---|
| 最新稳定 Xcode | **Xcode 27**（另有 27.1 / 27.2；27.3 beta 2 在测） | https://developer.apple.com/xcode/system-requirements |
| Xcode 27 系统要求 | **macOS Tahoe 26.6 或更高**；Swift 6.4；SDK 为 iOS 27.x；部署目标支持 **iOS 15–27** | 同上 |
| 当前 iOS 主版本 | **iOS 27**（2026 年秋发布，Xcode 27 配套） | https://developer.apple.com/xcode/ |
| iPhone 14 | A15 / 6GB；iOS 26 官方支持机型包含 iPhone 14 系列；能否升 iOS 27 以 Apple 兼容性列表 / 朋友手机实际版本为准（**待核实**） | Apple 发布信息 |
| 开发者账号 | **Apple Developer Program $99/年**；免费账号可在**自己的设备**上通过 Xcode 调试（签名 7 天有效） | https://developer.apple.com/programs/ |
| TestFlight | 付费账号最多邀请 **10,000** 名外部测试员；**测试构建 90 天过期**（过期后需重新发版，礼物场景不适合长期依赖） | 同上 / TestFlight 文档 |
| Unlisted 分发 | 不公开上架：不出现在分类/搜索/榜单，**仅拿到链接的人可装**；需 App 先通过 App Review 再提交申请 | https://developer.apple.com/support/unlisted-app-distribution/ |
| 企业证书 | Apple Developer Enterprise Program **$299/年**，仅限企业内部员工，**给朋友装属违规，会导致封号**，不要用 | https://developer.apple.com/programs/enterprise/ |
| 隐私清单 | 提交 App Store 的 App 需包含 `PrivacyInfo.xcprivacy`（2024-05 起要求），第三方 SDK 需提供隐私清单/签名 | https://developer.apple.com/news/upcoming-requirements/ |
| 审核规则 | App Review Guidelines（4.2 最低功能、5.1 隐私、2.5 私有 API、5.2.5 音乐版权等） | https://developer.apple.com/app-store/review/guidelines/ |

## C. 开源项目 License / 维护状态（GitHub API 实测，2026-11-20）

| 项目 | 语言 | License | ★ | 最近推送 | 状态 | 建议用途 |
|---|---|---|---|---|---|---|
| Compositor | Swift | MIT | 18,763 | 2026-11-19 | 活跃（仅 macOS） | **架构参考**（图层/滤镜/PSD） |
| PhotoCraft | Rust | MIT / Apache-2.0 | 80,653 | 2026-11-20 | 活跃 alpha（桌面/Web） | **架构参考**（命令引擎/PSD） |
| Graphite | Rust | Apache-2.0 | 27,990 | 2026-11-20 | 活跃（桌面/Web） | 参考（节点式渲染） |
| GPUImage3 | Swift | BSD-3-Clause | 2,874 | 2024-07-25 | 维护放缓 | 滤镜/视频 GPU 处理参考 |
| MetalPetal | Objective-C | MIT | 2,200 | 2024-04-10 | 放缓但稳定 | **推荐**：Metal 图像/视频处理引擎 |
| Brightroom | Swift | MIT | 3,689 | 2026-11-20 | 活跃 | **推荐**：Core Image+Metal 照片编辑器底座 |
| ZLPhotoBrowser | Swift | Apache-2.0 | 4,990 | 2026-10-19 | 活跃 | **推荐**：相册选择 + 图片编辑 + 视频裁剪 |
| TOCropViewController | Objective-C | MIT | 4,947 | 2026-11-08 | 活跃 | 裁剪（可选） |
| YPImagePicker | Swift | MIT | 4,483 | 2026-07-28 | 活跃 | Instagram 风选图+滤镜（可选） |
| BSImagePicker | Swift | MIT | 1,368 | 2024-05-23 | 放缓 | 多选相册（可选） |
| Cabbage | Swift | MIT | 1,576 | 2023-11-08 | 停滞但可用 | AVFoundation 视频合成**参考实现** |
| PryntTrimmerView | Swift | MIT | 905 | 2024-12-11 | 放缓 | 视频裁剪 UI（可抄交互） |
| miniPaint | JS | GitHub 识别为 NOASSERTION（**需人工核对 LICENSE**） | 3,502 | 2026-11-09 | 活跃 | Web 图片编辑器（WKWebView 备选，许可先核实） |
| tui.image-editor | JS | MIT | 7,666 | 2023-11-20 | **已归档** | 不建议新项目使用 |
| ffmpeg-kit | C | **LGPL-3.0** | 5,856 | 2026-07-02 | **已归档（退役）** | 不建议；用 AVFoundation 替代 |

## D. 关键判断（供报告引用）
1. **没有**现成开源项目能"直接改成 iOS 全功能 P图+剪辑 App"；必须原生开发 + 组合开源组件。
2. 照片编辑最稳的 iOS 底座：**Core Image + Metal（MetalPetal / Brightroom 思路）**，配合 Vision 抠图 + 自研图层/文字/贴纸/拼图。
3. 视频剪辑**不需要 FFmpeg**：AVFoundation + Core Image 覆盖裁剪/拼接/转场/字幕/音乐/画中画/变速/导出；ffmpeg-kit 已退役且 LGPL 合规麻烦。
4. 最大现实约束不是技术，是**"Windows 无 Mac"**：$99 账号 + 云 Mac/CI 构建 + TestFlight（短期）/ Unlisted 上架（长期）。
5. "简单易用 + 绝大多数效果"的正确解法：**模板化 + 一键**包装专业能力，而不是做完整 PS/PR 界面。
