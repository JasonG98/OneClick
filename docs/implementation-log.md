# OneClick 实施记录

## 2026-09-10

- 用户确认 Finder Sync、原生 Liquid Glass 配置窗口、macOS 26+、仅 arm64；设计阶段结束，开始实施。
- 在空项目初始化 `feat/oneclick` 开发分支，直接使用当前专属项目目录。
- 按文件所有权拆分工作：子代理负责 `src/shared/core` 与纯行为测试；主代理负责 Xcode、平台集成、SwiftUI、运行验证及分发脚本。
- 测试以零依赖 Swift Package 执行，共享核心源文件同时编入主应用与扩展。这样测试不依赖 Finder 进程或图形会话。Xcode 工程保留两个产品 target，替代计划中另建 Xcode 测试 target 的工程组织。
- Xcode 初始构建阻碍：IDESimulatorFoundation 要求 DVTDownloads 中的符号，系统版本缺失该符号。Xcode 随附安装包中的对应框架包含该符号；仅调整 DYLD_FRAMEWORK_PATH 未生效，已调用官方 `xcodebuild -runFirstLaunch` 修复流程。
- Computer Use 返回“Computer Use permissions are not granted”。在授权可用前不将 GUI、Finder 菜单或玻璃外观写成已验证。

## 进度

- 核心选择语义与配置：完成，40 项 Swift Testing 通过。
- Finder 与系统动作：菜单、复制、Terminal、编辑器及主应用唤醒已实测；Claude Handler 本机不可用。
- 配置窗口：已实现并验收基本交互，详细覆盖见 `docs/verification.md`。
- Homebrew 分发准备：脚本与 6 项行为测试完成；真实公开发布待 Developer ID、公证配置与仓库地址。

## 实测调整

- Finder 菜单通过 tag 保存选择快照，避免 Finder IPC 丢失 representedObject。
- 崩溃栈证实 Finder 菜单回调在后台 XPC 队列，改用可测试的主线程桥接。
- Terminal 的扩展内直接打开失败，采用设计中的主应用执行后备路径：一次性类型化请求 + 自有 URL 唤醒。
- 用户报告反复“访问其他 App 数据”弹窗。立即暂停 OneClick 并停止开发进程，TCC 日志确认无有效 App Group 授权的 ad hoc 签名是问题来源。随后检测到 Apple Development 证书，读取证书 OU 作为真实 Team ID，配置有效签名与团队前缀共享组。
- Debug 和 Release 归档均通过嵌套签名及 arm64 校验；签名修复后的最后 10 分钟未发现 OneClick TCC 提示请求。
- 测试和发布凭据不进入 Git。旧设计文档是历史决策，实际覆盖与剩余工作以验收记录为准。

## 自动化验证补齐

- 根据用户反馈，日常验证改为先跑自动化测试和命令行构建，Computer Use 仅用于必要的真实系统接入和视觉验收。
- 增加 24 项行为测试，直接执行配置模型、NSMenu 构造、动作分流和一次性请求流程；只替换应用启动、系统剪贴板和权限查询等外部边界。
- 增加统一入口 `script/check.sh` 和 `docs/testing.md`。64 项 Swift 测试、6 项脚本测试与 arm64 编译通过，六个临时回归均被测试捕获。本轮没有 GUI 自动化操作。

## 配置窗口视觉重做

- 用户反馈配置窗口界面难看。实际截图定位到原因：窗口级 `.ultraThinMaterial` 抹平了层次，页面标题与操作挤在内容区而工具栏是空的，`.inset` 列表与窗格同色导致卡片没有边界。
- 重做为「系统负责玻璃、代码只画内容」：工具栏承载标题与玻璃按钮，列表沿用原生 `List`（拖拽排序不变）并显式绘制卡片表面，侧边栏底部状态卡是唯一使用 `glassEffect` 的自定义面。
- 新增 `IconTile`、`StatusChip`、`PanelSectionLabel`、`PanelSurface` 四个视图原语，三个页面共用；`SettingsView`、`ApplicationRow`、`DirectoryRow` 重写。
- 由于本机沙盒禁止嵌套 `sandbox-exec` 导致宏插件无法运行，构建与截图需要在沙盒外执行；视觉核对改用 `screencapture -l <window id>`，按窗口截图而不是整屏截图。
- 三个页面与深浅两种外观截图核对完成，回归测试与 arm64 编译通过。

## 后台形态重做

- 用户指出方向偏了：这是右键增强工具，配置窗口只是偶尔用，平时应该自启动、轻量运行。据此重新界定优化对象，真正的产品面是右键菜单和后台形态。
- 先用实测替代推测：`ps` 的 RSS 把共享库算进去，严重高估；改用 `footprint` 得到扩展 5.7 MB、主程序无窗口 17 MB、开窗 41 MB。菜单热路径实测一次完整构造稳态 0.160 ms，瓶颈不在菜单本身，而在冷进程首次图标查找的 18.269 ms。
- 关键发现来自一个对照实验：用扩展的真实 entitlements 签名探针，证明 `selectedItemURLs()` 交出的 URL 不带沙盒读取权限，**任何**应用都打不开，不只是 Terminal。此前所有打开动作转交主程序并非只为 Terminal，而是被这一条限制逼出来的，只是当时没查明原因。
- 由此确定路线：加只读例外让扩展自足，删除整套请求中转；主程序不再常驻，入口改用 Finder 工具栏按钮（由已常驻的扩展提供，零额外进程）。
- 冷启动不开窗一并修复。原先的判断（时序竞争）被日志证伪——回调根本没触发；`applicationShouldOpenUntitledFile` 是文档型 App 的回调。改用 `applicationDidFinishLaunching` 后连续 10 次冷启动全部出窗。
- 按用户决定暂时移除 Claude Code，恢复 Terminal 为预置。迁移顺序调整为"先摘除退休预置再校验"，并让未知 `kind` 宽容解码，否则老配置会整体读不出来。
- 新增 `TargetAvailabilityCache`；删除五个源文件和三个测试文件；新增 7 项测试覆盖迁移、缓存与工具栏菜单。64 项 Swift 测试与 6 项脚本测试通过。

## 首次运行验收与空状态修复

- 补做"首次运行体验"验收（此前从未真实看过这一屏）：备份真实配置、删除、让应用重建、截图。发现全新安装的首屏是"一行 Terminal"，而不是空状态——`Settings.initial` 会写入内置目标与主目录。
- 由此确认**应用页空状态无法通过界面到达**（内置目标不给"移除"按钮），但**覆盖目录页空状态是用户可达的**，而它是坏的：删光目录后整个窗口从顶边布局，侧边栏爬到红绿灯上方、区块标签被标题栏盖住、底部提示栏被挤出可视区。
- 两个假设被对照实验证伪：嵌套贪婪 frame（改成自然尺寸无效）、`.glassProminent` 触发窗口级玻璃协调（换成 `.borderedProminent` 无效）。真因是手搓空状态栈——详情列没有滚动视图时 `NavigationSplitView` 会把窗口从顶边布局。改用 `ContentUnavailableView` 后两个页面均正常。
- 顺带修掉空列表时"拖动调整顺序"这条不自洽的底部文案。配置已恢复并复核。
- 补上"恢复默认主目录"入口：删光覆盖目录后扩展不监控任何位置、菜单彻底消失，而原来只能靠文件选择器一个个加回来。空状态给次要按钮，工具栏在主目录确实缺失时才多一个房子按钮（避免对故意移除的人造成常驻噪音）。`SettingsModel.restoreDefaultDirectory()` 复用 `addDirectories` 的去重逻辑，新增 2 项测试。

## 2026-09-11

### Finder 扩展"已启用但菜单消失"

- 用户报告扩展无法使用。实测排除了一圈假设：`pluginkit` 显示 `local.oneclick.app.finder` 为 `+`（已选中）、扩展产物签名与 entitlements 完整、共享容器可读、设置文件正常、`FXSyncExtensionToolbarItemsAutomaticallyAdded` 里仍有 OneClick。没有崩溃报告，也没有 `OneClickFinder` 进程。
- 日志给出真因链：扩展在 `00:25:21` 还活着，`00:26:35` 随主程序重建而退出，此后再没起来。用户看到的是"系统设置里开关开着、Finder 里什么都没有"。**Finder 只在启动时载入一次 Finder Sync 扩展，进程退出后不会自动重启它**；对照实验证实：`pkill` 掉扩展后等 25 秒，Finder 不会把它拉起来，而 `killall Finder` 或 `pluginkit -e use` 可以。
- 第二条独立故障：`pluginkit -m -v` 里的已注册路径一直指向 `~/Library/Developer/Xcode/DerivedData/...` 的旧副本，而用户运行的是 `.build/DerivedData` 的新产物。**同一 bundle id 的第二份产物执行 `pluginkit -a` 不会顶掉先注册的那份**，所以开发脚本构建出来的扩展永远不会被加载。有效序列是 `lsregister -u` 摘掉旧宿主 app + `lsregister -f` 注册新产物 + `pluginkit -e use` 重新选举，实测可把注册路径切到 `.build` 并立刻拉起扩展，且不重启 Finder、不影响其他扩展。
- `script/build_and_run.sh` 现在按上述序列恢复扩展并校验进程确实起来（失败时给出明确提示而非静默通过）。`script/check.sh` 修掉一个真 bug：`EXIT` trap 里调用 `exit` 覆盖了已记录的构建失败状态，导致 `** BUILD FAILED **` 仍然以 0 退出——这也是本轮一开始"构建通过"假象的来源。
- 状态卡不再只报开关。新增 `ExtensionAvailability`（禁用 / 已启用 / 已启用但未运行）与 `ExtensionHeartbeat`：扩展在 `init`、`menu(for:)`、`beginObservingDirectory` 写入自己的 pid 与时间戳到共享容器，应用用 `NSRunningApplication(processIdentifier:)` 核对 bundle id。第三种状态可点按重新加载，走的是与脚本相同的 `pluginkit` 恢复路径。心跳窗口取 600 秒：Finder 只在用户交互时索要菜单，空闲进程的心跳本来就会很旧，用短窗口会把"活着但没人点"误判成故障。
- 真机验证：构建脚本输出 `Finder extension is running`；心跳文件 pid 与运行中的扩展进程一致；`pkill` 后心跳指向死进程（对应"未在运行"），`pluginkit -e use` 后新 pid 出现、三个日志环节齐全。UI 自动化被辅助功能权限拦住，右键菜单的最终确认留给用户。
