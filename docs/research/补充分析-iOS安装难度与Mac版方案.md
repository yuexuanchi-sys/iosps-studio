# 补充分析：iOS 安装到底难不难？要不要改做 MacBook 版？

> 补充调研时间：2026-11-20 ｜ 性质：只做分析与资料核实，不写代码
> 关联主报告：[调研报告.md](调研报告.md) · 事实底稿：[00-lead-verification.md](00-lead-verification.md)

---

## 0. 一句话回答

**没有你想的那么难，但"难"的位置不在"装"，而在"开发环境 + 账号 + 审核/期限"这三件事上。**
如果她用的是 MacBook，**改做 macOS 版确实更划算**：分发可以做到"发个压缩包/安装包，她拖进应用程序就能用"，**不需要开发者账号、不需要审核、没有 90 天过期**；但开发环境仍然需要 macOS（云 Mac / 借 Mac），这一点和 iOS 版一样绕不开。下面是完整对比。

---

## 1. 先纠正一个前提：iOS"装上去"其实分几种情况

| 方式 | 对你的门槛 | 对朋友的操作 | 有效期 | 结论 |
|---|---|---|---|---|
| **TestFlight**（官方测试分发） | $99/年开发者账号；上传构建；邀请她的 Apple ID/发公开链接 | 装 TestFlight App → 点邀请 → 安装，和装普通 App 一样 | **构建 90 天过期**（到期要重新发版） | 生日前体验很方便，**不适合长期当礼物** |
| **Unlisted App Distribution**（不公开上架、链接分发） | $99/年；先通过 App Review，再申请 Unlisted | 点你给的链接 → App Store 安装，和正常 App 一样 | **长期**（账号有效期内） | ✅ 长期礼物最推荐，但要走审核 |
| **Ad Hoc**（指定设备安装） | $99/年；收集她 iPhone 的 UDID；打包 | 点链接/用电脑装 | 设备授权 1 年，profile 到期需重签 | 可行但麻烦，不推荐 |
| **免费 Apple ID 侧载**（AltStore/SideStore 等） | 免费；Windows 可操作 | 需要她配合信任证书/每 7 天重签一次 | **7 天** | ❌ 礼物场景不可接受 |
| **企业证书分发** | $299/年 | 直接安装 | — | ❌ 只限企业内部员工，给朋友装违规、会封号 |

**结论**：iOS 安装本身不"难"——难的是：① 你没有 Mac 开发环境；② 需要 $99/年账号；③ 长期有效要么走审核（Unlisted），要么接受 90 天过期（TestFlight）。**这三件事叠加，才让它"感觉很难"。**

---

## 2. 改做 MacBook 版：分发反而简单很多

### 2.1 macOS 应用的三种分发方式（官方 + 自分发）

| 方式 | 需要什么 | 对朋友的操作 | 有效期 | 成本 |
|---|---|---|---|---|
| **直接发安装包（未签名/未公证）** | 一台 macOS 构建环境（云 Mac/借 Mac/CI） | 下载 → 拖进"应用程序" → 首次打开时按提示进"系统设置 → 隐私与安全性 → 仍要打开" → 以后正常用 | **永久**（文件在就能用） | **￥0**（开发者账号非必需） |
| **Developer ID 签名 + 公证**（推荐给"要省心"的场景） | 需 Apple Developer Program（**$99/年**）；生成 Developer ID 证书；用 `notarytool` 提交公证（可在云 Mac/CI 上完成） | 下载 → 打开即用，**没有"未知开发者"警告** | 永久 | $99/年 |
| **Mac App Store 上架** | $99/年 + App Review | App Store 搜索/链接安装 | 长期（账号有效） | $99/年 |

> 已核实：Apple 官方明确说明「要在 Mac App Store 分发，或为 Mac App Store 之外的分发生成 Developer ID 证书，需要加入 Apple Developer Program（$99/年）」（<https://developer.apple.com/macos/distribution/>）。但**未签名的自分发并不被技术禁止**，只是首次打开会被 Gatekeeper 拦截一次，需要用户手动允许（<https://support.apple.com/guide/mac-help/mh40616/mac>）。这对"送给朋友"的场景完全可以接受。

### 2.2 也就是说：Mac 版的"礼物闭环"可以做到
- 成本：**￥0 分发**（不想花 $99 的话），或 $99 换"没有警告、更顺滑"；
- 期限：**永久**，不存在 TestFlight 90 天过期；
- 审核：**不需要**（直接分发）；
- 朋友操作：**下载 → 拖进应用程序 → 首次允许一次**，之后和普通软件一样。

> 唯一"仪式感"上的代价：Mac 版不能像手机 App 那样随时拿出来看。可以用"生日当天全屏启动动画 + 自动播放回忆短片"等设计弥补。

---

## 3. Mac 版的开发环境：仍需 macOS，但没有 iOS 那么多坑

| 维度 | iOS 版 | macOS 版 |
|---|---|---|
| 开发工具 | Xcode（必须 macOS） | Xcode（同样必须 macOS） |
| 开发语言/界面 | Swift + SwiftUI/UIKit | Swift + SwiftUI/AppKit |
| 部署目标（Xcode 27 支持范围） | iOS 15–27 | **macOS 12–27**（可兼容老 Mac） |
| 构建环境（你只有 Windows） | 云 Mac / GitHub Actions / Codemagic / 借 Mac | **同样**：云 Mac / GitHub Actions / Codemagic / 借 Mac |
| 分发 | TestFlight（90 天）/ Unlisted（需审核）/ Ad Hoc | **直接发 .zip/.dmg（无审核、无期限）**，或公证/上架 |
| 开发者账号 | **基本必须**（$99/年） | **非必须**（不公证也能分发） |
| 复用桌面开源项目 | ❌ 不能（Compositor 等是 macOS 专用） | ✅ 可以（同平台、同为 Swift/Metal，见第 4 节） |

**重要更正/补充：**
- 截至 2026-11，最新 macOS 是 **macOS 27 Golden Gate**（2026-09-14 发布，来源：<https://isc.upenn.edu/news/macos-27-golden-gate-released-9142026>、<https://www.macobserver.com/news/apple-releases-macos-27-golden-gate-with-new-siri-ai-and-more/>）；上一代是 macOS 26 Tahoe。
- 最新 Xcode 27 要求 **macOS Tahoe 26.6 或更高**（<https://developer.apple.com/xcode/system-requirements>），但**构建出的 App 可以部署到 macOS 12 及以上**——所以她即使不是最新系统，也有机会运行。
- 也就是说：**你依然需要一台 macOS 来编译**（云 Mac 或借），但**做出来的 Mac App 给朋友安装，比 iOS 简单得多**。

---

## 4. Mac 版的一个"隐藏加速器"：可以直接借鉴/复用 Compositor

你之前看到的 **Compositor** 就是 macOS 原生的 Swift + MIT 项目（18,763★，8.9MB）：

- 它和 Mac 版 App **同平台、同语言、同框架**（SwiftUI/AppKit + Metal + Core Image）；
- **MIT 许可允许你学习、修改、甚至基于它做二次开发**（保留版权声明即可）；
- 它已经实现了：图层、蒙版、混合模式、调整图层、滤镜、选区、魔棒、内容感知填充、PSD/PSB 导入、文字、画笔、导出等——**这些正是 P图功能里最费时间的部分**；
- 你可以做的产品化改造：保留其图像引擎/画布/图层能力，**换掉 Photoshop 式 UI，做成"生日礼物"风格的界面**，加上回忆时间轴/一键短片/模板/彩蛋/祝福页；
- 限制：Compositor 要求 **macOS 26+ 与 Apple Silicon**（源码 Xcode 26+），如果她/你的 MacBook 是 Intel 或老系统，就不能直接用它的代码，需要降级适配或换成自研轻量引擎。

> 另一条同类路线：**PhotoCraft**（Rust，MIT/Apache-2.0，80,653★）是跨平台桌面编辑器，可参考其"命令引擎/PSD/图层"架构，但 Rust 技术栈和你后续做 iOS 版不一致，复用价值低于 Compositor。

**结论**：Mac 版有现成的"高质量参考/可复用底座"（Compositor），这是 iOS 版不具备的优势。

---

## 5. Mac 版技术方案（推荐）

### 5.1 架构：一套核心引擎 + 两套 UI（为以后 iOS 版留路）
```
shared-core (Swift Package)
├── ImageEngine    Core Image + Metal：滤镜链、图层、蒙版、LUT、抠图（Vision）
├── VideoEngine    AVFoundation + Core Image：拼接/裁剪/转场/字幕/BGM/导出
├── ProjectModel   Codable 工程文件、撤销/重做、模板(JSON)
└── MediaIO        Photos/Finder 导入导出
macOS App (SwiftUI/AppKit)      ← 先做这个
iOS App (SwiftUI, 复用 shared-core) ← 以后做
```
- **代码复用率**：核心引擎 60–80% 可在 Mac/iOS 之间共享；UI 各写一套（Mac 用窗口/多面板，iPhone 用单列/手势）。
- **部署目标**：建议 macOS 14（Sonoma）或 macOS 15（Sequoia）起步，覆盖绝大多数 MacBook；具体看她 MacBook 的系统版本。
- **依赖**：尽量少（Core Image/Metal/AVFoundation/Vision 都是系统框架，零集成成本）；照片视频导入可用系统 PhotosUI/Finder；无需第三方大库。

### 5.2 功能设计（Mac 版和手机版的差异）
| 能力 | Mac 版优势 | 生日场景用法 |
|---|---|---|
| P图 | 大屏多面板、键鼠快捷键、拖拽、批量处理；可做"图层式"专业编辑 | 做生日海报、合影精修、回忆相册排版 |
| 视频剪辑 | 时间轴更宽、预览更清楚、导出更快；AVFoundation 同源 | 把照片+视频+BGM 剪成 1–3 分钟回忆短片 |
| 照片/文件管理 | 直接访问"照片"App 或 Finder 文件夹 | 她可以把童年照片、合照拖进来，一键生成时间轴 |
| 仪式感 | 全屏启动动画、生日当天"生日模式"、自动播放回忆短片、桌面贺卡 | 生日当天打开 App 就是惊喜 |
| 后续扩展 | 可做屏保式回忆播放、导出成视频发朋友圈、打印贺卡 | 电子+实体礼物结合 |

> Mac 版不代表"功能缩水"——相反，**它比 iPhone 版更容易做到"功能全面"**：大屏能放下更多工具面板，文件系统让素材管理更顺，键鼠让精细修图更准。

---

## 6. 风险与需要提前确认的点（Mac 版）

| 风险 | 说明 | 应对 |
|---|---|---|
| **她的 MacBook 型号/芯片** | Apple Silicon（M1/M2/…）还是 Intel？决定能否用 Compositor、部署目标定多低 | 先问清「关于本机」里的芯片与 macOS 版本 |
| **系统版本** | macOS 27 Golden Gate / 26 Tahoe / 15 Sequoia / 14 Sonoma… | 部署目标建议 macOS 14+，必要时降到 13 |
| **Gatekeeper 首次拦截** | 未公证 App 第一次打开会提示"无法验证开发者" | 写一份图文安装说明（3 步：系统设置→隐私与安全性→仍要打开）；或花 $99 做公证免提示 |
| **云 Mac 成本** | 构建/调试需要 macOS 环境 | Codemagic/GitHub Actions 免费额度或云 Mac 按月租；一次性构建成本很低 |
| **代码移植工作量** | 基于 Compositor 改造需要理解它的代码（Swift 项目不小） | 先评估"换皮 + 加生日功能"的工作量；不行就走自研轻量引擎（Core Image 已够用） |
| **礼物时效** | 生日日期固定 | 先做 MVP（生日主页 + 照片编辑 + 回忆短片），再迭代剪辑/模板 |
| **仪式感弱于手机** | 电脑 App 不如手机随身 | 设计"生日当天全屏模式"+ 配套实体贺卡/周边 |

---

## 7. iOS 版 vs Mac 版：决策对比表

| 维度 | iOS 版（iPhone 14） | macOS 版（她的 MacBook） |
|---|---|---|
| 开发环境 | 需 macOS（云/借） | 需 macOS（云/借）**同样** |
| 开发语言 | Swift + SwiftUI/UIKit | Swift + SwiftUI/AppKit |
| 可复用桌面开源项目 | ❌ 不能 | ✅ Compositor（MIT）/PhotoCraft 可参考或复用 |
| 分发成本 | **$99/年基本必须** | **￥0 起**（不公证）；$99 可选 |
| 上架/审核 | TestFlight（Beta 审核）或 Unlisted（正式审核） | **不需要审核**（直接分发） |
| 有效期 | 90 天（TestFlight）/ 长期（Unlisted，需年费） | **永久** |
| 朋友安装难度 | 点链接安装（不难） | 下载→拖入应用程序→首次允许（需一次说明） |
| 功能上限 | 受 6GB 内存/散热限制；便携、相机、AR、通知强 | 大屏/键鼠/文件系统/批量；P图剪辑更专业 |
| 仪式感 | 随身、锁屏、通知、小组件 | 全屏生日模式、回忆短片、桌面贺卡 |
| 开发周期（MVP，兼职） | 3–6 周 + 1 周上架/分发 | 3–6 周 + 1–2 天打包分发（复用 Compositor 可能更快） |
| **推荐度** | 第二目标（后续可做） | **✅ 首选**（如果她确实常用 MacBook） |

---

## 8. 推荐路线（我的建议）

### 方案一（首选）：Mac 版先做，iOS 版后补
1. **第 0 步**：确认她 MacBook 的**芯片（Apple Silicon / Intel）与 macOS 版本**；
2. **第 1 步**：用 macOS 版做 MVP（生日主页 + 照片编辑 + 一键回忆短片 + 彩蛋），部署目标按她的系统定（建议 macOS 14+）；
3. **技术底座**：优先"Compositor 借鉴/复用（若她的机器满足 macOS 26 + Apple Silicon）"，否则用 Core Image/Metal 自研轻量引擎；
4. **分发**：打包 `.zip`/`.dmg`，附 3 步安装说明；预算允许就 $99 公证，体验最顺；
5. **第 2 步（可选）**：把 shared-core 复用到 iOS 版，用 TestFlight/Unlisted 再送她一份手机版。

### 方案二：只做 Mac 版（最省事）
- 不追求"手机 App"，把 Mac 版做成一个完整的"生日回忆工作室 + 贺卡生成器"；
- 优点：开发、分发、维护成本最低，没有账号/审核/期限焦虑；
- 缺点：少了手机端的随身仪式感，需要靠"生日当天全屏模式"补足。

### 方案三：坚持 iOS 版（如果手机端仪式感是核心）
- 走「$99 账号 + TestFlight（生日前体验）+ Unlisted（长期）」，或接受 TestFlight 90 天；
- 开发仍要云 Mac/CI；技术上没有 Mac 版顺，但完全可行。

---

## 9. 需要你补充确认的信息（这次只需回答 3 个问题）

1. **她的 MacBook 是什么芯片、什么系统版本？**（Apple 菜单 →「关于本机」，例如 "Apple M2，macOS 26.6" / "Intel Core i5，macOS 14.5"）
2. **你能接受"她第一次打开时要点一次『仍要打开』"吗？**（能接受 → ￥0 分发；不能 → 建议 $99 公证或走 Mac App Store）
3. **生日日期 + 你愿意投入的时间**（决定 MVP 范围：只做照片+回忆短片，还是也做视频剪辑）

> 另：如果她的 MacBook 是 Apple Silicon 且系统较新（macOS 26/27），我们能直接站在 Compositor 的肩上做，**Mac 版的开发速度会明显快于 iOS 版**。

---

## 10. 参考来源（2026-11-20 核实）

- Apple · 分发 macOS 软件（Mac App Store / Developer ID / Gatekeeper）：<https://developer.apple.com/macos/distribution/>
- Apple · 从未知开发者处打开 App：<https://support.apple.com/guide/mac-help/mh40616/mac>
- Apple · Xcode 版本与系统要求（Xcode 27 需 macOS Tahoe 26.6+，部署目标 macOS 12–27）：<https://developer.apple.com/xcode/system-requirements>
- Apple · Apple Developer Program（$99/年）：<https://developer.apple.com/programs/>
- Apple · 公证（Notarization）文档：<https://developer.apple.com/documentation/security/notarizing-macos-software-before-distribution>
- macOS 27 Golden Gate 发布（2026-09-14）：<https://isc.upenn.edu/news/macos-27-golden-gate-released-9142026>、<https://www.macobserver.com/news/apple-releases-macos-27-golden-gate-with-new-siri-ai-and-more/>
- Compositor（MIT、Swift、macOS 26+、Apple Silicon）：<https://github.com/robbietilton/Compositor>
- PhotoCraft（Rust、MIT/Apache-2.0，桌面参考）：<https://github.com/storytold/photocraft>
- Apple · Unlisted App Distribution（iOS 长期分发）：<https://developer.apple.com/support/unlisted-app-distribution/>
- Apple · TestFlight：<https://developer.apple.com/testflight/>

## 11. 追加 FAQ：做 iOS 版一定要 $99 吗？

**结论：不是"做"一定要，而是"长期装到朋友手机上/上架"基本一定要。$99 是年费（订阅制），不是一次性买断。**

### 11.1 免费 Apple 开发者账户能做什么（已核实）
按 Apple 官方说明，免费账户可以用：Beta 版 Xcode 和操作系统、**用 Xcode 直接在自己的设备上测试 App**、开发者论坛、反馈助理（来源：<https://developer.apple.com/cn/programs/>）。
但免费账户**没有** TestFlight、Ad Hoc、App Store 上架、Developer ID 公证；并且免费签名的 Profile 是临时性的（**7 天有效、最多 3 个 App**，需重新签名）。

### 11.2 不花 $99 的四条路
| 路线 | 能实现什么 | 关键限制 | 适合送礼吗 |
|---|---|---|---|
| 免费 Apple ID + Xcode | 把 App 装到**你自己的** iPhone 上调试 | 7 天过期、最多 3 个 App；需要 Mac/云 Mac + 真机 | ❌ 送朋友不现实 |
| AltStore / SideStore 等侧载 | 装到**她的** iPhone | 用她的免费 Apple ID 签名；**每 7 天重签**；需信任证书/开发者模式；需要一台电脑做服务端 | ❌ 不体面、易失效 |
| 网页 / PWA（Safari 添加到主屏幕） | "手机端软件"体验 | 不是 App Store App，功能/性能受限，无法像原生一样用摄像头/后台等 | ⚠️ 零成本 Plan B |
| 改做 MacBook 版（未公证直接发） | 她的电脑上装真 App | 只需首次"仍要打开"；无需账号 | ✅ 零成本，但仪式感偏电脑 |

### 11.3 花 $99 才能解锁的能力（已核实）
- **TestFlight**：100 名内部测试员、最多 **10,000** 名外部测试员；但构建**约 90 天过期**；
- **Ad Hoc**：指定设备安装（100 台/年）；
- **Unlisted App Distribution**：链接分发、长期（需通过 App Review）；
- **App Store 公开上架**；
- **Xcode Cloud**（付费账号含一定的云端构建额度）；
- **Developer ID + 公证**（Mac 自分发免"未知开发者"警告）。
来源：<https://developer.apple.com/cn/programs/>、<https://developer.apple.com/testflight/>、<https://developer.apple.com/support/unlisted-app-distribution/>

### 11.4 结论与建议
1. **只在自己手机玩/自己调试**：免费够用（7 天重签）；
2. **要送朋友、且希望长期有效**：$99/年基本是**官方最低门槛**（走 Unlisted 最稳；TestFlight 只适合生日前体验）；
3. **预算敏感**：优先 Mac 版（￥0 分发）或网页/PWA（￥0，但体验打折）；
4. **别碰**：企业证书（违规封号）、越狱/TrollStore（iPhone 14 新系统基本不支持）、共享账号（违反协议）；
5. 补充：$99 是**年费**，第二年需续费才能持续分发/更新；审核本身不收费；Apple 对非营利/教育/政府机构有年费减免政策，**个人礼物 App 不适用**（以 Apple 页面为准）。

---

*补充分析完 · 2026-11-20*
