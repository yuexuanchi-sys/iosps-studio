# ADR-0005：macOS 礼物分发

- 状态：**Accepted**
- 日期：2026-11-20
- 关联：[ADR-0003](ADR-0003-target-platform.md)、[项目章程 G5](../charter.md)、[R03](../research/R03-fact-check-2026-11-20.md)

## 决策

⚠️ D-03 暂按免费 M-0 执行。T-0801 用 macOS CI 生成 ad-hoc 签名的 `.app.zip`，在 CI 校验签名并记录 ZIP 的 SHA-256，包内只含公开资源。通过私下约定的渠道把 ZIP、校验值及 T-0802 的图文安装说明交给朋友。个人回忆经独立的本地导入流程传递。

朋友核对来源及校验值后解压，移至「应用程序」并尝试打开。若 macOS 提示无法验证开发者，使用系统设置 → 隐私与安全性 → 仍要打开（需要时验证身份）。T-0803 在目标机验证首次安装、退出重开和离线使用。没有 7 天或 90 天续签流程，系统策略和未来兼容性以实测为准。[Apple 支持：安全地打开 Mac 上的 App](https://support.apple.com/en-us/102445)

## 备选与复核

如果 D-03 确认可使用付费账号，或目标设备的安全策略不允许 M-0，复核 M-1。M-1 用 Developer ID、强化运行时和 `notarytool` 提交公证，附加公证票据后重打 ZIP，重新验证首次打开。收费与凭据由用户确认。[Apple：Developer ID 签名](https://developer.apple.com/developer-id/) · [Apple：公证与分发](https://developer.apple.com/documentation/security/notarizing-macos-software-before-distribution)

## 约束

遵守系统 Gatekeeper 设置和目标机管理策略。企业证书、共享账号、越狱和私有 API 不纳入分发方案。
