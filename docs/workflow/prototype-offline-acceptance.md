# 拾光簿原型离线验收

对应 [T-0010](../../tasks/T-0010-compositor-prototype-offline-movie.md)。原型要求 Apple 芯片与 macOS 26.0 或更新版本。测试只用合成照片和内置示例相册。

## 下载后核对

从任务卡所列成功 run 下载 `iosps-compositor-prototype`，将 ZIP、校验值和签名记录放在同一目录。在目标 Mac 的「终端」进入该目录并执行：

```bash
shasum -a 256 -c IOSPSCompositorPrototype.app.zip.sha256
ditto -x -k IOSPSCompositorPrototype.app.zip .
codesign --verify --deep --strict --verbose=2 IOSPSCompositorPrototype.app
codesign -dv --verbose=4 IOSPSCompositorPrototype.app
codesign -d --entitlements :- IOSPSCompositorPrototype.app
lipo -archs IOSPSCompositorPrototype.app/Contents/MacOS/IOSPSCompositorPrototype
/usr/libexec/PlistBuddy -c 'Print :LSMinimumSystemVersion' IOSPSCompositorPrototype.app/Contents/Info.plist
```

记录 ZIP 校验成功、签名检查结果、`Signature=adhoc`、`arm64`、`26.0`。权限应只有应用沙盒及用户选取文件的读写权限。许可在 `Contents/Resources/compositor-license.txt`。遇到 Gatekeeper 提示时，按项目分发决定和目标机系统策略处理。 [分发决定](../decisions/ADR-0005-distribution.md)

## 目标 Mac 断网操作

1. 记录 `sw_vers`、`uname -m`、`sysctl -n hw.model` 与 `sysctl -n hw.memsize`。断开 Wi‑Fi、以太网或热点。将 App 移到「应用程序」，从 Finder 首次打开。
2. 核对生日首屏，进入「回忆」浏览示例。进「修图」选合成照片，放大并平移，做一次固定比例裁剪、90° 旋转、曝光和饱和度调整。试撤销和重做。
3. 保存 `.comp` 工程，分别导出 PNG 和 JPEG。通过系统播放器打开导出的短片，记录画面、约 3 秒时长以及静音。CI 的精确帧率和帧数从文件回读。
4. 用 ⌘Q 退出并重新启动。按 ⌘O 打开刚保存的工程，核对照片方向、裁剪、调色和再次导出。全程保持断网。
5. 回传每项通过或失败、错误原文、是否出现系统安装提示。截图只包含合成素材。参考机和目标机各记一份结果。

## 12 MP 记录

使用同一张 4000×3000 合成图，在各环境从新进程开始记录。选图等待从确认文件面板算到画布可编辑，保存和短片导出从确认目标位置算到文件写成，工程重开从确认工程文件算到画布可编辑。可用系统「活动监视器」取得进程 PID，在另一个终端采样常驻内存：

```bash
read -r app_pid
while rss="$(ps -o rss= -p "$app_pid")"; do
  printf '%s\n' "$rss"
  sleep 0.25
done | awk 'NF && $1 > peak {peak = $1} END {printf "采样峰值 RSS: %.1f MiB\n", peak / 1024}'
```

输入 PID 后进行完整流程，最后正常退出 App，终端会输出采样峰值。记录计时方法和采样频率，CI 进程峰值另行记录。

| 环境 | 型号 / macOS / 内存 | 选图秒 | 保存秒 | 短片秒 | 重开秒 | 峰值 MiB 与口径 |
|---|---|---|---|---|---|---|
| CI | 见任务卡对应 run | | | | | |
| 参考机 | 待实测 | | | | | |
| 目标机 | 待实测 | | | | | |
