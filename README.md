# OneClick

极简的 macOS Finder 右键工具。Swift 6、SwiftUI、原生 Liquid Glass，零第三方运行时依赖。

需要 **macOS 26+、Apple Silicon（arm64）**。

## 功能

- **在应用中打开**：内置 Visual Studio Code、Cursor、Sublime Text、Terminal、Claude Code，可添加其他 `.app`、开关和排序。
- **复制绝对路径**：保留中文、空格和特殊符号；多选时每行一个路径。
- **文件夹空白处**：操作当前目录。Terminal 和 Claude Code 遇到文件时使用其父目录，多选目录会去重。
- 独立配置窗口；配置自动保存，Finder 扩展由系统管理。

## 本地构建

安装 Xcode 26 并完成首次启动组件安装，在 Xcode 添加 Apple 开发者账号与开发证书。在本机创建不提交到 Git 的 `Config/Local.xcconfig`：

```xcconfig
DEVELOPMENT_TEAM = 你的十位TeamID
```

随后运行：

```sh
./script/build_and_run.sh --verify
```

也可打开 `OneClick.xcodeproj`，或使用 Codex 的 Run 按钮。开发脚本使用 Apple Development 签名，生成：

```text
.build/DerivedData/Build/Products/Debug/OneClick.app
```

首次打开后点击“启用扩展”，在系统设置的“通用 → 登录项与扩展 → 文件提供程序”启用 OneClick。随后在覆盖目录内右键文件或文件夹。系统初始化扩展可能需要数秒。

当前 macOS 的共享容器需要有效的团队签名。ad hoc 签名不能授权 App Group，可能引起反复的“访问其他 App 数据”提示。开发脚本禁止在缺少团队配置时运行集成版本，运行时也会在访问共享容器前验证签名团队。无证书时仍可执行 `--build-only` 和核心测试。[Apple 共享容器授权说明](https://developer.apple.com/documentation/xcode/accessing-app-group-containers)。

默认覆盖用户主目录及其子目录，可在配置窗口增加目录。Finder 对 iCloud、File Provider、应用程序目录和重叠扩展有自己的限制；启用状态不代表每个目录都提供菜单。[Apple 对 Finder Sync 覆盖范围的说明](https://developer.apple.com/forums/thread/756711)。

## Claude Code

通过官方 `claude-cli://open?cwd=…` 深链接启动，仅传目录。终端沿用 Claude Code 最近使用的受支持终端；与列表里的 macOS Terminal 开关独立。

必须先安装 Claude Code 并注册有效的 URL Handler；配置窗口会隐藏不可用的菜单入口。若安装升级后 Handler 指向已删除的旧版本，需要按 Claude Code 的流程重新注册。[Claude Code 深链接文档](https://code.claude.com/docs/en/deep-links)。

## 验证

```sh
./script/test.sh
Tests/ReleaseScripts/run_tests.sh
```

受嵌套沙盒限制的开发环境可对 SwiftPM 追加 `--disable-sandbox`；应用自身的 Finder 扩展仍启用 App Sandbox。构建日志在 `.build/logs/build.log`，`./script/build_and_run.sh --telemetry` 可查看 OneClick 的系统日志。

核心逻辑通过 Swift Testing 验证；真实 Finder 菜单、应用启动和目录覆盖仍以 [验收记录](docs/verification.md) 为准。

## Homebrew 分发

发布目标是自有 tap 的 Homebrew Cask。签名、公证、ZIP 和 Cask 生成脚本已准备，详见 [发布说明](docs/releasing.md)。尚未发布公开下载版本；需要 Developer ID、公证配置和实际仓库地址。

## 工程结构

| 路径 | 职责 |
| --- | --- |
| `OneClick/` | SwiftUI 配置窗口与 Observation 状态 |
| `FinderExtension/` | Finder 菜单、选择快照和复制路径 |
| `Shared/Core/` | 选择语义、配置校验、Claude 链接及可测试行为 |
| `Shared/Platform/` | App Group、应用解析、一次性打开请求与系统 API |
| `Config/` | 主应用和扩展的 Info.plist、entitlements |
| `script/` | 本地构建、测试和发布 |

Xcode 只有主应用和嵌入扩展两个产品 target，共享代码直接编入。Swift Package 单独执行核心测试。工程文件已经提交到源码目录；需要重新生成时运行 `python3 script/generate_project.py`。
