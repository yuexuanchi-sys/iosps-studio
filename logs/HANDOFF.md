# 会话交接日志（HANDOFF）

> **新记录写在最上面**，只追加不修改。模板见 [docs/workflow/session-protocol.md §5](../docs/workflow/session-protocol.md)。
> 新会话只需要读**最上面一条**；需要追溯历史时再往下看。

---

## 2026-11-21 · 拾光簿原型、离线验收候选包与主线回归

- **原型状态**：`t-0008-compositor-prototype` 在 `artifacts/worktrees/t-0008-compositor-prototype`。T-0009 在 review。源码 `3740195` 的 [run 44920382778](https://github.com/yuexuanchi-sys/iosps-studio/actions/runs/44920382778) 通过三页导航、校验实际放大字号及完整文件编辑。已查看 `artifacts/prototype/44920382778/review-sheet.png`。T-0008 的原产物仍在 `artifacts/prototype/44784457809/`。
- **短片与 ZIP**：T-0010 源码 `4bbda3e` 的 [run 44921126380](https://github.com/yuexuanchi-sys/iosps-studio/actions/runs/44921126380) 成功。AVFoundation 与本地 PyAV 取证 3.000 秒、30 fps、90 帧、无音轨。MP4 与 ZIP 分别在 `artifacts/prototype/44921126380/retouched-memory.mp4` 和 `artifacts/prototype/44921126380/iosps-compositor-prototype/`。ZIP 为 arm64、26.0、ad-hoc，解包签名与精确权限核验通过，SHA-256 见任务卡。
- **目标机阻塞**：T-0010 的 AC2 余断网首开、修图、短片与重开恢复，AC3 余参考机和目标机的 12 MP 数据。CI 宿主导入 0.185 秒、保存 0.354 秒、成片 0.853 秒、重开 0.254 秒，峰值约 498.6 MiB。验收用 `artifacts/prototype/acceptance/landscape-12mp.jpg` 与 [断网清单](../docs/workflow/prototype-offline-acceptance.md)。T-0009 等用户界面评审。
- **独立主线**：T-0203 快照代码 `5de11ac`，[run 44922099330](https://github.com/yuexuanchi-sys/iosps-studio/actions/runs/44922099330) 的三种实际 PNG 已查看。快进主线 `ed263b5` 后 [run 44922448800](https://github.com/yuexuanchi-sys/iosps-studio/actions/runs/44922448800) 成功。T-0207 的五种合成格式回归在 `t-0207-media-library` 的 `e402247`、[run 44922628475](https://github.com/yuexuanchi-sys/iosps-studio/actions/runs/44922628475) 通过，48 项 SwiftPM 用例及主线 Release 和宿主测试成功。主线部署目标 14.0／arm64。
- **主线合入回归**：`main` 的 `524f39c` 自动 [run 44922945754](https://github.com/yuexuanchi-sys/iosps-studio/actions/runs/44922945754) 为 success。收尾 `python tools/check_repo.py` 为 0 error，两个既有 warning 是 T-0102/T-0103 等 T-0101。
- **接续**：在 `D:\IOSPS` 运行 `Get-Content -Raw -Encoding UTF8 tasks/T-0205-media-import-and-storage.md`，按实施要点接 Finder 选取和拖放。收到真机和界面反馈时按 T-0009/T-0010 逐项记录。正式迁移仍等 D-12 用户确认。

---

## 2026-11-20 · 首次 macOS CI 与 Compositor 派生编辑器验证

- **任务**：T-0004、T-0005、T-0202、T-0006、T-0008 已完成。首轮 CI 同时完成 T-0201、T-0204、T-0206、T-0305、T-0306、T-0501 的运行验收。T-0207 部分验收，余下全格式／色彩测试。T-0009 已细化，待接取。
- **完成**：D-04/D-05 确认私有仓库和本轮 Git 权限。建立 `yuexuanchi-sys/iosps-studio`，审计 93 个首次暂存路径，`main` 首推 SHA `8e8f61d`。R04 的只读评估确认上游 `4a17b264` 的 macOS 26／Apple 芯片要求与复用边界。D-12 确认先做完整继承原型，代码在 `artifacts/worktrees/t-0008-compositor-prototype` 的私有 `t-0008-compositor-prototype` 分支。
- **验证**：[冒烟 44775125352](https://github.com/yuexuanchi-sys/iosps-studio/actions/runs/44775125352) 通过 47 个测试及 arm64 Release，已查看 `artifacts/smoke/44775125352/birthday-smoke.png` 并核对 ZIP。 [正式 CI 44777973616](https://github.com/yuexuanchi-sys/iosps-studio/actions/runs/44777973616) 通过 47 个 SwiftPM、1 个宿主测试及签名包回读。 [原型 44784457809](https://github.com/yuexuanchi-sys/iosps-studio/actions/runs/44784457809) 测试 SHA `8001a93bf62f5bc58c6365d3aec8782424f06ecf`，47 基线、3 原型用例，Swift 6／Xcode 27.1，Release 75.863 秒。`artifacts/prototype/44784457809/` 的 ZIP、日志、SHA-256、签名与权限已回读。L0 为 0 error，2 个既有 warning 为 T-0102/T-0103 等 T-0101 验收。
- **未完成**：T-0009 中文界面、生日和回忆及 L3 截图，T-0010 短片与目标机断网验收。T-0203 主线快照、T-0207 剩余格式及 P3、T-0205 Finder 集成继续待办。Windows `swift --version` 找不到命令。正式迁移或提高主线下限等待原型证据与用户确认。
- **注意**：Windows Git 全局代理不可达，使用单次 `git -c http.proxy=` 配合 gh 凭据助手。原型 Xcode 26.6 在 Swift 6 优化阶段复现 IRGen 崩溃，改用 `xcode-27` 后完成构建。Release 关闭 Xcode 自动注入调试权限，CI 比对签名权限并解包验签。主线仍按 macOS 14.0／arm64 验收。
- **下一步**：上下文交接。先在原型工作树按 T-0009 复用 `GiftKit` 和应用会话，接简体中文导航、生日与合成回忆包，再运行 `xcodebuild -project IOSPSCompositorPrototype.xcodeproj -scheme CompositorPrototype -destination 'platform=macOS' test`，回读浅、深色与放大字号截图。随后执行 T-0010。

---

## 2026-11-20 · GitHub 登录验证、MacBook 基线及 MediaIO

- **任务**：T-0004 的登录 AC2 已勾选，T-0004/T-0005 仍等 D-04/D-05；T-0205 拆出 T-0206/T-0207，两张新卡待 macOS 验证。
- **完成**：`gh` 2.105.0 联网 `gh auth status --hostname github.com` 返回 0。记录 D-07 为 M 系列 MacBook，部署下限仍是 macOS 14.0／arm64，M1／8 GB 为性能参考。MediaIO 新增文件草稿、媒体 UUID 存储、逐项导入和方向校正的 512 像素 PNG。
- **验证**：L0 `check_repo` 0 error、2 条既有 PRD 依赖警告；静态核对 SwiftPM 接线、合成 PNG 文件校验、无实现占位符。新增 9 个 macOS 测试声明，当前合计 47 个 Swift 测试声明。
- **待验证**：本机找不到 `swift`。用首次 CI 验证 L1、MediaIO、Mac 构建、签名和产物回读。Finder 入口、全部格式验收和权限反馈仍在 T-0205。
- **注意**：沙箱内 GitHub API DNS 解析失败，已通过联网只读执行验证登录。需要用户确认远端可见性与首次 Git 操作授权；按纯技术前置条件调整了 T-0004 依赖，交付日期单独确认。
- **下一步**：获 D-04/D-05 后先做 T-0004，审计待上传的路径，再触发 T-0005。依照 CI 实际结果收口任务，然后做正式 CI、截图和 Finder 集成。

---

## 2026-11-20 · macOS 产品基线、Swift 工程与冒烟准备

- **任务**：T-0003 → done；T-0101/T-0102/T-0103 → review；T-0004/T-0005/T-0007/T-0104/T-0201/T-0204/T-0305/T-0306/T-0501 → blocked；T-0006 → dropped；T-0202/T-0203/T-0205 已滚动细化为 ready。
- **产出**：ADR-0003/0005 Accepted；PRD v1.0 有 16 个 macOS P0 故事；11 张交互线框、3 套视觉方向、本地回忆清单；SwiftPM、AppMac、XcodeGen、GitHub workflow；草稿与历史、礼物日期、回忆清单、短片模板及时间轴。
- **L0 证据**：`python tools/check_repo.py` 0 error，2 条评审依赖警告来自 T-0101 尚未确认；PRD 与清单 P0 16/16 匹配；YAML、xcstrings、两个 JSON 示例可解析；L1 import 反例 3 项在相应行检出；五段 CI shell 通过 `bash -n`。
- **待验证**：38 个 Swift 测试已写但未执行。执行 `swift test --package-path app`；T-0005 按任务卡发起 macOS CI，核对实际 App 构建、ZIP、ad-hoc 签名、PNG 和耗时。ADR-0004 仍为 Proposed。用户确认 PRD/交互/视觉和素材后补其验收。
- **注意**：Git 未初始化，D-04/D-05 待答。Windows WinGet 别名不可启动，已有 VS C++ 工具但尚无 Swift；用户可走 T-0007，CI 是另一条 L1 路径。用户素材仅放私密目录，当前无需读内容。
- **下一步**：从 STATUS 的 T-0004/T-0005 解阻与验证开始。完成冒烟后推进正式 CI、快照和 MediaIO，并用新证据收口 L1 卡片。

---

## 2026-11-20 · 平台定为 macOS + 执行代理提示词

- **任务**：T-0002（→ blocked：D-01 已答，D-04 / D-05 未答）；T-0003（依赖改为 T-0001，`ready`，作为下次会话的当前任务）
- **完成**：
  - 记录用户决定 **D-01 = macOS**；D-02 / D-03 / D-06 / D-07 写入暂定默认值（STATUS，标 ⚠️）
  - 新增 [executor-prompt.md](../docs/workflow/executor-prompt.md)：可以反复使用的执行代理提示词（连续执行、真正阻塞的定义、质量标准、诚实规则、停止条件、固定格式报告）+ 启动语 + 用户检查清单
  - 新增根目录 `AGENTS.md`（给 Codex / GPT 等代理的入口，指向 CLAUDE.md）
  - 依赖调整：T-0201 改为依赖 T-0003（代码可以先写，验证等 T-0007 / T-0005）
  - check_repo：必备文件加上 AGENTS.md 和 executor-prompt.md；STATUS 当前任务允许是 `ready`
- **验证**：L0：check_repo 0 error
- **注意（坑）**：Swift 代码在这台机器上还无法编译，执行代理写完代码只能标 `blocked`（待验证），不能标 `done`
- **下一步**：执行代理按提示词从 T-0003 开始，连续推进 T-0101 → T-0102 → T-0103 → T-0104 → T-0007 → T-0201

---

## 2026-11-20 · 调研复核 + 项目库与工作流搭建

- **任务**：T-0001（→ done）；T-0002（→ in-progress，等用户回答）
- **完成**：
  - 复核了 DeepSeek 的调研：16 个开源仓库数据全部一致；确认了 Compositor 的系统要求、Xcode 27、macOS 27、GitHub macOS runner、Gatekeeper 的变化 → [R03](../docs/research/R03-fact-check-2026-11-20.md)
  - 调研文件移到 `docs/research/`（修复了 R02 里一个失效链接；`tools/md_to_docx.py` 的默认路径改为相对仓库）
  - 建立：CLAUDE.md、STATUS.md、README.md、docs/（charter、6 份 ADR、PRD 草案、功能清单、易用性原则、架构总览、模块卡、4 份工作流文档）、tasks/（看板 + 模板 + 11 张任务卡）、content/、`tools/check_repo.py`、.gitignore、.gitattributes
- **验证**：L0：`python tools/check_repo.py` → 0 error
- **未完成 / 遗留**：Git 没有初始化（需要用户授权，D-05）；平台未定（D-01）
- **注意（坑）**：
  - GitHub API 匿名调用每小时只有 60 次，批量查仓库很快就会用完 → 用 raw.githubusercontent.com，或者 T-0004 之后用 `gh api`（登录后额度 5000 次/小时）
  - 这台机器上 WebFetch 访问不了 github.com 和 developer.apple.com（安全策略拦截），要用 curl 或 WebSearch
  - R02 默认朋友有 MacBook —— 用户**没有确认过**，D-07 必须先问清楚
- **下一步**：用户回答 D-01 ~ D-07 → T-0003 定稿平台 / 分发 → T-0004 Git/GitHub → T-0005 CI 冒烟测试
