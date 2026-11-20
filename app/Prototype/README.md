# Compositor 编辑器原型

本目录仅在 `t-0008-compositor-prototype` 分支验证完整继承路线。编辑器源码基于 Compositor `4a17b264a93b6da5fa5ff81357e6194ef9ad61a2`，版权及 MIT 条款随原型 App 分发。构建目标为 macOS 26.0／arm64，以 Swift 6 严格并发编译。

保留上游画布、裁剪、调色、历史、项目存储和导出。App 使用独立包标识及沙盒文件选择权限。上游脚本、图标、Sparkle 更新链、模型下载、色表二进制和历史发行配置均为原型打包排除项。调色回归使用曝光与色相／饱和度路径。文本和界面集成继续见项目看板。

- [来源与版权](compositor-license.txt)
- [构建和回归任务](../../tasks/T-0008-compositor-integrated-prototype.md)
- [中文编辑、生日和回忆](../../tasks/T-0009-compositor-prototype-gift-interface.md)
- [短片与离线真机](../../tasks/T-0010-compositor-prototype-offline-movie.md)
