# 许可与素材登记

当前 App 使用系统界面字体和 Swift、Apple SDK，安装包没有第三方捆绑素材。项目源码的公开许可由仓库维护者决定。内置素材的登记字段见 [视觉规范](../../docs/product/visual-style.md)。

「关于 IOSPS」可离线查看开源组件与工具的固定版本、上游来源、版权和许可原文。随包资源在 [Notices](Notices/licenses.json)，用于致谢。

| 项目 | 用途 | 来源与许可 | 是否随 App 分发 |
|---|---|---|---|
| XcodeGen | 将 project.yml 生成 Xcode 工程 | [XcodeGen 2.48.0](https://github.com/yonaskolb/XcodeGen/releases/tag/2.48.0) · [MIT](https://github.com/yonaskolb/XcodeGen/blob/2.48.0/LICENSE) | 否 |
| actions/checkout v6.0.2 | CI 自动检出 | [MIT](https://github.com/actions/checkout/blob/de0fac2e4500dabe0009e67214ff5f5447ce83dd/LICENSE) | 否 |
| actions/upload-artifact v6.0.0 | CI 上传 ZIP 与截图 | [MIT](https://github.com/actions/upload-artifact/blob/b7c566a772e6b6bfb58ed0dc250532a479d7789f/LICENSE) | 否 |
| NovaCut `722178133bc8d82592ddc093382511e3e8e591b2` | F-16 的 macOS 原生合成和导出核心 | [固定源码](https://github.com/JesusMonjeGonzalez/NovaCut/tree/722178133bc8d82592ddc093382511e3e8e591b2) · [MIT 原文](Notices/novacut.txt)。保留已验证的原生编译子集，补 Swift 6 同步标注与音频回调失败处理 | 是 |
| Compositor `4a17b264a93b6da5fa5ff81357e6194ef9ad61a2` | M4 照片编辑画布、历史、工程存储与像素渲染底座 | [固定源码](https://github.com/robbietilton/Compositor/tree/4a17b264a93b6da5fa5ff81357e6194ef9ad61a2) · [MIT 原文](Notices/compositor.txt)（Copyright (c) 2026 Wonder Assembly LLC）。保留离线画布与渲染内核，移除 Sparkle 更新器、联网权限、在线模型下载及未核实二进制色表，通过适配层封装工程格式与回调 | 是 |
| [生日贺卡蛋糕插画](../Sources/DesignSystem/Resources/birthday-card-art.png) | F-01 生日首页插图 | 2026-11-25 用 OpenAI 图像生成工具为 IOSPS 生成的项目素材，无外部参考图。原文件随项目使用，SHA-256 `9abbd644ad8dd97bd4acbc05d44af42e73bafd4e59b918ea7aac4e862eefb345` | 是 |
| IOSPS 8 套内置回忆短片模板 JSON（`app/Sources/TemplateKit/Resources/MemoryTemplates/01-*.json` – `08-*.json`） | F-15 内置短片模板 | 2026-11-27 IOSPS 项目原创 JSON 模板，CC0-1.0 / MIT，见 [许可说明](Notices/iosps-original-bgm.txt) | 是 |
| `warm-piano.m4a`（`app/Resources/Music/warm-piano.m4a`） | F-15 短片内置配乐（温暖钢琴） | 2026-11-27 由项目确定性音频脚本 `tools/generate_bgm.py` 原创和声合成，无外部采样；CC0-1.0 / MIT，SHA-256 `04adfbb2741285e95570508fb4dca75418911ad19fcb924a6ca499c5ede1491e` | 是 |
| `music-box.m4a`（`app/Resources/Music/music-box.m4a`） | F-15 短片内置配乐（晶莹八音盒） | 2026-11-27 由项目确定性音频脚本 `tools/generate_bgm.py` 原创和声合成，无外部采样；CC0-1.0 / MIT，SHA-256 `60bf485ab56941198cfb6770e702c497f0c88f31fa17a153210422dfdb349202` | 是 |
| `sunny-acoustic.m4a`（`app/Resources/Music/sunny-acoustic.m4a`） | F-15 短片内置配乐（晴日拨弦） | 2026-11-27 由项目确定性音频脚本 `tools/generate_bgm.py` 原创和声合成，无外部采样；CC0-1.0 / MIT，SHA-256 `2b8f27b038b9cb61764926db6d4c36c93793069d54d818e63d6c679028e1d3db` | 是 |
| `starry-nocturne.m4a`（`app/Resources/Music/starry-nocturne.m4a`） | F-15 短片内置配乐（星夜独白） | 2026-11-27 由项目确定性音频脚本 `tools/generate_bgm.py` 原创和声合成，无外部采样；CC0-1.0 / MIT，SHA-256 `9a49a6fa250b5194ebe32822fc6c8747431642156f0185e62144ed2aef023a73` | 是 |
