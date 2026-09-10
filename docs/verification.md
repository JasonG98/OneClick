# OneClick 本地验收记录

日期：2026-09-10。环境：macOS 26.6.2、Apple Silicon、Xcode 26.6、Swift 6.3.3。

## 已通过

| 项目 | 证据 |
| --- | --- |
| Swift 核心行为 | `./script/test.sh --disable-sandbox -Xswiftc -warnings-as-errors`：40 项通过 |
| 分发脚本行为 | `Tests/ReleaseScripts/run_tests.sh`：6 项通过；Bash 语法检查通过 |
| Debug 构建与启动 | `./script/build_and_run.sh --verify` 成功，验证实际开发可执行文件进程 |
| Release 归档 | `xcodebuild ... -configuration Release ... archive` 成功；归档在 `.build/OneClick.xcarchive` |
| arm64 限制 | 对 Release 主程序与扩展执行 `lipo -archs`，均只有 `arm64`；最低系统 26.0 |
| 嵌套签名 | Debug 与 Release 主应用、扩展均由相同 Apple Development 团队签名；共享组前缀与 Team ID 一致；`codesign --verify --deep --strict` 通过 |
| Finder 注册与启用 | 系统设置“登录项与扩展 → 文件提供程序”能显示 OneClick；`pluginkit` 启用状态与应用刷新一致 |
| Finder 菜单 | 本地项目和隐藏的 `.build/fixtures` 下出现“在应用中打开”和“复制绝对路径”；只显示已安装且启用的应用 |
| 空白处复制 | 实际剪贴板内容与当前 `.build/fixtures` 绝对路径一致 |
| 多选复制 | 3 项路径均逐字正确，保留中文、空格、`+`、`#`、`&`、单引号；顺序来自 Finder 选择数组，不承诺屏幕排序 |
| Terminal 工作目录 | 从 OneClick 菜单打开特殊字符目录；通过 Terminal 登录 shell 的 `lsof -d cwd` 确认实际工作目录完全一致 |
| 编辑器打开 | Sublime Text 窗口 URL 指向正确的 `sample.txt`；VS Code 打开请求也有主应用成功日志 |
| 主应用退出后的请求 | 主应用退出后由 Finder 请求重新唤醒，执行成功；随后正常打开设置窗口 |
| 配置交互 | 开关即时保存，重启保留；右键上移 Terminal 后落盘顺序正确；目录添加能通知扩展重新注册覆盖范围 |
| 错误展示 | 早期 Terminal 启动失败能唤醒配置窗口并显示具体错误 |
| 原生界面 | 实际运行 SwiftUI 配置窗口；原生工具栏、`glassEffect`、`GlassEffectContainer` 和玻璃按钮；截图在 `.build/screenshots/settings.png` |
| 重复权限提示修复 | 换用有效团队签名后重新启动主应用、启用扩展并连续操作；最终查询最近 10 分钟 OneClick 的 TCC `AUTHREQ_PROMPTING` 日志为空 |

## 运行中发现并修复的问题

1. Finder 的菜单回调发生在 XPC 后台队列。原来的主线程假设触发 Swift 6 `EXC_BREAKPOINT`。现在先在回调内捕获选择，再通过有双向调用测试的 `MainThreadBridge` 同步构造菜单；动作仅把整数 tag 交给主线程。
2. Finder 不保留 `NSMenuItem.representedObject`。改用 tag 对应不可变选择快照，旧菜单的动作不会误用后来的选择。
3. 扩展直接打开 Terminal 失败。现在以 App Group 中限大小、带有效期的一次性请求唤醒主应用；主应用只按当前配置中的已启用目标执行，没有任意命令接口。消费后删除请求。
4. ad hoc 开发签名没有经过系统授权的 App Group 身份，触发“访问其他 App 数据”提示。已停用旧进程，改用 Apple Development 签名与实际团队前缀共享组；构建脚本禁止无团队配置的集成运行，代码在访问容器前检查签名团队。未要求 Full Disk Access，也未修改 TCC 数据库。
5. Claude 链接中的字面 `+` 现在编码为 `%2B`，避免被查询参数解析器误作空格。

排障时临时关闭过 RClick 与 Keka 的 Finder 扩展，随后已恢复当时记录的开关。实际菜单在它们启用时也能显示；未将扩展冲突误认成此次菜单崩溃的原因。

## 尚未验证与已知边界

- Claude Code：本机 Handler 的可执行文件链接指向已删除的旧版 Claude CLI；配置显示不可用。已验证链接生成，尚未实测完整 Claude 会话启动。没有代替用户发送提示、修改 Claude 状态或修补第三方安装。
- 深色模式、降低透明度、增强对比度尚未逐项人工验收；使用原生 SwiftUI 材质和系统字体。
- 自定义应用添加/移除、拖动排序、外置盘、Downloads、Desktop、Documents、iCloud/File Provider 范围尚未完整逐项验收。右键排序与本地项目范围已验证；不能据此宣称所有目录通用。
- 冷启动主应用时，系统可能在后台创建设置窗口。请求设置 `activates = false`，成功后由目标应用获得焦点。沙盒调用者的 `NSWorkspace.OpenConfiguration.arguments` 会被系统忽略，因此实现不依赖启动参数抑制窗口。
- 当前证书是 **Apple Development**。Release 归档可用于本地验证，但不是已公证的公开分发版本。
- Developer ID、公证、GitHub Release、Homebrew tap 安装/升级/卸载仍待真实发布环境与仓库地址。脚本测试使用模拟外部工具，不代表 Apple 公证或 Homebrew 安装已经完成。
