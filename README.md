# OneClick

极简的 macOS Finder 右键工具。Swift 6、SwiftUI、原生 Liquid Glass，零第三方运行时依赖。

需要 **macOS 26+、Apple Silicon（arm64）**。

## 功能

- **在应用中打开**：内置 Terminal，其他应用由用户导入 `.app`，支持开关和排序。仅在选中项目全部为文件夹或在文件夹空白处右键时显示；前 3 个已启用且可用的应用直接显示，其余折叠到子菜单。选中文件或混选时使用系统“打开方式”。
- **复制绝对路径**：保留中文、空格和特殊符号；多选时每行一个路径。
- **文件夹空白处**：操作当前目录。Terminal 对文件取父目录，多选目录会去重。
- **Finder 工具栏按钮**：常驻入口。点按显示当前选区的操作，并可直接打开配置窗口。
- 配置自动保存，Finder 扩展由系统管理。

扩展在 Finder 进程内完成全部打开动作，主程序**不在后台常驻**：只有配置窗口打开时它才运行，关掉即可退出，平时只有一个扩展进程（实测物理占用约 5.7 MB）。

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

首次打开后，在配置窗口底部点按“Finder 扩展未启用”，在系统设置的“通用 → 登录项与扩展 → 文件提供程序”启用 OneClick。启用后 Finder 工具栏会出现 OneClick 按钮。系统初始化扩展可能需要数秒。

### 开关是开的，却没有菜单

Finder 只在启动时载入一次 Finder Sync 扩展，之后**不会**在扩展进程退出后自动重启它。重新构建替换掉正在运行的扩展二进制，进程随之退出，于是出现一种很容易误判的状态：系统设置里的开关仍然开着，右键菜单和工具栏按钮却全部消失，也没有任何东西可以“重新启用”。开发脚本每次构建后会自动把扩展重新注册并拉起；设置窗口底部的状态卡也把“已启用”和“正在运行”当作两件事分别显示，处于后者时点按卡片即可重新加载，不必重启 Finder。

当前 macOS 的共享容器需要有效的团队签名。ad hoc 签名不能授权 App Group，可能引起反复的“访问其他 App 数据”提示。开发脚本禁止在缺少团队配置时运行集成版本，运行时也会在访问共享容器前验证签名团队。无证书时仍可执行 `--build-only` 和核心测试。[Apple 共享容器授权说明](https://developer.apple.com/documentation/xcode/accessing-app-group-containers)。

默认覆盖用户主目录及其子目录，可在配置窗口增加目录。Finder 对 iCloud、File Provider、应用程序目录和重叠扩展有自己的限制；启用状态不代表每个目录都提供菜单。[Apple 对 Finder Sync 覆盖范围的说明](https://developer.apple.com/forums/thread/756711)。

## 沙盒授权

Finder 交给扩展的选区 URL **不附带沙盒读取权限**（Apple 问题 rdar://42874694，仍未修复）。没有额外授权时，扩展只能读取元数据：菜单能显示，路径能复制，但把文件交给任何应用都会失败——这与具体应用无关，Terminal 和编辑器一样打不开。

因此 `config/FinderExtension.entitlements` 声明了一条**只读**例外：

```xml
<key>com.apple.security.temporary-exception.files.absolute-path.read-only</key>
<array><string>/</string></array>
```

这是让扩展自足、从而不需要后台常驻主程序的前提。主程序本身没有沙盒，全盘读权限已在产品原有范围内；该例外只授予扩展，不授予主程序。若移除它，打开动作必须重新交回主程序执行。

## 验证

```sh
./script/check.sh          # Swift 行为测试、分发脚本测试和 Shell 语法检查
./script/check.sh --build  # 再编译主应用与扩展；不签名、不启动、不操作 Finder

# 开发时只跑受影响的测试
./script/test.sh --filter SettingsModelTests
./script/test.sh --filter FinderMenuTests
```

受嵌套沙盒限制的开发环境可对 SwiftPM 追加 `--disable-sandbox`。构建日志在 `.build/logs/build.log`，`./script/build_and_run.sh --telemetry` 可查看 OneClick 的系统日志。

核心逻辑、配置模型与旧版迁移、真实 NSMenu 构造、打开分流与权限访问前检查均通过 Swift Testing 验证。测试仅替换系统调用，使用隔离临时文件，不启动目标应用、不写系统剪贴板、不访问实际 App Group。测试分层与命令见 [测试说明](docs/testing.md)；真实 Finder 接入和视觉外观仍以 [验收记录](docs/verification.md) 为准。

## Homebrew 分发

发布目标是自有 tap 的 Homebrew Cask。签名、公证、ZIP 和 Cask 生成脚本已准备，详见 [发布说明](docs/releasing.md)。尚未发布公开下载版本；需要 Developer ID、公证配置和实际仓库地址。

## 工程结构

| 路径 | 职责 |
| --- | --- |
| `src/app/` | SwiftUI 配置窗口与 Observation 状态 |
| `src/finder-extension/` | Finder 菜单、工具栏按钮、选择快照和复制路径 |
| `src/shared/core/` | 选择语义、配置校验与旧版迁移及可测试行为 |
| `src/shared/platform/` | App Group、应用解析与图标缓存、系统动作 |
| `config/` | 主应用和扩展的 Info.plist、entitlements |
| `tests/` | 核心逻辑、应用行为和发布脚本测试 |
| `script/` | 本地构建、测试和发布 |
| `docs/` | 设计、计划、验证记录和发布说明 |

普通目录统一使用小写，多词用连字符；Swift 文件保留类型名称，工程文件与工具固定名称保留原名。项目约定见 [AGENTS.md](AGENTS.md)，插件生成文件时也应遵循这些路径。

Xcode 只有主应用和嵌入扩展两个产品 target，共享代码直接编入；`src/app`、`src/shared`、`src/finder-extension` 都是文件系统同步分组，**新增或删除 Swift 文件无需改动工程文件**。Swift Package 编译同一份共享代码及配置模型，执行核心与行为测试。

改动工程路径、构建设置或 target 时，改 `script/generate_project.py` 再运行它：

```sh
python3 script/generate_project.py
```

生成器只用 Python 标准库，确定性输出 `OneClick.xcodeproj/project.pbxproj` 与共享 scheme；重复运行应当零差异（可用 `git diff OneClick.xcodeproj` 自查）。不要只手改生成出来的工程文件，否则下次生成会把改动冲掉。
