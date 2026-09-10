# OneClick 极简 Finder 右键工具设计

日期：2026-09-10
状态：设计已确认并实施。实际验证结果与剩余范围见 [验收记录](../../verification.md)；公开分发尚未完成。

## 目标与已确认约束

在 Finder 中提供两类高频操作：在指定应用打开选中的文件或文件夹，以及复制绝对路径。支持在选中目录启动 Claude Code。用户已指定第一阶段通过 Homebrew 分发。

工程暂用当前目录名 OneClick。第一版最低支持 macOS 26，使用当前机器的 Xcode 26.6、Swift 6.3 工具链。用户已明确要求仅支持 Apple Silicon（arm64）；主应用、Finder 扩展、测试及发布产物统一使用 arm64。当前可执行实际运行验证的机器为 Apple Silicon、macOS 26.6.2。

## 方案比较

| 方案 | 使用体验 | 实现与限制 | 判断 |
| --- | --- | --- | --- |
| SwiftUI 主应用 + Finder Sync 扩展 | 在 Finder 右键中显示打开应用的子菜单和复制路径项；支持文件夹空白处 | 需要嵌入扩展、签名和首次启用；受 Finder 的目录覆盖限制 | 推荐作为第一版 |
| 原生 NSServices 服务 | 从 Finder 的服务入口调用 | 不需要 Finder Sync；入口位置与动态菜单能力不满足同样的交互目标 | 后续按实测需要作为特殊目录的补充入口 |
| 快速操作 / Shortcuts 工作流 | 从系统快速操作或服务入口使用 | 适合少量固定动作；配置、应用列表与独立产品分发需要更多拼装 | 不作为第一版产品架构 |

这两种原生方案都可以有 SwiftUI 配置窗口。区别在于 Finder 如何调用功能：Finder Sync 是嵌入应用的独立扩展，由 Finder 请求菜单与选择信息；NSServices 是应用向系统公布的动作，系统把选中数据交给应用处理。“服务”在这里并不表示必须另外运行后台守护进程。[Apple Services 说明](https://developer.apple.com/library/archive/documentation/MacOSX/Conceptual/OSX_Technology_Overview/SoftwareProducts/SoftwareProducts.html)

Finder Sync 可在菜单打开时根据设置生成应用列表，并区分选中项与文件夹背景。NSServices 的入口通常位于“服务”菜单中，系统根据选中数据决定是否显示；服务可配置快捷键，但不会直接提供 Finder 空白处的当前目录上下文。服务定义通常声明在 Info.plist 中；也可生成独立 `.service` bundle，但这需要维护额外的注册与更新流程。若提供固定的“用 OneClick 打开…”服务并随后显示应用选择器，应用列表仍可配置，但会多一次交互。[Apple Services Properties](https://developer.apple.com/library/archive/documentation/Cocoa/Conceptual/SysServices/Articles/properties.html)、[使用与配置服务](https://support.apple.com/guide/mac-help/use-services-in-apps-mchlp1012/mac)

Finder Sync 可以为监控目录中的选中项及文件夹背景提供菜单，但 Apple 明确说明它并非通用的 Finder UI 修改机制。不能把本方案描述成 Apple 专门为任意右键增强提供的新框架。[Apple Finder Sync 文档](https://developer.apple.com/library/archive/documentation/General/Conceptual/ExtensibilityPG/Finder.html)

## 第一版交互

右键菜单的两个入口：

```text
在应用中打开  ›  Visual Studio Code
                 Cursor
                 Sublime Text
                 Terminal
                 Claude Code
复制绝对路径
```

应用子菜单按设置中的顺序显示，只显示已安装并启用的目标。菜单中的应用名称和图标取自目标应用。初始内置上述五个目标，并支持在设置中选取额外的 `.app`；额外应用按普通文件打开协议处理，其支持的文件和文件夹类型由该应用决定。任意终端应用的特殊启动协议需要独立适配，不能视为普通 `.app` 自动支持。

| 操作场景 | 行为 |
| --- | --- |
| 选中文件或文件夹，打开编辑器 | 将原始选中 URL 交给指定应用；多选时批量传递 |
| 选中文件夹，打开 Terminal / Claude Code | 使用该文件夹作为工作目录 |
| 选中文件，打开 Terminal / Claude Code | 使用该文件的父目录作为工作目录 |
| 多选并打开 Terminal / Claude Code | 将工作目录去重，每个唯一目录发起一次打开请求；窗口或标签页形式由目标应用决定 |
| 复制路径 | 复制文件系统绝对路径，不转成 `file://` URL，不加 shell 引号；多选时每个路径一行 |
| 右键文件夹空白处 | 对当前目录执行相同操作 |
| 路径包含中文、空格、引号、`&`、`#` | 原样保存路径；交给 URL API 正确编码，不能拼接成 shell 命令 |
| 符号链接 | 复制 Finder 选中项本身的绝对路径，不主动解析成目标路径 |
| 应用不存在或 Claude URL Handler 未注册 | 设置中显示不可用状态和具体原因；不在菜单中显示失效入口 |
| 点击后目标被删除或启动失败 | 显示简短失败原因；不得静默转而打开其他目录 |

第一版设置只有一个原生窗口：扩展状态与启用入口、应用列表及启用/排序/添加、工作目录覆盖范围。用户已明确要求最新 Liquid Glass UI：采用 macOS 26 原生 SwiftUI 工具栏与玻璃按钮，必要的自定义交互面使用 `glassEffect`，相邻玻璃元素放入同一个 `GlassEffectContainer`。应用列表保持系统原生内容表面，避免叠加模糊层影响可读性。遵循系统字体、深浅色外观、降低透明度与增强对比度设置。首次启动引导启用 Finder 扩展，正常使用时可关闭主应用，扩展由系统管理。Finder 右键菜单的材质与排布由系统管理。

配置窗口具体包含：

- 应用列表：自动识别内置目标的安装状态；勾选是否出现在右键菜单，拖动排序，添加/移除额外 `.app`。
- Claude Code：单独的启用开关、handler 可用状态；启动方式显示“自动：沿用 Claude Code 最近使用的终端”，并提供简短的更换终端说明。
- 复制路径：是否显示该菜单项；多选默认按行复制。
- Finder 扩展：启用状态、前往系统管理的入口与目录覆盖设置。

“Terminal”菜单项明确指 macOS Terminal.app；Claude Code 的终端选择由其 handler 管理，两者的偏好并不绑定。第一版不显示一个实际不起作用的终端选择下拉框。若后续要求在 OneClick 内固定 Claude 终端，则新增经过验证的终端启动适配器及独立偏好，不修改 Claude 的内部状态文件。

首版不增加菜单栏常驻图标、账号、云同步、历史记录、任意 shell 命令编辑器、应用内自动更新或额外后台守护进程。更新通过 Homebrew 完成。

## 最小原生架构

一个 Xcode 工程，包括主应用、嵌入的 Finder Sync 扩展和测试 target；共享的少量 Swift 类型直接加入相应 target。应用运行时不引入第三方依赖。

| 部分 | 职责与技术 |
| --- | --- |
| OneClickApp | SwiftUI 窗口与 Form；Observation 管理设置状态；展示扩展启用和应用可用性 |
| FinderExtension | `FIFinderSync` 与 `NSMenu`；读取真实选择、构建菜单、执行用户选择的操作 |
| OpenTarget / Selection | 类型化目标配置与选择解析；区分原始 URL、工作目录和复制文本 |
| ActionExecutor | `NSWorkspace` 异步打开指定应用或 URL；`NSPasteboard` 写入路径 |
| SettingsStore | App Group 内共享的轻量 Codable 设置文件，采用原子替换；扩展在构建菜单时读取最新快照 |
| Tests | Swift Testing 验证选择语义、路径编码、目录去重和配置读取 |

`NSWorkspace.open(_:withApplicationAt:configuration:)` 提供异步打开指定应用的接口，普通编辑器打开不依赖 `code`、`cursor` 或 `subl` 命令进入 PATH。[Apple NSWorkspace 文档](https://developer.apple.com/documentation/appkit/nsworkspace/open(_:withapplicationat:configuration:completionhandler:))

第一条待运行验证的路径是由沙盒 Finder 扩展直接调用这些系统接口，主应用负责设置。当前 SDK 中这些 NSWorkspace 接口未标为 app-extension unavailable，但头文件可用性不能证明沙盒下每种目标都能正常启动。先验证真实 Finder 菜单到编辑器、Terminal 和 Claude Code 的调用，再扩展设置 UI。

如果实测发现某个必要操作受扩展沙盒限制，只把该操作转交主应用：使用 App Group 中一次性请求文件和应用唤醒，执行固定的类型化动作。请求仅包含应用标识和文件 URL，不引入通用命令执行协议。该后备方式不需要独立常驻服务。

扩展中的运行错误可存入 App Group，并唤醒主应用在设置窗口显示。操作成功时保持安静。诊断使用系统 Logger，不依赖自建日志服务。

## Terminal 与 Claude Code

Terminal 优先通过 `NSWorkspace` 打开目录。当前机器的 Terminal.app 声明支持 `public.directory`；实际 cwd、新窗口及已运行实例的行为仍须在 Finder 中验证。首版不需要通过 AppleScript 拼接 `cd`。

Claude Code 使用官方链接：

```text
claude-cli://open?cwd=<经过 URL 编码的绝对目录路径>
```

用 Foundation 的 `URLComponents` / `URLQueryItem` 生成链接，仅设置 `cwd`，不预填或自动发送任务。官方 handler 负责启动终端及 Claude Code，并复用其支持的终端偏好。Claude Code 仍管理自身的登录、目录信任与权限。[Claude Code 深链接文档](https://code.claude.com/docs/en/deep-links)

在 macOS 上，官方 handler 会记住并复用最近一次 Claude Code 交互会话使用的受支持终端，包括 Terminal.app、iTerm2、Ghostty、kitty、Alacritty 和 WezTerm。不能将其描述为固定默认 Terminal.app，也不能仅根据机器上安装了 Ghostty 就推断本次会打开 Ghostty。官方链接参数未提供 `terminal=` 选择项；固定终端需要单独启动适配。[Claude Code 终端选择与链接参数](https://code.claude.com/docs/en/deep-links)

当前机器已经存在 `~/Applications/Claude Code URL Handler.app`，其 Info.plist 声明了 `claude-cli` scheme；这证明本地存在 handler 包，还不能代替实际 URL 打开验证。应用应通过 Launch Services 查询可处理该链接的应用，不依赖 handler 的固定安装位置。

官方文档说明 handler 会在交互会话中发送首个提示后注册。未注册时显示该配置说明；不自动替用户发送提示，也不将需要更新/注册的状态伪装成可用。官方 `cwd` 对网络路径及部分控制字符有限制，遇到不支持的路径须给出原因。[Claude Code 注册与参数说明](https://code.claude.com/docs/en/deep-links)

## Finder 范围与兼容边界

第一版优先覆盖真实用户主目录下的本地目录，并允许额外选择需要覆盖的目录，例如外置磁盘中的工作目录。通过配置目录及 Finder 回调工作，不递归扫描文件树、不增加轮询。

Finder Sync 对特殊目录及扩展重叠有已知限制。Apple 工程师指出 `/Applications` 等位置不能正常工作，开发者也报告过 iCloud Drive 的限制；这些材料不能直接当作当前机器所有目录的测试结果。[Apple 开发者论坛中的工程师说明与开发者反馈](https://developer.apple.com/forums/thread/756711)

必须单独检查本地项目、Downloads、Desktop、Documents、外置盘，以及可用的 iCloud/File Provider 目录。Desktop/Documents 是否由 iCloud 管理需要区分。对于 Finder 不提供扩展菜单的区域，首版明确标注覆盖边界；NSServices 是可选的后续补充，不能声称它会恢复同样的顶层菜单或空白处菜单。

扩展首次启用通过系统界面完成。系统管理界面的入口是否有效须在 macOS 26.6.2 上验证，不把强制修改 pluginkit 状态当成产品安装流程。

## Homebrew 分发

首发采用自有 Homebrew tap 中的 Cask，下载 GitHub Release 中打包好的 `.app`。Cask 包含真实版本号、下载 URL、SHA-256、最低系统版本、仅限 arm64 的架构要求与 `app "OneClick.app"`。自有 tap 可独立分发，不依赖首先被 Homebrew 主仓库接纳。[Homebrew Taps](https://docs.brew.sh/Taps)、[Cask Cookbook](https://docs.brew.sh/Cask-Cookbook)

发布流程：构建 Release arm64 应用 → 对主应用与嵌套扩展正确签名 → Hardened Runtime → Apple 公证 → staple 公证票据 → ZIP 打包与 SHA-256 → GitHub Release → 更新 Cask。

公开下载版本按 Developer ID 签名和公证准备，使正常 Gatekeeper 检查可通过。Homebrew 负责安装，不代替应用签名与系统信任。普通本地 Debug 验证与正式分发分开处理。[Apple 公证说明](https://developer.apple.com/documentation/security/notarizing-macos-software-before-distribution)

实际发布需要用户指定 GitHub 仓库及 tap 所属账号，并提供可用的 Developer ID 签名/公证环境。当前未检查这些凭据，也未创建远程仓库、发布 Release 或上传任何产物；这些发布输入不阻碍先实现和本地验证应用。

## 验收与实现顺序

1. 先构建最小的主应用和扩展，验证签名、注册、启用及真实 Finder 菜单出现。
2. 用项目内测试文件夹验证 VS Code、已安装的其他编辑器、Terminal 和 Claude 深链接；检查实际打开对象与工作目录。
3. 验证选中文件、文件夹、多选、空白处、中文、空格、引号、`&`、`#`、符号链接、目标被删除以及未安装应用等情况。
4. 完成设置窗口与 App Group 配置，验证主应用关闭后右键动作仍有效，设置变更反映到下一次菜单中。
5. 记录各类 Finder 目录的实测覆盖范围，不用普通目录测试替代特殊目录测试。
6. 在 Apple Silicon 上运行 Swift Testing、Release 构建与嵌套 bundle/签名校验；检查主程序和扩展的二进制架构均仅为 arm64，并完成实际运行验证。
7. 准备可审阅的发布脚本和 Cask；取得发布输入后验证签名、公证及 Cask 安装/升级/卸载，再进行实际发布。

本草案将“现代化”落实为当前 Swift 工具链、原生 SwiftUI、类型化数据、异步系统 API 和标准分发流程；将“极简”落实为一个应用、一个必要扩展、少量共享代码和明确的功能范围。
