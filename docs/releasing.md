# 发布

使用 ad hoc 签名，目标为 Apple Silicon / macOS 26+；无需 Apple 账号、证书或公证密钥。

## 本地打包

```sh
./script/check.sh
python3 script/release.py 0.1.0
```

`release.py` 构建 Release，检查主程序和扩展的版本、arm64 架构与签名，再生成：

- `dist/OneClick-0.1.0.dmg`（应用、Applications 链接和安装说明）
- `dist/OneClick-0.1.0.dmg.sha256`
- `dist/oneclick.rb`（使用该 DMG 的实际哈希）

所有检查成功后才替换产物。可用 `ONECLICK_DERIVED_DATA_PATH`、`ONECLICK_DIST_DIR` 调整目录；同一目录只运行一个构建。

## CI/CD

`check.yml` 在 push / PR 时检查工程生成结果，运行测试和无签名编译。
`release.yml` 在 `vMAJOR.MINOR.PATCH` tag push 或手动选择已有 tag 时运行，只有一个任务：
检出并核对 tag → 测试 → 打包 → 创建 GitHub **草稿**。

维护者完成审阅、桌面验证和许可证选择后提交代码，再推送版本 tag。
流水线用 GitHub 提供的 token，无额外签名 secrets。手动上传可执行
`python3 script/release.py 0.1.0 --draft`，要求当前提交匹配 tag 且工作区干净（包括未跟踪文件）。
同 tag 可刷新草稿附件；已公开的 release 拒绝修改。修复已发布版本时使用新版本号。

下载草稿附件验证安装和 Finder 操作后，再人工公开。
如维护 Homebrew tap，将 `oneclick.rb` 放入 `JasonG98/homebrew-tap/Casks/`，在 release 公开后发布。
远程 Actions、公开 tap 的安装/升级仍需实际验收，见[验收记录](verification.md)。

## 安装与卸载

应用未公证，下载后可能被 Gatekeeper 拦截；确认来源和 SHA-256 后，按 [README](../README.md) 操作。
Cask 只提示解锁命令，不自动移除 quarantine。
`uninstall.sh` 默认只报告，`--apply` 执行；应用按 bundle ID、共享目录按归属标记确认。
旧 Group Containers、仓库构建目录和本地配置保留。

## 旧版配置迁移

新版使用 `~/Library/Application Support/OneClick/`，不会读取或清理旧 App Group。

1. 打开新版创建目录后，关闭设置和 Finder 扩展。
2. 找到确属旧 OneClick 的容器（如 `~/Library/Group Containers/<Team ID>.local.oneclick.shared/`）。
3. 备份新目录的 `settings.json`，用旧文件替换它，保留新版 `.oneclick-owner.plist`。
4. 重新打开，核对应用与目录配置，再启用扩展。

非空且无归属标记的目录不会被自动认领；先备份移走，让应用重新创建，勿给未知目录补标记。
