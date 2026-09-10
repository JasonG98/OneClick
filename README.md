# OneClick

极简的 macOS Finder 右键工具。Swift 6、SwiftUI、原生 Liquid Glass，零第三方运行时依赖。

需要 **macOS 26+、Apple Silicon（arm64）**。

## 功能

- **在应用中打开**：仅内置 Claude Code，其他应用由用户导入 `.app`，支持开关和排序。仅在选中项目全部为文件夹或在文件夹空白处右键时显示；前 3 个已启用且可用的应用直接显示，其余折叠到子菜单。选中文件或混选时使用系统“打开方式”。旧配置中的四个预置应用会自动移除，用户导入的应用保留。
- **复制绝对路径**：保留中文、空格和特殊符号；多选时每行一个路径。
- **文件夹空白处**：操作当前目录。Claude Code 遇到文件时使用其父目录，多选目录会去重。
- 独立配置窗口；配置自动保存，Finder 扩展由系统管理。

## 本地构建

安装 Xcode 26 并完成首次启动组件安装，在 Xcode 添加 Apple 开发者账号与开发证书。在本机创建不提交到 Git 的 `config/Local.xcconfig`：

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

通过官方 `claude-cli://open?cwd=…` 深链接启动，仅传目录。终端沿用 Claude Code 最近使用的受支持终端。

必须先安装 Claude Code 并注册有效的 URL Handler；配置窗口会隐藏不可用的菜单入口。若安装升级后 Handler 指向已删除的旧版本，需要按 Claude Code 的流程重新注册。[Claude Code 深链接文档](https://code.claude.com/docs/en/deep-links)。

## 验证

```sh
./script/check.sh          # Swift 行为测试、分发脚本测试和 Shell 语法检查
./script/check.sh --build  # 再编译主应用与扩展；不签名、不启动、不操作 Finder

# 开发时只跑受影响的测试
./script/test.sh --filter SettingsModelTests
./script/test.sh --filter OpenFlowTests
```

受嵌套沙盒限制的开发环境可对 SwiftPM 追加 `--disable-sandbox`；应用自身的 Finder 扩展仍启用 App Sandbox。构建日志在 `.build/logs/build.log`，`./script/build_and_run.sh --telemetry` 可查看 OneClick 的系统日志。

核心逻辑、配置模型、真实 NSMenu 构造、打开请求传递与权限访问前检查均通过 Swift Testing 验证。测试仅替换系统调用，使用隔离临时文件，不启动目标应用、不写系统剪贴板、不访问实际 App Group。测试分层与命令见 [测试说明](docs/testing.md)；真实 Finder 接入和视觉外观仍以 [验收记录](docs/verification.md) 为准。

## Homebrew 分发

发布目标是自有 tap 的 Homebrew Cask。签名、公证、ZIP 和 Cask 生成脚本已准备，详见 [发布说明](docs/releasing.md)。尚未发布公开下载版本；需要 Developer ID、公证配置和实际仓库地址。

## 工程结构

| 路径 | 职责 |
| --- | --- |
| `src/app/` | SwiftUI 配置窗口与 Observation 状态 |
| `src/finder-extension/` | Finder 菜单、选择快照和复制路径 |
| `src/shared/core/` | 选择语义、配置校验、Claude 链接及可测试行为 |
| `src/shared/platform/` | App Group、应用解析、一次性打开请求与系统 API |
| `config/` | 主应用和扩展的 Info.plist、entitlements |
| `tests/` | 核心逻辑、应用行为和发布脚本测试 |
| `script/` | 本地构建、测试和发布 |
| `docs/` | 设计、计划、验证记录和发布说明 |

普通目录统一使用小写，多词用连字符；Swift 文件保留类型名称，工程文件与工具固定名称保留原名。项目约定见 [AGENTS.md](AGENTS.md)，插件生成文件时也应遵循这些路径。

Xcode 只有主应用和嵌入扩展两个产品 target，共享代码直接编入。Swift Package 编译同一份共享代码及配置模型，执行核心与行为测试。工程文件已经提交到源码目录；需要重新生成时运行 `python3 script/generate_project.py`。
