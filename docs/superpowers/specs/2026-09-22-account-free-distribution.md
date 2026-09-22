# 无开发者账号构建与分发

用户目标：无需 Apple 账号、团队证书或年费，保留独立 Finder 扩展架构，
通过自有 Homebrew tap 分发未公证的 ad hoc 签名应用。用户授权实现细节自主决定。

## 设计

- 主程序保持非沙盒，Finder 扩展保持沙盒及现有 `/` 只读例外。
- 共享目录为真实账户 home 下的 `Library/Application Support/OneClick/`。
  通过 `getpwuid_r` 读取账户 home，不能采用沙盒重定向的 HOME 或 Foundation 默认 home。
- 扩展增加 `com.apple.security.temporary-exception.files.home-relative-path.read-write`，
  仅覆盖 `/Library/Application Support/OneClick/`（目录必须有结尾斜杠）。
- 移除 App Group entitlement、Info.plist 元数据及运行时团队检测。
  配置 schema、原子写入、通知、输入验证、错误读写上限不变。
- 共享目录带 `.oneclick-owner.plist`（`CFBundleIdentifier=local.oneclick.app`）供卸载识别。
  拒绝把符号链接、已有非空无标记目录或其他所有者目录认领为本应用数据。
- 不自动扫描或迁移旧 App Group，避免正常启动访问受保护容器；文档提供显式复制步骤。
  卸载仍按旧容器元数据识别历史数据，默认报告，只有 `--apply` 删除。
- Xcode 项目、本地运行和 Release 都用 `CODE_SIGN_IDENTITY=-`、空 DEVELOPMENT_TEAM。
  旧 `Local.xcconfig` 保持忽略且不删除，构建不再包含它。
- Release 脚本检查版本、arm64 和嵌套签名，创建带 Applications 链接的只读压缩 DMG。
  对 DMG 验证完成后才原子替换最终产物，生成 SHA-256 和对应 cask。
- GitHub Actions 的 v* tag 流程在 macos-26 检查和构建；仅最终 draft job 有 contents:write。
  重跑只更新 draft，已发布版本不可覆盖。手工重跑只接受现有合法版本 tag。
- Cask 使用实际 DMG 哈希，要求 arm64/macOS 26；README 说明未公证和定向 xattr 操作。
  tap 默认按已配置 origin 使用 JasonG98/homebrew-tap，生成文件待维护者放入 Casks/oneclick.rb。
  不在此任务中创建远程仓库、推 tag 或发布公开版本。

## 方案取舍

普通目录加受限写入例外使扩展仍能独立执行。转由常驻主程序/XPC 代理会改变产品生命周期，
保留 App Group 则无法实现无账号目标，故都不采用。旧配置显式迁移避免为兼容而保留弹窗来源。

## 验证

自动化覆盖临时 home 下共享存储、错误回报、拒绝错误所有权，及 DMG/cask/卸载失败分支。
实编译并检查主程序/扩展的 ad hoc 签名与 entitlements。尝试真实沙盒探针及 Finder 加载。
未亲自验证的无 TCC 弹窗、干净账户初装、Finder 完整交互与 Homebrew 安装不能标成通过。
