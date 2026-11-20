# R04 · Compositor 修图底座只读预评估

2026-11-20。为了最大限度保留画布、裁剪、调色与导出，若朋友的 Apple 芯片 Mac 已运行 macOS 26+ 或用户接受升级，推荐先验证 **以 Compositor 为应用主体**的最小原型。若首版必须覆盖 macOS 14/15，推荐 **保留 IOSPS 主体，定点复用裁剪几何和独立像素处理代码**。完整嵌入上游编辑器同时承担两边的集成工作，收益要等依赖拆解与原型实测。当前交付基线和迁移权限见 [D-12](../../STATUS.md)。

## 证据版本与平台

- 固定源码为 `4a17b264a93b6da5fa5ff81357e6194ef9ad61a2`。`gh api` 读到最新发行 `v1.6.14` 指向 `d37eb51a6cb6e78a18adbfe4cccbde974e094e35`，固定源码比它多一笔 `appcast.xml` 更新。下载源码 ZIP 的 SHA-256 为 `1defff87570d9bce2bbe64ea2a904cf648b47b654a6b36b1bb6540ce354d17cb`。源码只在独立临时目录阅读，以下功能均为静态证据。 [发行标签](https://github.com/robbietilton/Compositor/releases/tag/v1.6.14) · [提交差异](https://github.com/robbietilton/Compositor/compare/d37eb51a6cb6e78a18adbfe4cccbde974e094e35...4a17b264a93b6da5fa5ff81357e6194ef9ad61a2)
- 上游 README 规定 macOS **26.0+／Apple 芯片**、构建用 Xcode **26+**。工程确认 `ARCHS = arm64`、`MACOSX_DEPLOYMENT_TARGET = 26.0`，应用目标使用 Swift **5 语言模式**、默认 `MainActor` 隔离。仓库只提供 App、单测和 UI 测试目标。当前 IOSPS runner 实际有 Xcode 26.6／Swift 6.3.3，仍需验证上游构建和 Swift 6 严格并发，编译工具版本与语言模式分别检查。M1 MacBook Air 在 Apple 的 Tahoe 兼容清单内，朋友的实际系统与升级意愿待确认。 [上游要求](https://github.com/robbietilton/Compositor/blob/4a17b264a93b6da5fa5ff81357e6194ef9ad61a2/README.md#requirements) · [Xcode 工程](https://github.com/robbietilton/Compositor/blob/4a17b264a93b6da5fa5ff81357e6194ef9ad61a2/Compositor.xcodeproj/project.pbxproj#L285) · [Apple 兼容清单](https://support.apple.com/en-us/122867)
- 源码中 `CompositorApp` 使用 `defaultWindowPlacement`，`AppSlider` 使用 `glassEffect`。完整编辑器在 macOS 14 的可运行性待逐项审查。改工程版本号无法验证实际 API 可用性。 [窗口入口](https://github.com/robbietilton/Compositor/blob/4a17b264a93b6da5fa5ff81357e6194ef9ad61a2/Compositor/CompositorApp.swift#L14) · [滑杆](https://github.com/robbietilton/Compositor/blob/4a17b264a93b6da5fa5ff81357e6194ef9ad61a2/Compositor/UI/AppSlider.swift#L105) · [Apple SwiftUI API](https://developer.apple.com/documentation/swiftui/view/glasseffect(_:in:))

## 功能与复用边界

下表的成本指从单体 App 拆出后接入 IOSPS 的相对工作量。复制 Compositor 代码的各项均保留完整 MIT 许可正文和 Wonder Assembly LLC 版权声明。

| 能力 | 已找到的实现 | 在 IOSPS 中的复用成本 |
|---|---|---|
| 画布与导入 | `ProjectWorkspaceView` 从当前标签取 `EditorSession` 和控制器，`ContentView` 连接文件导入、拖放、工具栏和图层。`EditorCanvas` 用 `NSViewRepresentable` 包装 `CanvasView`，处理输入、视口和叠层，连接 `LayerRenderer`、`GPUCanvasRenderer` 与 AppKit。 [工作区](https://github.com/robbietilton/Compositor/blob/4a17b264a93b6da5fa5ff81357e6194ef9ad61a2/Compositor/UI/ProjectTabs.swift#L6) · [画布](https://github.com/robbietilton/Compositor/blob/4a17b264a93b6da5fa5ff81357e6194ef9ad61a2/Compositor/Rendering/EditorCanvas.swift#L4) | **高**。整块接入需同带文档状态、工具、手势和渲染依赖。只保留视口算法时仍需独立画布接线与交互验证。 |
| 裁剪、旋转、翻转 | `CropGeometry`、`CropDrag`、`CropSnap` 做比例和吸附，`EditorSession.commitCrop()` 使用 `CanvasResizer` 处理文档快照。`rotateCanvas` 与 `flipCanvas` 分别更新画布几何和图层变换。 [裁剪几何](https://github.com/robbietilton/Compositor/blob/4a17b264a93b6da5fa5ff81357e6194ef9ad61a2/Compositor/Document/Crop.swift#L4) · [旋转](https://github.com/robbietilton/Compositor/blob/4a17b264a93b6da5fa5ff81357e6194ef9ad61a2/Compositor/Document/CanvasRotation.swift#L34) · [翻转](https://github.com/robbietilton/Compositor/blob/4a17b264a93b6da5fa5ff81357e6194ef9ad61a2/Compositor/Document/LayerFlip.swift#L55) | **低至中**。几何可试拆，保留方向、取整、越界和前后像素的测试。整套吸附、选区和文档事务一起移植则依赖更多。 |
| 调色、滤镜、主体选择 | `HueSaturation`、`ImageAdjustments`、`Filters` 提供实时预览和提交。曝光、色相／饱和度、锐化、暗角等已有入口。`CameraRawSettings` 含温度、对比度、高光与阴影等，但连接二进制色表和渲染资源。`SubjectRemoval` 使用 Vision 前景实例蒙版。 [滤镜](https://github.com/robbietilton/Compositor/blob/4a17b264a93b6da5fa5ff81357e6194ef9ad61a2/Compositor/Document/Filters.swift#L352) · [参数](https://github.com/robbietilton/Compositor/blob/4a17b264a93b6da5fa5ff81357e6194ef9ad61a2/Compositor/Document/CameraRaw.swift#L47) · [Vision](https://github.com/robbietilton/Compositor/blob/4a17b264a93b6da5fa5ff81357e6194ef9ad61a2/Compositor/Document/SubjectRemoval.swift#L28) | **中至高**。可试抽独立算子并留在 L2。F-08 的八项滑杆要逐项映射和验收。主体选择属 P1，可单独核对可用性。 |
| 预览和导出 | `ImageExporter.render` 从 `ProjectSnapshot` 合成，`pngData`／`jpeg` 编码。`ProjectController` 连接保存面板。标准照片路径使用 sRGB，需要实测与现有 Display P3 缩略图约定的边界。 [导出引擎](https://github.com/robbietilton/Compositor/blob/4a17b264a93b6da5fa5ff81357e6194ef9ad61a2/Compositor/IO/ImageExporter.swift#L25) · [保存面板](https://github.com/robbietilton/Compositor/blob/4a17b264a93b6da5fa5ff81357e6194ef9ad61a2/Compositor/IO/ProjectController.swift#L146) | **中**。独立编码函数比整个合成器更易复用。选定色彩策略后核验裁剪后的原像素尺寸、EXIF 方向、ICC、透明度和 JPEG 背景填色。 |
| 工程与撤销 | `ProjectStore` 用 `NSFileCoordinator` 原子替换 `.comp` 文件包，保存像素资源和版本化清单。固定源码的 `ProjectManifest.current` 为 22，格式文档摘要仍写 21，以源码为准。`DocumentHistory` 是会话历史，默认最多 100 条且受 256 MiB 保留像素预算约束。 [存储](https://github.com/robbietilton/Compositor/blob/4a17b264a93b6da5fa5ff81357e6194ef9ad61a2/Compositor/IO/ProjectStore.swift#L20) · [历史](https://github.com/robbietilton/Compositor/blob/4a17b264a93b6da5fa5ff81357e6194ef9ad61a2/Compositor/Document/DocumentHistory.swift#L27) | **高**。采用完整编辑器时让 `.comp` 拥有照片编辑状态；IOSPS 用 `MediaID` 或应用拥有的文档引用关联。定点复用时由 `BirthdayCore` 和 `FileDraftStore` 管理状态。自动保存与至少 20 步撤销仍须按 F-14 验收。 |

## 两条路线

| 方面 | A · 以 Compositor 为应用主体 | B · 保留 IOSPS 主体并复用上游 |
|---|---|---|
| 继承范围 | 直接沿用同一编辑会话下的画布、裁剪、滤镜、撤销、`.comp` 和导出。先缩小可见工具范围。 | 完整嵌入 `EditorCanvas` 需要移入会话、文档、渲染及相关交互，接近移植整个编辑目标。定点复用可先抽 `CropGeometry`、变换运算、选定调色和编码函数。 |
| 简单中文界面 | **中至高**。保留编辑会话与文件服务，替换应用入口导航和专业工具栏。收敛编辑区为「裁剪」「调色」「保存」，清理上游菜单、指令搜索、快捷键、退出确认和错误文案的可达入口。补 `zh-Hans`、VoiceOver、字号、浅／深色与键盘验证。 | 定点复用的中文界面成本 **中**，现有 SwiftUI 壳直接承载；需要补画布接线、预览、保存和历史。完整嵌入的 UI 与会话解耦成本 **高**。 |
| 生日与短片 | 在派生 App 的导航接现有 `DesignSystem` 和 `GiftKit`／`MediaIO`，保留已有 SwiftPM 包及纯逻辑测试；编辑器当其中一个页面。移除上游编辑专用的全局命令对主页和短片的拦截。 | 导航和工程继续使用 AppMac。完整嵌入时由 macOS 编辑模块持有会话；定点复用时只给 L2 传原件、参数和输出。两种方式都保留 L1 依赖方向。 |
| 兼容与维护 | 依赖 macOS 26+。目标和工程配置接入现有 CI，给派生版本独立 App 名、图标、bundle ID 和签名；上游升级时回归自定义导航与命令。 | 完整嵌入仍按 macOS 26+ 估算。定点复用才有机会维持 14.0，按文件记录来源和维护差异，需在 macOS 14 真机验证。 |
| 主要取舍 | 继承最多功能，最早验证源图到导出的闭环；Swift 6、中文壳与离线签名是首批风险。 | 优先维持经验证的 IOSPS 工程和 14.0 覆盖。抽取越窄，重新实现画布、编辑事务和预览的工作越多。 |

两条路线都由 `GiftKit` 读取私下导入的回忆包与日期，`MediaIO` 管理只读原件、副本和本地 ID。编辑器保存可编辑工程或配方，导出照片后可把扁平图登记为新 `MediaID`。`TemplateKit` 和 `TimelineKit` 只读素材引用与模板，后续由 `VideoEngine` 用 AVFoundation 编码 MP4。这样生日页、回忆和短片可以与编辑器独立验收。基础剪辑、八套短片模板、生日素材、LUT 预设与 IOSPS 的完整 P0 验收依然沿现有任务推进。 [模块边界](../architecture/modules.md) · [素材清单](../../content/README.md) · [功能矩阵](../product/features.md)

## 许可证与离线分发

- Compositor 根许可证为 MIT，版权行是 `Copyright (c) 2026 Wonder Assembly LLC`。正式复制源码或分发二进制时，保留版权和许可正文，在 `app/Resources/LICENSES.md` 登记提交和使用范围，将声明随 App 分发。派生版本采用独立图标和标识，保留上游致谢。 [固定提交 LICENSE](https://github.com/robbietilton/Compositor/blob/4a17b264a93b6da5fa5ff81357e6194ef9ad61a2/LICENSE)
- 上游目标锁定 Sparkle 2.10.0，启动读取上游更新配置，并有网络和 Sparkle XPC 权限。离线礼物原型移除更新框架、appcast、公钥与对应权限，避免指向上游更新服务。若以后引入更新功能，按固定版本审核合并许可证和签名配置。 [依赖锁](https://github.com/robbietilton/Compositor/blob/4a17b264a93b6da5fa5ff81357e6194ef9ad61a2/Compositor.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved) · [应用配置](https://github.com/robbietilton/Compositor/blob/4a17b264a93b6da5fa5ff81357e6194ef9ad61a2/Config/Info.plist#L60) · [权限](https://github.com/robbietilton/Compositor/blob/4a17b264a93b6da5fa5ff81357e6194ef9ad61a2/Config/Compositor.entitlements) · [Sparkle 许可](https://github.com/sparkle-project/Sparkle/blob/eef1a539a373c1f1a320624b1130fc5de7b2e100/LICENSE)
- Volumetric Light 首次运行会下载 DepthMini。首版离线原型排除该功能和模型数据。`CameraRawTables.bin` 与 `CameraRawShadows.bin` 的源码注释提到依据 Photoshop Camera Raw 的测量拟合，二进制数据的来源与再分发依据待核对。原型用现成曝光、色相／饱和度及系统框架实现的已核对路径。任何样图、字体、图标、着色器和资源逐项登记或移除。 [模型加载](https://github.com/robbietilton/Compositor/blob/4a17b264a93b6da5fa5ff81357e6194ef9ad61a2/Compositor/IO/DepthModel.swift#L8) · [色表说明](https://github.com/robbietilton/Compositor/blob/4a17b264a93b6da5fa5ff81357e6194ef9ad61a2/Compositor/Document/CameraRawTables.swift#L4) · [阴影拟合](https://github.com/robbietilton/Compositor/blob/4a17b264a93b6da5fa5ff81357e6194ef9ad61a2/Compositor/Document/CameraRawShadows.swift#L4)
- 上游 DMG 流程依赖 Developer ID 和公证凭据。原型沿用 IOSPS 已验证的 arm64、ad-hoc ZIP 和 SHA-256，CI 核对签名及权限，App 保留系统文件选择能力。在干净目标 Mac 用合成素材断网验收首开、编辑、重开和短片导出。构建期下载工具与运行期离线验收分别取证。 [上游发行脚本](https://github.com/robbietilton/Compositor/blob/4a17b264a93b6da5fa5ff81357e6194ef9ad61a2/scripts/release.sh) · [IOSPS 分发方案](../decisions/ADR-0005-distribution.md)

## 最小原型验收门槛

用户先确认路线和目标系统，原型单独立卡并在隔离分支验证。两种路线共用下列基准，A 与 B 分别记录沿用的代码、移除的资源及待解决的差异。

1. **构建与回归 L1/L2**。固定上游来源与 CI SHA；本项目 `swift test --package-path app` 已有 47 用例继续通过。以 Swift 6／严格并发构建 arm64 Release，保存 `xcodebuild` 日志、部署目标及签名证据。A 用 macOS 26+；若选 B 保留 14.0，产物编译目标为 14.0，并在 14.x／Apple 芯片实机首开。若候选代码依赖无法替换的晚期 API，记录位置及影响并回到 D-12。
2. **编辑闭环 L2/L3**。用带方向标记的合成 JPEG 和有透明边缘的 PNG，验收选图、平移缩放、固定比例裁剪、90° 旋转、曝光和饱和度预览、撤销／重做、保存后重开。导出 JPEG/PNG，校验裁剪后原像素尺寸、方向、ICC 和透明度处理，确认源文件 SHA-256 无变化。下载浅色、深色和放大字号截图，确认中文主入口和错误反馈可见，键盘能完成主流程。
3. **礼物和短片连接 L2/L3**。启动即显示生日首屏，读取一份虚构回忆包。将导出照片作为新 `MediaID` 供短片入口使用，以单个无声模板渲染 3 秒、30 fps 的 MP4，核对 90 帧、时长与可播放性。本切片验证导航和素材边界，正式模板、音乐与编辑器功能继续按各自任务验收。
4. **离线交付 L2/L4**。下载 ZIP、校验 SHA-256、检查 `codesign --verify --deep --strict` 和许可清单。目标 Mac 按安装说明断网首开、完成上面两条主流程并退出重开；无更新或模型下载依赖。记录 12 MP 照片实测中的等待时间和峰值内存，供 M1／8 GB 参考机评估。参考机与最终目标机的测试数据分开记录。

静态审阅覆盖了候选源码，原型未构建。现有 [run 44775125352](https://github.com/yuexuanchi-sys/iosps-studio/actions/runs/44775125352) 的 47 个测试、Release、PNG 和签名 ZIP 属 IOSPS 基线证据。
