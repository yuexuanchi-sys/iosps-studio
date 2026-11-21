---
id: T-0009
title: Compositor 原型中文编辑、生日和回忆
milestone: M0
status: in-progress
priority: P0
modules: AppMac, DesignSystem, GiftKit, MediaIO
features: F-01, F-02, F-07, F-08, F-13, F-14
depends: T-0008
verify: L0,L2,L3
owner: AI+用户
updated: 2026-11-21
---

# T-0009 · Compositor 原型中文编辑、生日和回忆

## 目标

在派生编辑器上呈现简体中文礼物首页、回忆与简单编辑入口，并回读实际画面。

## 背景与依据

- [R04](../docs/research/R04-compositor-reuse.md)、[T-0008](T-0008-compositor-integrated-prototype.md)、[易用性原则](../docs/product/ux-principles.md)。

## 验收标准

- [ ] AC1：简体中文入口完成 JPEG/PNG 选择、平移缩放、固定比例裁剪、90° 旋转、曝光、饱和度、撤销重做、工程重开和原像素尺寸 PNG/JPEG 导出。
- [x] AC2：首屏显示生日信息，通过 GiftKit 读取合成回忆包并浏览照片，回到首页时编辑工程正确保留。[run 44919189467](https://github.com/yuexuanchi-sys/iosps-studio/actions/runs/44919189467) 的 `8346db969ad63268d86e1aef8c0e22b23bb26930`，Debug `testChineseEntryAndAppearanceVariants` 通过，截图在 `artifacts/prototype/44919189467/`。
- [ ] AC3：下载浅、深色及放大字号截图，检查文案、焦点和布局，验证键盘能完成主流程。

## 实施要点

- 假设：在原型工作树复用 AppKit 画布和编辑会话，简体中文主界面提供「生日」「回忆」「修图」，修图首批操作按「选图」「裁剪」「调色」「保存」组织。保留打开工程与撤销快捷键，切换页面时持续持有当前编辑会话。
- 交付物：`app/Prototype/Editor/` 的中文原型入口，`app/compositor-prototype.yml` 的本地 SwiftPM 依赖与 UI 测试组。由 `GiftKit` 读取合成回忆包与日期，图片经本地文件访问，已编辑工程留在派生应用的文档边界。
- 验收：在 `xcode-27` 上重新执行原型构建和既有测试，再用 `xcodebuild -project IOSPSCompositorPrototype.xcodeproj -scheme CompositorPrototype -destination 'platform=macOS' test` 执行中文导航与编辑流程的 UI 检查。实际运行生成浅色、深色和放大字号 PNG，回读并对照易用性原则。原型代码继续留在隔离分支。
- 实施顺序：先在 `app/Prototype/UITests/` 定义可从应用入口重跑的验收脚本和截图，再用 `app/Prototype/Editor/Gift/` 与现有应用入口组装三页。系统面板继续用于选取与保存文件，修图调用已有画布、项目控制器、裁剪和调色事务。固定比例默认取画布内居中区域，可用画布手柄改选。工程跨页面保留，由已有 `.comp` 保存与打开，不创建第二种工程格式。
- 影响文件：`app/compositor-prototype.yml` 接本地 GiftKit 和 UI 测试目标，`.github/workflows/compositor-prototype.yml` 保留既有构建、测试和签名并上传测试截图，`app/Resources/LICENSES.md` 登记仓库生成的合成示例。预期 47 个基线和 3 个派生编辑回归继续通过，UI 测试全部通过并输出三组 PNG。

## 进度日志

- 2026-11-20：从 T-0008 细化，承接原 AC2 的界面与原 AC3 的生日和回忆验收。
- 2026-11-21：先运行验收测试。[run 44918131135](https://github.com/yuexuanchi-sys/iosps-studio/actions/runs/44918131135)（`70e24805d124407b15e1c217faf7e75d8ac86fe5`）完成 L1 和 Release 构建，旧入口在 `testChineseEntryAndAppearanceVariants` 第 11 行因缺少「生日快乐」按预期失败。
- 2026-11-21：[run 44918616083](https://github.com/yuexuanchi-sys/iosps-studio/actions/runs/44918616083)（`499ae9ba0b00d6e393d819463f7474a91e9b5e85`）通过构建、编辑回归和导航。下载浅／深色六张并查看 `artifacts/prototype/44918616083/review-sheet.png`。首轮放大组和浅色 PNG 内容相同，已改用 App 内字号选项及标题尺寸断言。 [SwiftUI 字号在 macOS 的行为](https://developer.apple.com/documentation/swiftui/environmentvalues/dynamictypesize)
- 2026-11-21：[run 44918850143](https://github.com/yuexuanchi-sys/iosps-studio/actions/runs/44918850143)（`443dc11058fa88b32ab2bdc809bb75cc053c7145`）导航通过，系统选图面板选中 `source.jpg` 后仍停在面板，未到画布。失败日志 `artifacts/prototype/44918850143/failed.log`。测试改为等待每个原生面板的确认按钮可用后操作，再检查画布。
- 2026-11-21：[run 44919189467](https://github.com/yuexuanchi-sys/iosps-studio/actions/runs/44919189467) 的导航和字号高度断言通过。下载并查看九张 PNG，合成图在 `artifacts/prototype/44919189467/review-sheet.png`。浅深色文字、控件与相册图片可辨识，放大版回忆页可滚动。回忆日期取消年份千位分隔。文件流程暴露 macOS 静态文本通过 AX value 表示画布尺寸，已修正测试。
- 2026-11-21：[run 44919349925](https://github.com/yuexuanchi-sys/iosps-studio/actions/runs/44919349925)（`404e6416b1e895617307c9976734d9d2baf6cb48`）从原生面板选取 JPEG、PNG 后通过画布尺寸，按 ⌘= 后失败快照确认缩放数值为 125%。缩放断言同样改读 AX value。macOS 焦点循环现在可从画布用 Tab 移出，画布可用方向键平移。工作流验收命令与文件流程证据继续跟随下一次 SHA。
