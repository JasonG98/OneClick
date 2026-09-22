> 历史记录：保留当时的实现与观察。当前操作入口以开发和发布指南为准。

# OneClick 实施记录

## 2026-09-22：更新 simplify 范围

- 按用户最新要求重写 [simplify 计划](../superpowers/plans/2026-09-22-simplify.md)：直接使用静态图标，
  删除生成链路；逐项精简九个脚本；整体重写 README 并压缩其他文档。产品代码候选后置。
- 现有资产目录含 1024 像素图标，计划原样迁入 assets；不放大 README 的 512 像素 PNG。
  图标测试文件混有公共脚本测试，删除时按保留行为迁移。本轮仅更新计划与记录，未执行删减。

## 2026-09-22：补充产品代码瘦身探索

- 按用户要求审阅 28 个生产 Swift 文件、调用点及相关测试，在
  [simplify 计划的代码候选](../superpowers/plans/2026-09-22-simplify.md)
  区分可直接清理的接口/分支、需测量的缓存指纹简化、视图整理和暂缓的兼容契约调整。
- 复核历史记录后排除直接用 repository 非空代替加载成功状态、删除合法空配置 UI、
  无条件删除旧预置迁移等误删；保持既有行为及系统适配。本轮只补文档，未修改或运行产品代码。

## 2026-09-22：simplify 目标与维护流程瘦身计划

- 用户明确优先减轻脚本、测试、文档和发布步骤的负担，保留产品功能；制定
  [simplify 计划](../superpowers/plans/2026-09-22-simplify.md)，本轮未执行代码或流程改造。
- 盘点发现 `--filter` 仍承担全部脚本测试和图标重绘；自研图标渲染器及其测试共 997 行。
  计划先分离日常/专项/全量验证并收拢文档，再评估替换渲染器；保留扩展恢复、数据归属和发布保护。
- 本轮只修改计划与本条记录；核对涉及路径、现有命令与规划接口的区别，使用文档级验证。

## 2026-09-22：精简项目级代理指令

- 根据用户提供的《Rethinking skills and prompts for GPT-6 Astra》，将根 `AGENTS.md`
  从 14,735 字节缩减为 4,297 字节（减少 70.8%），保留项目边界、入口及按任务查阅的链接。
  明确本地检查可连续执行，验证随改动范围选择；小修改无需固定的计划、全库阅读或审阅停点。
- 将进程、沙盒、共享目录、校验、菜单及别名约束迁入 `runtime-invariants.md`，将图标生成、
  渲染取舍和缓存问题迁入 `icon-pipeline.md`。保留真实故障背后的约束，移除假设性功能建议。
- 同步 CONTRIBUTING、testing 和 releasing：文档修改检查差异与链接；明确 `--filter` 只筛选
  Swift 用例；保留卸载默认只报告和完整隔离要求；生成工程的幂等性比较两次运行的结果，
  避免把工作区中合理的未提交工程修改误判为失败。
- 仓库未发现项目级 skill，未为静态知识额外创建 skill；贡献指南补充精确触发、按需读取和
  避免重复指令的维护原则。保留 Codex Run 配置及个人/插件级技能。
- 验证：`git diff --check` 通过；检查 6 份指引中的 21 个本地链接（含 6 个章节锚点）、
  Markdown 代码围栏和脚本入口。与修改前文件快照比对，文档范围外现有文件字节不变。
  本次仅改指令和文档，未运行 Swift 测试、应用构建或真实桌面操作。

## 2026-09-22：去除 Apple 开发者账号依赖

- 按用户授权选用普通共享目录：新增 `SharedDirectory`，用 `getpwuid_r` 获取真实账户 home；
  主程序与扩展共享 `~/Library/Application Support/OneClick/`。保留 schema、原子写入、通知、
  输入校验及错误文本上限。目录锁协调首次创建，归属标记供卸载核验，拒绝外来目录和符号链接。
- 删除 App Group entitlement、Info.plist 配置和签名团队检查；保留现有广泛只读例外，
  仅对新目录增加 home-relative 读写例外。旧配置采用显式迁移，不在启动时扫描受保护容器。
- Xcode 生成器、本地运行和 Release 都默认 ad hoc，旧 Local.xcconfig 不再参与构建但仍忽略且保留。
  Release 关闭调试基础 entitlement 注入；实测无 Team ID、无 get-task-allow、无 App Group。
- 新目录卸载依赖归属标记，保留旧容器的系统元数据判定和默认只报告行为；README、CONTRIBUTING、
  AGENTS、testing、releasing 同步说明无账号构建、未公证 Gatekeeper/xattr、迁移与当前发布状态。
- 测试先验证旧实现失败，再改生产代码。实测发现旧卸载测试只隔离 HOME，仍会扫描并删除本仓库
  的真实 `.build` 产品；修为临时仓库 + HOME + Applications + 系统工具全隔离，重新生成受影响产物。
- 独立审查找到 `--verify` 的原有假成功：扩展超时后仅检查主程序。新增“app 活着而 extension 不在”
  用例复现退出 0，再修为扩展失败时返回非零；扩展和主程序均存在的分支仍通过。
- 严格检查随后捕获了一次真实重建中扩展登记丢失，再次登记同一产物即可恢复。给原有等待窗口增加
  每 2 秒重申登记的有限重试，并用延迟登记替身先复现失败再验证修复；最终实际 `--verify` 返回 0。
- 完整检查通过：96 项 Swift 测试、51 项 Python 脚本测试、图标及 Shell 校验；主程序/扩展 arm64 编译。
  工程重复生成字节一致。真实 DMG 挂载后嵌套签名通过；Gatekeeper 如预期拒绝未公证应用。
- 真机证据：ad hoc Finder 扩展运行并读取一个监控根目录；相同生产源码的真实沙盒探针完成新目录读写
  和错误消费、拒绝相邻目录写入；去掉读写例外后失败。裸探针最初在沙盒初始化崩溃，完整 `.app` 修正了探针形态。
- GUI 检查因 ScreenCaptureKit `-3811` 未取得画面。没有把当前账户运行成功写成“干净账户彻底无弹窗”；
  未验证的初装、GUI、GitHub Actions 和公开 Homebrew 分发边界明确保留在 verification.md。

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

## 2026-09-12 全项目简化

- **心跳文件整套删除，存活改问进程注册表。** 这是上一节那张 600 秒窗口与 pid 复核的设计的反面：扩展自己写一份"我活着"的记录，就是在给自己造一份会过期的副本，于是必须再造两条补偿机制去识别它过期——`deinit` 还根本不会在进程被 `kill` 时执行。现在 `ExtensionLiveness.isRunning(extension:)` 直接问 `NSRunningApplication.runningApplications(withBundleIdentifier:)`，bundle id 从构建产物的 `.appex` 里读，因此判据天然是"本次构建的扩展在不在跑"。删除：`ExtensionHeartbeat`、`recordHeartbeat`/`heartbeat`/`clearHeartbeat`、`notRunningGrace`、扩展侧 3 处写入与 `deinit` 清理、`SharedEnvironment.extensionIdentifier`（同一 id 的第 3 份拷贝）、以及 3 项 grace 窗口测试。`ExtensionAvailability` 的三态与状态卡 UI 不变。
- 顺带两个可测的收益：Finder 的同步菜单回调里每右键一次少一次原子写（`.atomic` 写共享容器；量级与本仓库记过的图标冷查 18.269 ms 同一条路径上），`FinderExtensionController.reload` 的等待条件从"时间戳够新"换成"进程真的在跑"。
- **实测证据（2026-09-12 本机）**：扩展运行中，独立探针查询该 bundle id 返回 1 个进程且 `bundleURL` 为 `.build/DerivedData/.../OneClickFinder.appex`；`Bundle(url: appex)?.bundleIdentifier` 读出 `local.oneclick.app.finder`。**未做**：签名构建下的设置窗口端到端复核，仍以状态卡三态实际表现为准。
- 其余删除项：`FinderMenuBuilder` 两个无人调用的默认闭包（生产与测试都显式注入，留着等于给菜单回调留一条绕过 `TargetAvailabilityCache` 的入口）、`ApplicationResolver.icon(for:)`（随之失去唯一调用者）、`MenuActionRegistry` 不可达的 tag 溢出分支（触发需 2^63 次插入，且重置 `nextTag` 本身会让 Finder 手里的旧 tag 命中新快照）、`SettingsServices.extensionEnabled` 与 `SettingsModel.extensionEnabled`（生产代码无调用方）、`SettingsModel.homeDirectory`（只服务于 `DirectoryRow` 的手写 `~` 缩写，改用 `NSString.abbreviatingWithTildeInPath`）、`SelectionContext` 里被 `isLocalURL` 蕴含的重复 `isFileURL` 检查。
- 合并项：`SettingsModel` 的 `availableApplications` 与 `applicationIcons` 两个必须保持键集一致的平行字典合并为 `resolved`（`ResolvedApplication`），视图侧一次查询；`FinderSync.settingsDidChange` 原先 `refreshDirectories()` 与失效判断各读一次配置，改为前者的返回值交给后者；`SF Symbol` 按（名称, 已解析外观）缓存，实测单次菜单构建里 symbol 与其余部分的开销比约为 0.34 ms : 0.01 ms。
- `script/build_and_run.sh` 的扩展 bundle id 改为从**构建产物**的 Info.plist 读（原先是同一标识的第 3 份硬编码，而 `pluginkit -e use` 后面挂着 `|| true`，id 漂移只会表现为"扩展不重启"）。
- 判定为误报或超范围的：`configurationAvailable` 并非 `repository != nil` 的派生值（它表示"配置成功载入"，用来防止损坏的 `settings.json` 被默认值覆盖，测试当场抓到）、`SettingsRepository` 的退休预置表不能换成"非内置且无 `applicationURL`"这条更泛的不变量（`sampleTargets` 这类配置会被误删）、`TargetKind` 改计算属性、错误上报的双通道（`errorOccurred` 通知是 app 已在前台时唯一的送达路径）。交给 `/code-review` 的：`FinderExtensionController.reload` 相比 `script/build_and_run.sh` 缺 `lsregister -u` 那一步。
- 回归：`./script/check.sh --build` 通过，**71 项** Swift 测试、6 项发布脚本测试、arm64 编译。

## 2026-09-12 应用图标

- 用户报告"app 没有图标"。排查确认工程里根本不存在任何图标资源：没有 `.xcassets`、没有 `.icns`、`config/OneClick-Info.plist` 里没有 `CFBundleIconFile`，`generate_project.py` 里没有 `ASSETCATALOG_COMPILER_APPICON_NAME`，构建产物的 `Contents/` 下连 `Resources/` 目录都没有。即从未接入图标，而非图标损坏。
- 图标改为代码生成，与 `generate_project.py` 同样的思路：`script/generate_icon.swift` 用 CoreGraphics 画（超椭圆底板 + 指针 + 点击射线），`script/generate_assets.py` 写 `Contents.json`，`script/generate_icon.sh` 是唯一入口。重复运行零差异（两次渲染的全部文件 md5 一致），因此资源可以提交进仓库而不是不可复现的位图。
- 底板用 Apple 图标网格的超椭圆而不是 `NSBezierPath(roundedRect:)`：后者是圆角矩形，在 512/1024 上肩部差异肉眼可见。指针按系统箭头的比例以多边形写出，而不是读 `NSCursor.arrow`——它的 image 只在有运行中的 app 时才填充，会让生成器依赖 AppKit 状态。
- 过程中修掉三个真 bug，都不是"画得不好看"而是几何错误：超椭圆参数域只取半圈（`-π/2…π/2`）导致只画出右半边；指针顶点顺序不是边界游走，多边形自交成"闪电"（用排列搜索找出 6 个简单多边形，取拓扑正确的一个）；射线起点取在指针轮廓之外导致所有射线都无交点。这些无法靠读代码发现，是靠把路径单独光栅化后逐张看图定位的。
- `.icns` 改用 `iconutil` 生成：先用 `CGImageDestination` 直接编码，它**静默**只写入了 16/32 两级（其余丢档且不报错），表现是"图标看起来正常，直到大尺寸视图需要 512/1024"。`generate_icon.sh` 现在转换后逐个核对 10 个尺寸，缺任何一个即失败并退出。注意构建产物里 actool 自己产出的 `AppIcon.icns` 同样只有 4 级，这是正常的：macOS 现在通过 `Assets.car` + `CFBundleIconName` 取图。
- 验证：`./script/check.sh --build` 通过（71 项 Swift 测试、6 项发布脚本测试、arm64 编译）。构建产物内含 `AppIcon.icns` 与 `Assets.car`，`Info.plist` 的 `CFBundleIconFile`/`CFBundleIconName` 均为 `AppIcon`。用 `NSWorkspace.icon(forFile:)` 反向解析该构建产物，取回 256–2048 的多档表示（含 1024 与 2048），渲染色以蓝色为主（149733/262144 像素），确认系统取到的是本图标而非通用图标——**未做**：Dock、Finder 与设置窗口在真实桌面上的外观确认，留给用户。
- 嵌套沙箱下 `xcodebuild` 会因子进程无法 `sandbox_apply` 而报 `ObservationMacros.ObservableMacro ... malformed response`，与本次改动无关；按 AGENTS.md 追加 `--disable-sandbox` 后正常。

## 2026-09-12 图标改用 SVG + numpy 重画

- 用户指出第一版指针"没画好"，并建议换路径。复盘：问题不在画法，而在**几何靠猜且迭代太慢**。CoreGraphics 版把指针顶点手写成多边形、又叠了一层 `flippedVertically`，结果多边形自交成"闪电"；每次验证都要重渲染 10 档位图再看图，一轮几分钟。
- 改为 `script/generate_icon.py`：一份图形两个产物——可读的 `AppIcon.svg`（浏览器里直接能看能改）和资源目录用的 PNG 阶梯，两者同源不会漂移。渲染只用 numpy：画面只需"填充多边形"和"线性渐变"两个操作，于是按 3 倍超采样做 even-odd 扫描填充、再盒式滤波降采样，抗锯齿就是覆盖率本身。指针直接采用系统箭头光标的 17×23 点坐标；SVG 的 y 轴向下与之天然一致，**不再需要任何翻转变换**——上一版正是靠一层翻转去"修正"坐标，才把形状绕反。
- 构图不再手调常数：`_tip_offset()` 由图形自身包围盒反推平移量，使 mark 居中于底板；改指针大小或射线长度后居中自动成立。
- 性能：初版对每个多边形在整个画布上做边缘测试，1024 档单次 96 秒；改为只光栅化包围盒（并对齐整像素，好让盒式滤波退化成 reshape）后降到 14 秒。重复运行零差异（两次生成的全部文件 md5 一致）。
- 踩到的 numpy 形状错误**全部只在最小尺寸暴露**：包围盒先裁剪后对齐会塌成 1 像素、采样范围被缩放两次、`inside` 少乘一次超采样倍数、`plate_path()` 漏传 `size` 而恒按 1024 绘制。共同点是 1024 档看着正常、16 档才炸——不能只看最大尺寸验收。
- SVG 放在资源目录内但不被 `Contents.json` 引用，actool 会忽略未引用文件，因此不被打进 app 包。删掉三个 Swift 版本（`generate_icon.swift`、`render_icon.swift`、`generate_assets.py`）。
- 验证：`./script/check.sh --build` 通过；产物 `Contents/Resources/` 只有 `AppIcon.icns` 与 `Assets.car`（无 SVG），`CFBundleIconFile`/`CFBundleIconName` 均为 `AppIcon`；`NSWorkspace.icon(forFile:)` 取回 256–2048 多档表示且以蓝色为主（140996/262144 像素）；16/32/64/128/256/512 六档目视均可辨认为"指针 + 点击爆发"。**未做**：Dock、Finder 与设置窗口在真实桌面上的外观确认，留给用户。

## 2026-09-13 白色图形改为按设计稿描边

- 用户反馈：底板没问题，但画出来的图形不对，要求"把参考图里的白色区域提出来贴到图标上"。复盘：上一版的指针顶点是照系统光标写的，而设计稿里的指针是另一套比例；圆环、横线的半径和开口角同样是估的。**估出来的几何即使代码再干净也还是错的**，所以这次不再重画，改为从设计稿里把图形量出来。
- 提取：参考图是 1024×1024 的 RGBA PNG，底板蓝、图形近白。把每行的背景亮度拟合成一条二次曲线，用 `(亮度 - 背景) / (255 - 背景)` 反解出图形的覆盖率 alpha；该式子在抗锯齿边缘上就是覆盖率本身，实测边缘只有约 1 像素的过渡，因此不需要模糊或阈值技巧。图形包围盒之外（底板顶部那圈高光）按区域裁掉，否则会被当成图形。
- 描边：自写 marching-squares（角落采样、saddle 用格心均值消歧、按方向拼接成闭环），在 0.5 覆盖线上取亚像素轮廓，再用 Douglas-Peucker 按部件给不同容差（指针 0.35px、直条 0.25px、圆弧 1.0px）简化，共 6 个部件、约 840 个顶点，存进 `script/generate_icon_assets.json`。
- 踩到的坑：marching-squares 的交点必须落在**两个采样点连线的中点**上。先前把它放在格子边中点，闭环首尾差半像素、拼不成环，表现为"轮廓碎成一堆几点的小环"；这类错误在缩略图上看不出来，只有把交点坐标打出来才对上。另一个坑是把"格心"当成采样点，会让交点整体偏 0.5 像素，最后用一份理想的圆盘/圆环单测定位。
- 渲染：白色图形按 even-odd 填充，圆环内圈与指针上的凹口因此是真的洞（先前用"并集填充"，环会被填成实心饼）。各部件仍先并成一个 ink 掩码再上色，接缝处不会露出底板。
- 底板保持参数化不变（`inset` 0.078、指数 5、蓝色渐变），因为用户明确说底板没问题。设计稿的底板比这个小一圈（半宽 347 对 432）：若按底板比例缩放图形，图形会顶到圆角边缘，故白色图形按设计稿的绝对尺寸放置，多出来的留白由底板变大自然形成。
- 验证：与设计稿逐像素对比，图形区域平均差 3.8/255、底板区域 3.2/255；两次运行 10 个 PNG 与 SVG 的 md5 完全一致；`script/generate_icon.sh` 通过并校验了 .icns 的 10 档尺寸。`./script/check.sh --build --disable-sandbox` 在本会话仍停在既有问题（`swift-plugin-server ... sandbox_apply: Operation not permitted`，宏展开失败，与图标无关）。
- **未做**：把参考图提交进仓库。`script/generate_icon_assets.json` 是自洽的（生成器只读它），只有重新测量时才需要原图，流程见上。

## 2026-09-13 白色图形改为几何图元（弃用描边多边形）

- 用户反馈："有锯齿，你还是用 svg 去还原吧"。上一版把白色图形描成了一条多边形轮廓（840 个顶点），圆弧和圆角全是短弦拼的：缩放到浏览器里看就是多边形，边缘还带着参考图自身的抖动。
- 改为按图元还原。参考图本身是位图，所以每个图元都是**从描出来的轮廓里拟合**出来的，而不是照抄某个已知的图形库：
  - 圆环：用同一圆心拟合四条边（外环外/内、内环外/内），半径 111.66 / 92.57 / 66.90 / 48.27，圆心 (395.77, 459.38)；中径 102.12 与 57.59，线宽 19.09 与 18.63，张角 262.4°（79.5°→341.9°）与 182.5°（81.3°→263.8°）。端头是径向平切，不是圆头——放大看端点处两条边同时收口。
  - 横线：513×18 左右的圆角矩形，圆角 5（与参考图逐行剖面吻合）。
  - 指针：先按曲率把轮廓切成"直段 / 弯段"（滑动窗口测弦偏差），直段拟合直线，弯段拟合圆弧；判定出六条边 + 六个圆角。圆角改用**二次贝塞尔**（控制点=两条边的交点，端点=切点，切长按与描出点的均方误差选），因为尖角处的实际形状比圆更"扁"，圆弧拟合残差 1.6px 而二次贝塞尔 1.1px；尾部那段接近半圆的帽仍是圆弧（半径 18.13）。
- 踩到的坑（都是"看着差不多、其实错了"这一类，靠逐像素对比才发现）：
  - 角平分线没单位化，圆角圆心被推到离顶点 √3 倍远的地方；
  - SVG 弧线的 sweep 用"取短弧"来判定，对接近半圆的尾部帽子就会走错一边，得改成"这段弧是否真的覆盖描出来的点"；
  - 圆环路径把线宽又除了 2，环变成半个宽度；
  - 路径拼接时 `L` 的终点取了下一个圆角的**起点**而不是终点（起点/终点相差 12px），指针从嘴角切开。
- 验证：整块图形与参考图逐像素 IoU 0.95（指针 0.98、外环 0.92、内环 0.92，其余差异集中在参考图自身的软边）；两次运行 10 个 PNG + SVG 的 md5 一致；`.icns` 十档尺寸校验通过。
- 结构：`script/generate_icon_assets.json` 从 15KB 的轮廓点降到 1.5KB 的路径数据（6 条 path，共约 1.1KB），可以直接读、直接改。`generate_icon.py` 自己实现 SVG 的弧线「端点到圆心」换算，位图与 SVG 用同一份路径，不会各画各的。

## 2026-09-13 改用用户提供的 SVG 作为图标美术稿

- 用户否掉了此前两版自动生成的图形（描边多边形有锯齿、按图元拟合仍不满意），直接给了 `macos26_rightclick_icon.svg`，要求"用这个替换现有 APP 图标"。
- 现在的分工：`src/app/resources/Assets.xcassets/AppIcon.svg` 是唯一美术稿（人写的，1024 画布、824 圆角底板、两段蓝渐变、两条圆弧波纹、三根圆头横线、实心指针），`script/generate_icon.py` 负责把它光栅化成 10 档 PNG。删掉了 `script/generate_icon_assets.json`——那份从参考位图量出来的几何已经没有用了。
- 渲染器改成"按需实现这份 SVG 用到的子集"，而不是自己画图形：`<rect rx>`、`<path>` 的 `M L H V A Z`、`<g transform="translate()">`、纯色与纵向两段线性渐变的 `fill`、`stroke`（线宽 + 圆头/平头）。弧线仍按 SVG 规范的「端点到圆心」换算采样；遇到没实现的元素或属性直接抛错，避免悄悄画错。
- 关键取舍：**描边用"到中心线的距离 ≤ 半个线宽"来判定，而不是先把描边转成轮廓再填充**。描边形状的轮廓在内拐角处必然自交（`stroke-width` 越大越明显），此时 even-odd 会把带状区域异或掉、nonzero 又会把洞填上，任何填充规则都不对；距离判定不涉及绕数，圆头端点与圆角连接本来就是它的自然结果。
- 顺带踩到的两个坑：`<rect>` 原先按参数直接生成点，在角点处因浮点舍入产生极小的反向边，绕数在左右两侧分别多一和少一（表现为"左上角是方的、右上角是圆的"这种不对称），改为用路径数据 + 同一套弧线采样后消失；描边轮廓的圆头如果只是把两侧端点回折、不真的绕端点画半圆，会得到一个蝴蝶结形状，填充出来是空心的。
- 验证：加载后的图元包围盒（白图形 x 258.9..814.0、y 296.5..719.0）与渲染出的 PNG 逐像素测得的包围盒（x 259..813、y 297..718）一致，底板取色 `#3C91FD → #2A80F5` 与 SVG 完全一致；两次运行 10 个 PNG 的 md5 相同；`./script/generate_icon.sh` 通过并校验 .icns 十档尺寸。

## 2026-09-13 修掉"重新构建后图标还是旧的"

- 现象：换了美术稿、也重新生成了 PNG，但 `./script/build_and_run.sh` 之后看到的仍是旧图标。查下来**不是构建没生效**：构建产物 `.build/DerivedData/.../OneClick.app/Contents/Resources/Assets.car` 里的 1024 档、以及 macOS 实际解析出的图标（`NSWorkspace.icon(forFile:)` 取回 1024 表示再比对底板半径与取色）都已经是新美术稿。问题出在**图标走的是 LaunchServices 注册记录**。
- 根因有两个，叠在一起：
  1. **同一个 bundle id 有多份注册**。这台机器上 `local.oneclick.app` 同时注册了 `.build/DerivedData`（刚构建的）、`.build/Checks`（`check.sh --build` 的产物，美术稿是旧的）、`.build/ReleaseVerification`（归档中间产物）以及 Xcode 自己的 DerivedData。图标解析会在这些记录里挑一个，挑中旧的旧显示旧图。
  2. **Icon Services 按 bundle id + 版本号缓存**，而本项目的版本号从不变（一直 1.0），所以即使重新构建、资源换了，缓存里的旧图标也可能继续命中。
- 修法写在 `script/build_and_run.sh` 里，紧挨着原有的"清理过期扩展注册"逻辑：
  - `oneclick_registered_app_paths`：从 `lsregister -dump` 里取出该 bundle id 当前注册的所有路径（bundle id 从构建产物的 Info.plist 读，不写死）；
  - `oneclick_retire_stale_app_registrations`：把**本项目 `.build/` 目录下**的其它注册逐个 `lsregister -u` 摘掉（只摘注册，不动文件；再次构建或打开会重新注册）。仓库外的副本——比如 `/Applications` 里真正安装的那份——不碰；
  - 注册完这一份后 `touch` 应用包，让 Icon Services 的缓存条目失效，由这份构建补上。
- 验证：手工造出"旧副本在后注册"的局面并确认图标会解析成新图；再跑一遍脚本的新逻辑，看到 `Retiring stale app registration: .../.build/Checks/.../OneClick.app`，之后连续探测都解析到新美术稿（底板半径 411.5，取色 `#3C91FD → #2A80F5`）。`./script/check.sh`（Swift 测试 + 发布脚本测试）通过，`./script/build_and_run.sh --build-only` 通过。
- 如果 Dock 上仍有旧图标：那是 Dock 自己的图块缓存，`killall Dock` 重启一次即可；脚本不去动用户的 Dock。

## 2026-09-13 底板找回"质感"（渐变 + 顶部柔光）

- 用户反馈：换了美术稿之后底色是平涂，不好看，希望回到之前带一点质感的背景。原因是那份 SVG 的两个色标 `#3C91FD → #2A80F5` 太接近，纵向渐变基本看不出来。
- 只改底板的绘制，图形与底板几何（824 圆角方形、rx 190）一律不动：`bg` 扩成三段渐变 `#4A90FF → #1F73E8 (55%) → #0058D0`，上面再叠一层同形状的 `sheen`——白色 30% 到底部淡出，也就是早先那版"抛光面"的做法。
- 渲染器相应扩了两个能力，都按 SVG 语义实现：
  - **多段渐变**：色标可以是任意多个，不再限制两段；渐变沿 y 按元素自身包围盒（`objectBoundingBox`）取值，横向渐变直接报错；
  - **`stop-opacity` 与预乘合成**：图元按"预乘 alpha 的 source-over"合成。半透明柔光只应把底色洗亮，不能把图标自身的 alpha 冲淡——先前按 `coverage` 直接更新 alpha 会让底板顶部变得半透明（预览里看就是发白）。
- 顺带修掉一个自己引入的错：重写 render 时漏了最后一处 `/255.0`，函数对外承诺 [0,1] 却返回 0–255，写 PNG 时被裁到 255，整张图变成白板；而直接调用 render 打印数值看着"像"对的蓝（其实是 0–255 的那组数），所以更该用"写出去再读回来"来验证，而不是只看内存里的数。
- 验证：底板纵向取色 119,171,253（顶部，柔光后）→ 4,91,211（底部），圆角外 alpha=0；`./script/generate_icon.sh` 通过并校验 .icns 十档；两次运行 10 个 PNG 的 md5 相同；128 档目视仍有干净边缘。本机 `./script/build_and_run.sh --build-only` 仍卡在既有的沙箱宏展开问题（`swift-plugin-server ... sandbox_apply`），与图标无关。

## 2026-09-13 美术稿提到 assets/，README 与 app 共用一份

- 起因：README 顶部要放图标，而美术稿原本塞在 `src/app/resources/Assets.xcassets/AppIcon.svg` —— 那是资源目录内部，只有编译器看得见，README 只能去引用一个"编译输入"的 PNG（`icon_128x128@2x.png`）。既然一份图要供两处用，就该放在两处都能自然引用的地方。
- 做法：美术稿移到顶层 **`assets/icon.svg`**；`script/generate_icon.py` 仍负责光栅化，但产物变成三份 —— 资源目录的 16–1024 PNG 阶梯、README 内嵌的 `assets/icon.png`（512）、以及 `generate_icon.sh` 另外产出的 `.icns`。三者与美术稿同源，不会各自漂移。
- 顺带去掉一个隐藏约定：以前 SVG 放在资源目录里、靠"不被 `Contents.json` 引用所以 actool 会忽略"来避免被打进 app 包。现在它根本不在资源目录里，这条需要靠注释解释的规则不用再存在了。
- 同步更新 `README.md`（顶部图标、工程结构表、图标小节）与 `AGENTS.md` 的图标约定。
- 验证：移动前后 `icon_512x512@2x.png` 的 sha256 不变（`144667d1…`），说明这次只改路径、没改画面；两次运行 10 档 PNG + `assets/icon.png` 的 md5 一致；`./script/generate_icon.sh` 通过并校验 .icns 十档；`tests/release-scripts/run_tests.sh`（6 项）与全部 shell 语法检查通过。
- 备注：`./script/check.sh` 里的 SwiftPM 测试在本会话被既有的沙箱宏展开问题挡住（`swift-plugin-server ... sandbox_apply: Operation not permitted`），与本次改动无关，同一天早些时候同一命令是通过的。

## 2026-09-13 README 与 AGENTS.md 分工重整

- 用户指出：README 里混进了不少"给 agent 看"的内容，应该挪到 AGENTS.md。确实如此 —— 前一轮重构把工程约定、测试分层、图标实现细节都写进了 README，那是把维护者文档塞进了用户门面。
- 重新划线：**README 只回答用户的问题** —— 这是什么、为什么要装、怎么装怎么用、为什么需要那条权限、常见疑问、发布状态、许可证，外加一张"它是怎么工作的"高层架构图。**AGENTS.md 接管所有维护者信息**，新增四节：
  - *Documentation map*：哪类内容写进哪个文件（README / AGENTS / implementation-log / testing / verification / releasing）；
  - *Tests*：三层测试的职责，以及"不得启动目标应用、不写系统剪贴板、不碰真实 App Group"的硬约束；
  - *Icon pipeline*：美术稿 `assets/icon.svg` 是唯一来源（README 与 app 共用），渲染器只实现美术稿用到的 SVG 子集且遇到别的构造直接报错，描边为什么按"到中心线距离"而不是转轮廓；
  - *Runtime invariants*：扩展干活为主、只读沙盒例外不可删、Finder 只加载一次扩展、App Group 需要真实团队签名、菜单是快照式的 —— 这几条改动前必须是有意识的决定；再加一节 *Gotchas*（bundle id 的过期注册会让重建后仍显示旧图标、沙箱里的宏展开报错属于环境问题）。
- 具体删除：README 里的工程结构树、约定表、`generate_project.py` 确定性说明、测试分层段落、图标渲染器内部细节（弧线端点换算、预乘合成、3 倍超采样）、entitlements 的 XML 片段与"移除它会怎样"。这些要么已在 AGENTS.md，要么已在本日志里。
- 验证：README 全部相对链接与跨文件锚点逐一核对（`AGENTS.md#runtime-invariants` 对应 AGENTS.md 的 `## Runtime invariants`）；顺手修掉一个改标题后失效的页内锚点（`#沙盒授权为什么需要一条只读例外` → `#关于那条权限`）。

## 2026-09-13 "关于"页的图形改用应用图标本身

- 关于页原来画的是一个 SF Symbol（`cursorarrow.click.2`）放在 80×80 的 `panelSurface` 卡片里 —— 那是图标还是手绘阶段留下的占位图。换成应用自己的图标：`Image(nsImage: NSApplication.shared.applicationIconImage)`，96×96、`.resizable()` + `.interpolation(.high)`。
- 两个决定：
  - **不再套 `panelSurface`**：美术稿本身就是一个带高光的圆角方形，再套一层卡片等于给它加双重边框；系统自带的"关于"面板也是直接铺图标。
  - **从运行中的应用取图标**，而不是在视图里重画一份或者再塞一张图片资源：关于页显示的必然就是 Dock 与 Finder 里那个图标，将来换美术稿只要重新生成资源即可，这里不需要跟着改。文件头补了 `import AppKit`。
- 关于页其余部分（标题、副标题、版本文案）未动；菜单与 Finder 工具栏仍用 SF Symbol —— 那是模板图标，彩色应用图标放进菜单并不合适。
- 验证：`swiftc -parse` 通过；访问 `NSApplication.shared` 的隔离性是安全的，因为 `SettingsView` 由 `View` 协议的 `@MainActor` 推断为整型 MainActor 隔离 —— 同一类型里的 `badge(for:)` 已经在非 body 成员里直接读 `@MainActor` 的 `SettingsModel`，是既有且可编译的先例。**本机仍无法整包编译**（沙箱挡住 `swift-plugin-server` 的宏展开，`SettingsView.swift:5` 的 `@Bindable` 报错是 `SettingsModel` 宏没展开的连带结果），需要在你自己的终端里构建确认。

## 2026-09-13 整理 script/：删掉死入口、合并重复、修正与实现不符的说明

- 起因：`script/` 攒到 8 个文件，职责和重复都失控 —— 5 个脚本各自抄一份仓库根定位，`fail`/版本校验在 `release.sh` 与 `generate_cask.sh` 各写一份，`check.sh` 里内联调用只有 7 行的 `test.sh`。
- **哪个图标脚本在用**（用户要求先查清）：`assets/icon.svg` 有两条真实消费路径 —— ① PNG 阶梯喂给 actool，编译进 `Contents/Resources/Assets.car` 与 `AppIcon.icns`（因为 target 设了 `ASSETCATALOG_COMPILER_APPICON_NAME=AppIcon`）；② README 顶部内嵌 `assets/icon.png`。而 `generate_icon.sh` 唯一产物 `.build/OneClick.icns` **全仓库没有消费者**：`config/OneClick-Info.plist` 没有 `CFBundleIconFile`，`release.sh` 不打包它，README 从未提过它。app 的 `.icns` 是 actool 自己从 PNG 阶梯生成的。于是删掉该脚本，它真正有价值的那部分（十档尺寸校验）并入 `generate_icon.py --icns`。
- 删除：`script/generate_icon.sh`（无消费者的产物）、`script/test.sh`（并入 `check.sh`，它只多做「建缓存目录 + 包一层 swift test」）。8 个文件变 6 个。
- 新增 `script/lib.sh`（只被 source）：`oneclick_root`、`oneclick_fail`/`oneclick_fail_usage`、`oneclick_require_env`、`oneclick_is_version`。踩到的坑：`oneclick_fail` 若用 `${BASH_SOURCE[1]}` 取调用者名，从 `oneclick_require_env` 里报错会变成 `lib.sh: ...` —— 调用栈上一帧就是 lib.sh。改为沿 `BASH_SOURCE` 上溯到第一个不是 lib.sh 的文件。另一处：缺环境变量必须退出 **2**（调用方式错）而不是 1，这是原有契约，`release.sh`/`generate_cask.sh` 的测试都在断言它。
- `check.sh` 成为唯一测试入口：`--build`/`--icons` 之外的所有参数原样透传给 `swift test`，所以 `./script/check.sh --filter FinderMenuTests` 照旧可用；并修掉一个真 bug —— 它不先 `cd` 到仓库根就调用 `tests/release-scripts/run_tests.sh`，从别的目录调用会失败。保留 `ONECLICK_EXIT_STATUS` + trap 模式（trap 里调 `exit` 会覆盖构建失败状态那个坑）与 `-10814` 特判。
- `generate_icon.py`：新增 `--check`（重新渲染并与已提交文件逐字节比对，不写任何文件）与 `--icns PATH`（组装 .icns 后读回校验十档，用 `tempfile.TemporaryDirectory()` 取代原来从不清理的裸 `mktemp -d`）；`Contents.json` 改由脚本生成（原先由已删除的 `generate_assets.py` 手工维护，改 `SLOTS` 不同步就会出现"PNG 写了但 actool 不引用"）；PNG 编码的扫描线改用 numpy 拼装（逐行 `raw.extend` 的 Python 循环去掉）；两处与实现不符的注释订正（模块 docstring 说描边"转成轮廓"，实现其实按"到中心线距离"；`stroke_coverage` 注释说"按当前最小值剪枝候选段"，代码里没有这个剪枝）。
- **性能：试了向量化，测出来更慢，已回退。** 把逐边循环改成对 `(边, 行, 列)` 稠密数组做一次 numpy 归约（分批版也一样），底板单个图元在 1024 档从 3.6 秒变成 6.0 秒 —— 底板环有 797 个顶点，批量会把每条边对所有采样点的乘积全部实体化，内存流量比省下的 Python 还贵。逐边形式每次只碰一个 `(行, 列)` 数组，反而留在缓存里。结论写进 AGENTS.md，避免以后有人再"顺手优化"一遍。最终 `generate_icon.py` 从 16.8 秒降到 12.7 秒，全部来自去掉 Python 层循环，画面零变化。
- `generate_project.py`：补上 `ASSETCATALOG_COMPILER_APPICON_NAME="AppIcon"` —— 这一行此前只在工作区里，生成器的输出**不能**复现工作区的 pbxproj，也就是"重复运行应零差异"这条自查当时是失败的。现在跑完 `git diff OneClick.xcodeproj` 为空。
- `build_and_run.sh`：删掉未使用的 `--debug`（`exec lldb -n OneClick`，README/AGENTS/docs 全无引用，只有历史 plan 文档提过一次）；usage 补上此前完全没提的 `--build-only`。扩展重注册序列与 `--verify` 的精确路径比对**未动**（AGENTS.md 列为运行时不变式）。
- `release.sh`/`generate_cask.sh`：共用 `lib.sh`；`generate_cask.sh` 的 `ARCHIVE_PATH` 变为可省略，默认取 `ONECLICK_DIST_DIR`（默认 `dist/`）下的 `OneClick-<version>.zip`，即 `release.sh` 的产出。
- 测试：`tests/release-scripts/test_generate_icon.py` 新增 24 项（`Contents.json` 逐字节与跟随 `SLOTS`、PNG 容器与编码、已提交 16/32 档与美术稿逐字节一致、SVG 拒绝路径、even-odd 打洞、描边带状、`lib.sh` 契约含退出码与调用者归属）；`test_release_scripts.py` 从 6 项增到 10 项（Cask 默认归档路径、缺归档的提示、参数个数退出码、release.sh 的 1/2 退出码分界）。
- 验证：`./script/check.sh --disable-sandbox` 通过 —— 71 项 Swift 测试、34 项脚本测试、图标产出校对、全部 shell 语法检查。改动前后对 10 档 PNG + `assets/icon.png` + `Contents.json` 做 sha256 逐个核对，12 个文件全部一致；`--icns` 产出的 .icns 与原 `generate_icon.sh` 的产物 sha256 相同（`cffd5a96…`），读回十档与原脚本产物逐档一致；`generate_icon.py` 两次运行零差异。`./script/build_and_run.sh --build-only` 未在本次运行（本机 `swift-plugin-server ... sandbox_apply` 属已知环境限制）。
- 文档同步：README、AGENTS.md（脚本约定、测试入口、图标管线，含"逐边是有意为之"的性能结论）、docs/testing.md（命令与 `IconPipeline` 覆盖行）、docs/releasing.md（Cask 默认路径与退出码）。本文件此前 111/126 行把 `script/generate_icon_assets.json` 写成仍在使用，那份文件早已删除，以本条为准。

## 2026-09-13 关掉配置窗口即退出

- 起因：用户以用户视角审阅并明确要求 ——「关闭窗口就是退出」。原实现 `applicationShouldTerminateAfterLastWindowClosed` 返回 `false`，关掉窗口后主程序留在 Dock 里，只留下一个用户已经关掉的窗口背后的进程和图标。
- 改动只有一处语义反转：该方法改为返回 `true`。行为上其余一切不变 —— 动作全部在 Finder 扩展进程内完成，退出主程序不影响右键菜单。
- 先确认没有东西依赖主程序存活：`SettingsModel` 每次改动（开关/排序/增删应用与目录）都立刻 `save()`，不存在"关窗时才落盘"的等待；重开路径是启动 App 本身，扩展在「OneClick 设置…」里按 bundle id 唤醒主程序，也与主程序是否存活无关。因此这条改动不引入任何持久化或唤醒上的损失。
- 测试同步：`AppLifecycleTests` 的 `closingSettingsDoesNotTerminateBackgroundProcessing` 改名 `closingSettingsQuitsInsteadOfLingering` 并反转断言 —— 原测试名在描述上就是反的（"不退出"却叫"不终止后台处理"），现在锁住的是产品决定。
- 文档同步：README（卖点行改为「关掉窗口就是退出（Dock 图标一起消失）」；用法一节新增一条说明"退出主程序不影响右键菜单，重新打开即恢复配置"）、docs/testing.md 的 `AppLifecycleTests` 覆盖行。
- 验证：`xcrun swiftc -parse` 对 `AppDelegate.swift` 与 `AppLifecycleTests.swift` 均通过（exit 0）。**本机无法整包编译**（既有环境限制：`swift-plugin-server ... sandbox_apply: Operation not permitted` 导致 29 处 `ObservationMacros.ObservableMacro` 展开失败，与本次改动无关），因此"关窗即退出"这一条属于**代码与测试已改、真机行为待用户在终端构建后确认**。

## 2026-09-13 长名应用改用别名（右键菜单文案）

- 起因：用户反馈"又一些常用的应用名字太长了"，例如 `用 Visual Studio Code 打开`；要求给常用应用加别名，并且**后期便于扩展**。
- 先问清两件读代码决定不了的事：① 别名来源 —— 用户选**内置别名表**（不做设置窗口里的改名 UI）；② 设置列表是否体现别名 —— 用户选**设置列表不动**。方案因此收敛为"纯派生的别名表，只影响右键菜单文案"。
- 实现三处：
  - 新增 `src/shared/core/ApplicationAlias.swift`：`Entry(bundleIdentifier, applicationName, shortName)` 数组，按 bundle id 用 `first(where:)` 查。`applicationName` 表明这一条是谁，同时是"短名必须更短"这条断言的依据（不参与匹配）。
  - `OpenTarget.menuName` = `ApplicationAlias.shortName(forBundleIdentifier:) ?? name`。做成计算属性而不是在菜单构造里就地拼字符串：将来若要用户自定义显示名，只在 `??` 前插一个字段，其余代码不动。
  - `FinderMenuBuilder` 的两处文案（内联 `用 … 打开` 与折叠子菜单项）改印 `menuName`。`ActionExecutor` 的报错、`ApplicationRow` 的标题与开关无障碍标签**故意不动** —— 那里要的是应用身份，得和 `/Applications` 里的名字对得上。
- **别名不进配置**：没有 `OpenTarget.alias`、没有 schema 变更、没有迁移、`Settings.version` 仍是 1，加一条别名不需要碰任何人的配置。测试 `aliasesAreNeverPersisted` 钉住这条：编码后的 JSON 里不出现短名，解码回来 `name` 仍是全名。
- 表里的 bundle id 是**核出来的，不是想出来的**：`com.microsoft.VSCode`、`com.sublimetext.4` 用 `/usr/libexec/PlistBuddy` 从本机已装应用读出；`com.microsoft.VSCodeInsiders`、`com.jetbrains.intellij`、`com.jetbrains.intellij.ce` 本机没装，用 Homebrew Cask 清单核对（`uninstall quit:` 与 `zap` 路径里写着真实 bundle id）。核不到就不收录 —— 规则写进 AGENTS.md。
  - 弯路：先试 `lsregister -dump` 与 Spotlight（`mdfind kMDItemCFBundleIdentifier`）找那三条 id，本机都查不到。这两个来源只覆盖"这台机器装过的东西"，核**未安装**应用的 id 只能走发行渠道文档。
- 表自身的规矩用测试表达（`aliasTableEntriesAreWellFormed`）：bundle id 唯一、含 `.`、三段非空且首尾无空格、**`shortName` 严格短于 `applicationName`**、短名 ≤ 16 字符。"加一行"因此有检查清单，"别名比原名还长"这类自欺会在测试里被挡住。
- 菜单测试改成**字面量**断言（`["用 VS Code 打开", "用 Cursor 打开", "用 Sublime 打开"]`）：用 `targets.map(\.menuName)` 算期望值等于拿被测代码测被测代码。副作用是有意保留的 —— 以后加别名导致文案变化时这些断言会失败，逼着改的人同步更新文案测试。
- 新增 `aliasesApplyToFoldedItemsToo`：别名排到第 4 位（折叠进「用其他应用打开」）时也是短名，并且 `MenuActionRegistry` 里点中的仍是那个全名目标 —— 换文案不能换快照。
- 量化（生产代码建菜单 + 菜单字体量宽，harness 只建菜单、不 `popUp`、不截图）：**该量法复现了 docs/verification.md 里 160.5 pt 的历史基线**，数字可比。`用 Visual Studio Code 打开` 160.5 pt → `用 VS Code 打开` 98.3 pt；`用 Sublime Text 打开` 123.4 → 94.4；折叠项 `IntelliJ IDEA` 72.0 → 39.3；表里没有的 `Terminal`/`Cursor` 宽度一模一样（对照组，证明没有引入通用缩写规则）。明细进 docs/verification.md。
- 文档同步：README（用法一节补一句短名）、AGENTS.md（新增 “Menu wording and application aliases” 一节：菜单印 `menuName`、`name` 是身份、加一行即可扩展、id 必须核）、docs/testing.md（CoreTests 与 FinderMenuTests 两行覆盖范围）。
- 验证：见下方"本次验证结果"。
- 验证结果：`./script/check.sh --disable-sandbox` 通过 —— **76 项 Swift 测试**（8 个套件；改动前 71 项，新增 4 项别名表测试 + 1 项折叠项文案测试）、34 项脚本测试、图标产出校对、全部 shell 语法检查。
- `./script/check.sh --disable-sandbox --build`：**Finder 扩展 `OneClickFinder.appex` 编译并链接成功**，两个 target 都重新编出了 `ApplicationAlias.o`（对象文件时间戳晚于源文件，确认不是用了旧产物）；主程序 target 只在 `SettingsModel.swift` 的 `@Observable` 宏上报错 —— 即 AGENTS.md 记的环境限制（Xcode 的 `swift-plugin-server ... produced malformed response`，本会话的文件沙箱下起不来），该文件本次未改，同一份源码在 SwiftPM 路径下（`swift test --disable-sandbox`）编译通过。所以"主程序整包编译"这一条仍受环境限制，本次未确认。
- 真机确认（Finder 右键里实际显示 `用 VS Code 打开`）待用户点一次右键 —— 属 docs/testing.md 列为"仍未自动化"的边界。

## 2026-09-13 复制项改叫「复制路径」

- 用户要求：**应用里**两处都显示「复制路径」，**文档里仍然注明是绝对路径**。这是纯文案改动 —— 动作、剪贴板内容、`SelectionContext.pathText` 一律不动。
- 改动三处 UI 文案：`FinderMenuBuilder` 的菜单项（`复制绝对路径` → `复制路径`，多选 `复制 N 个绝对路径` → `复制 N 个路径`）与 `FinderSync.toolbarItemToolTip`。搜过 `src/` 下所有出现「复制」「绝对路径」的地方，用户可见的只有这两处；`SettingsRepository` 里几条"必须是本地绝对路径"的校验提示属于监控目录，与本次无关，保留。
- 先量后改（同一套生产代码 harness）：`复制绝对路径` 77.4 pt → `复制路径` **51.6 pt**，多选 105.2 → 79.4 pt。
- **文档不改语义**：README 用法一节的引号内文字改成「复制路径」，同时补上"复制到剪贴板的是绝对路径，多选时每行一个"；顶部一句话（"或复制绝对路径"）描述的是行为，保持原样。`docs/superpowers/specs/` 里那张表本来就写的「复制路径」，无需改。
- 历史记录不回溯：`docs/verification.md`（含新加的别名一节里引用的旧标题）、`docs/implementation-log.md` 与 `docs/superpowers/plans/` 里出现旧文案的段落是当时的记录，按本仓库惯例保留原文；本次新增的验收小节写清了"改的是哪三个位置、行为未变"。
- 测试同步：`FinderMenuTests` 的 5 处断言（含多选标题）改成 `复制路径` / `复制 2 个路径`。
- 验证：`./script/check.sh --disable-sandbox --filter FinderMenuTests` 10 项通过；全量 `./script/check.sh --disable-sandbox` 通过。
- `--build`：扩展的 `OneClickFinder.debug.dylib` 重新链接，按 UTF-8 字节在产物里核对 —— `复制路径` 命中、`复制绝对路径` 零命中（中文串用 `strings` 查不到，要用 `LC_ALL=C grep -a $'\xe5…'` 按字节找，这一步走了弯路）。扩展 stub 的 `Ld` 报错且没有错误正文，是主程序 target 宏失败（既有环境限制）**连带**终止同批任务所致：把日志里那条 `Ld` 命令原样重跑退出 0。

## 2026-09-13 质量清理（`/simplify`，按 reuse / simplification / efficiency / altitude 四个角度并行审查）

- **主要项：`generate_icon.py --check` 把整条图标阶梯渲染了两遍。** `main` 先按像素数渲染进 `cache`，随后 `check_targets` 丢掉它、从头再渲染一遍；`--icns` 也是同一份重复。现在是一份 `image(pixels)` memo（按像素数缓存渲染结果），写文件、`--check`、`--icns` 三条路径共用。**实测 32.5s → 14.5s**（`--icns` 26.2s → 14.4s）；`./script/check.sh` 每次都会跑这一步，所以这是常驻开销。SLOTS 里 32/256/512 本来就各出现两次、512 还有 README 预览这第三次。
- 其余合并/删除：`write_png`（两行包装，docstring 却在描述它并不调用的 `encode_png`）；`render(source:)` 与 `SLOTS` 旁的 `ARC_STEP` 参数（无人传值，viewBox 已锁死 1024，改成 `SOURCE_SIZE` 常量）；`SLOTS` 的注释原本和 `ARC_STEP` 挤在同一行，导致 `SLOTS` 没有注释；`SettingsModel.refresh` 对同一个 key 查两次并重复构造 `ResolvedApplication`，改为一次 `if let previous`；`release.sh` 的两条 usage 消息合成一条并走 `oneclick_fail_usage`（原先手写 `release.sh:` 前缀，与 lib.sh 的归因机制重复）；`check.sh --icons` 不再重复写死 `.build/OneClick.icns`（`--icns` 的默认值就是它）；测试侧：`ApplicationAliasTests` 的两份逐字相同的 `OpenTarget` 字面量提成一个常量，`test_generate_icon.py` 的 `write_svg` 增加 `view_box` 参数、`run_probe` 改为转调 `run_script`（两者原本是同一段 `subprocess.run` 写了两遍）。
- **`lib.sh` 里一句注释是错的**：`oneclick_caller` 已经会跳过调用栈上所有 lib.sh 的帧，所以"脚本想让自己出现在报错里就得自带一行 `fail()` 包装"这个理由不成立（包装留着只是因为调用处更短）。
- 判定为误报或超范围的：删掉 `--icns` 整套（它验证的是自己存在的前提，但这是用户明确要求保留的能力）；`contents_json()` 改 `json.dumps`（会改已提交的 `Contents.json` 字节，是给 actool 吃的）；`ExtensionLiveness` 把 bundle id 提取成一个访问器（轮询里重复 `Bundle(url:)` 实测整个 8 秒等待只值约 4ms）；`build_and_run.sh` 的 `lsregister -dump`（实测 4s / 21.7MB，但它能看见文件已不存在的注册，正是要清理的那一类）；`check.sh` 的四步串行改并行（输出会交错）；`FinderMenuTests` 折叠项测试改用 `sampleTargets` 派生（显式字面量正是那条测试的用意）。
- 验证：`./script/check.sh` 通过（**76 项** Swift 测试、34 项脚本测试、图标产出校对、shell 语法检查，exit 0）；`./script/check.sh --icons` 通过；重新运行生成器后 `git diff` 对 10 档 PNG + `assets/icon.png` + `Contents.json` 为空；`--icns` 产物 sha256 仍是 `cffd5a96…`，与上一节记录的原始脚本产物一致。
- 本机 `swift test` 这次未出现 AGENTS.md 记录的 `swift-plugin-server ... sandbox_apply` 宏展开失败，因此 76 项在无 `--disable-sandbox` 的情况下直接跑过。

## 2026-09-13 新增完全卸载脚本

- 起因：用户审阅上一轮的卸载说明后要求把它做成脚本。此前那套步骤是让人手抄 `rm -rf`，既容易漏（App Group 容器名带 Team ID 前缀，换团队就多一个）也容易多删（本机 `group.jay.OneClick` 就是另一个项目留下的同名容器）。
- 新增 `script/uninstall.sh`。**默认只报告、不删除**，`--apply` 才动手 —— 卸载不可逆，值得让人先读一遍再执行，也让脚本能安全地在任何机器上先跑一次看看。`--build`（`.build/`、`dist/`）与 `--local-config`（`config/Local.xcconfig`）是显式开关，默认不碰仓库内容。
- 顺序是硬约束，写进了脚本头注释：①停进程 → ②撤销注册 → ③删 bundle → ④删数据。数据先删会让注册指向不存在的路径（LaunchServices 会留下陈旧记录），进程最后停会留下一个"二进制已不在磁盘上"的活进程。
- **归属判定不靠名字**：App Group 容器读 `MCMMetadataCreator`（容器管理器自己写的），app bundle 读 `CFBundleIdentifier`。实测对照：`group.local.oneclick.shared`（creator 同为 `local.oneclick.app`）判为本应用，而 `group.jay.OneClick`（creator 为 `com.jay.OneClick`）被跳过 —— 后者名字里同样含 "oneclick"，只按名字匹配必然误删。
- 真实 dry run 纠正了两个此前说明里的遗漏：Xcode 自己的 `~/Library/Developer/Xcode/DerivedData/OneClick-*/` 里还有一份被 LaunchServices 注册的副本，`.build/Checks/` 也留了一份。因此改为"从 LaunchServices 注册反查所有副本"，而不是只查两个安装目录。
- 测试：新增 `tests/release-scripts/test_uninstall_script.py`（7 项），全部在临时 HOME 下通过注入的假 `lsregister`/`pluginkit`/`pgrep`/`pkill` 运行，**不触碰本机任何真实数据**。覆盖：报告模式零变更、`--apply` 删净自己的数据、名字像但归属不符的容器必须留下、注册撤销确实发生、可重复执行（第二次 "Removed 0 item(s)"）、`--build` 为显式开关、缺 `HOME` 退出 1、未知参数退出 2。
- 一处自查被测试纠正：最初断言"报告模式不执行任何命令"，实测失败 —— 报告确实会跑 `lsregister -dump` 与 `pgrep`（它靠这两个发现副本与进程）。断言改为"不得出现任何**改状态**的命令"（`pkill`、非 `-dump` 的 `lsregister`、`pluginkit -e`），这才是要保的性质。
- 文档同步：README 新增「完全卸载」（含"先关扩展再卸载"这条脚本无法代劳的必要步骤）、`docs/testing.md` 增加 `UninstallScript` 覆盖行、AGENTS.md 记明该脚本是唯一会删除仓库外内容的入口且默认必须保持只报告。
- 验证：`tests/release-scripts/run_tests.sh` 41 项通过（原 34 + 新 7）、`script/*.sh` 与 `tests/release-scripts/*.sh` 全部 `bash -n` 通过、图标产出校对通过。

## 2026-09-13 清理早期 demo 留下的容器

- 起因：用户问 `group.jay.OneClick` / `com.jay.ok` 是什么。查明二者分别是**本项目 2026-02 那版**（bundle id `com.jay.OneClick`，旧工程路径 `OneClick/OneClick.xcodeproj`）和一个独立小 demo（`com.jay.ok`，SwiftUI 单窗口）的 bundle id / App Group id。旧 App 本体已被用户丢进废纸篓（现已不在），残留只有容器与桌面域。
- 清掉：`~/Library/Group Containers/group.jay.OneClick`（creator 实测为 `com.jay.OneClick`）、`~/Library/Application Scripts/{com.jay.ok,com.jay.OneClick,group.jay.OneClick}`（三个都是空目录），以及两个 app 容器里的 `Data/`。**`tests/release-scripts/test_uninstall_script.py` 里的 `FOREIGN_CREATOR = "com.jay.OneClick"` 是字符串常量，不依赖这些容器存在，测试不受影响。**
- **踩到的硬约束：`~/Library/Containers/<bundle-id>` 的 metadata.plist 删不掉。** `Data/` 删净后只剩 `.com.apple.containermanagerd.metadata.plist`，`rm -f`、`rmdir`、`chmod -N` 一律 `Operation not permitted`（文件无 flags、无异常权限位）；脚本化 Finder 的 `delete` 报 -10004，连 `reveal`/`selection` 也报 -10004。原因是该目录受 TCC 保护，而当前进程没有「完全磁盘访问」（探针：读 `~/Library/Application Support/com.apple.TCC/` 也是 `Operation not permitted`；`sudo` 在本会话沙箱内同样不可用）。**这与 `script/uninstall.sh` 删自己容器的能力不矛盾** —— 实测 `group.*` 容器删得掉，卡住的只有 `Containers/` 下 app 容器的那份 metadata，结论是"删别的 App 的容器外壳"这件事本身需要完全磁盘访问。
- 被 TCC 锁住的两个外壳由用户在 Finder 里手动删除（`~/Library` 是隐藏目录，⌘⇧G 粘路径最省事），已确认清空。**不要用 `script/uninstall.sh` 干这件事**：它按 creator 判定归属，`com.jay.OneClick` 正是它要跳过的"别人的容器"（那是测试样本，不是缺陷）。
- 全盘复查（7 项全空）：容器 / 组容器 / Application Scripts、`defaults domains`、`~/Library/Preferences` 下的 plist、Caches / HTTPStorages / Saved Application State / Logs、废纸篓、Spotlight 里两个 bundle id 的 App；当前版本的 5 个容器与共享容器原样保留。
- 未动：当前版本的 `~/Library/Containers/local.oneclick.*`、`~/Library/Group Containers/<Team ID>.local.oneclick.shared`、`group.local.oneclick.shared` 全部原样；仓库代码与测试零改动（本次只改本文件）。
- 说明：`defaults domains` 里的 `com.jay.OneClick` / `com.jay.ok` 已消失，因为域来源是容器内那份 plist，随 `Data/` 一起没了 —— 用户级 `~/Library/Preferences/` 下从始至终没有这两个文件，无需额外 `defaults delete`。

## 2026-09-13 密钥扫描与六项安全加固

- 起因：用户要求检查仓库里有没有密钥、密码之类的隐私进了 git。扫描覆盖全部 5 个提交与 86 个被跟踪文件：无密钥格式命中（AWS/GitHub/OpenAI/Slack/Google/PEM 头）、无凭据硬编码、无敏感文件入库；`config/Local.xcconfig` 从未被提交。命中的关键词全是假阳性——URL 校验里的 `url.password == nil`、测试用的假密码 `oneclick://user:password@…`、脚本错误文案里的 "credentials"。
- **唯一的真实泄漏是一处还没提交的 Team ID。** 上一条目的正文里写了 `~/Library/Group Containers/<真实 Team ID>.local.oneclick.shared`，它在**未提交的 diff**里（`git log -S` 零命中、全历史 `git grep` 零命中），是改写历史前的最后窗口，已改为 `<Team ID>`。新增 `tests/release-scripts/test_repository_hygiene.py` 把它钉住：一个测试要求 `config/Local.xcconfig` 永不被跟踪，另一个从该文件读出 Team ID 后扫描整个工作区。**先让它对未修的行红了一次**（精确命中 `docs/implementation-log.md` 一处、零误报），再改行让它绿。扫描跳过 `.git/`、`.build/`、`dist/`、`.superpowers/`——`.build/` 里的扩展二进制嵌着展开后的真实 Team ID，不跳过就会永久误报。没有用正则匹配 Team ID 的形状：仓库已有 `TEAM123456`、`OTHER12345`、`AB12CD34EF` 三个合成 fixture，正则方案需要一份每加一个 fixture 就要改的白名单。
- **剪贴板换行注入**：`pathText` 用 `\n` 拼接路径，而换行是 APFS 的合法文件名字符。名为 `报告\n/tmp/pwn` 的文件被选中并「复制路径」后，剪贴板会多出一行用户没选过的路径——粘贴进 shell 就是一次执行。**修复不是转义**：`\n` 同时是分隔符，转义后的内容与「两条路径」无从区分，而粘贴方是任意应用。改为新增 `SelectionContext.clipboardText()`，遇 `Character.isNewline` 时抛 `invalidSelection` 并点名是哪条路径（路径先经 `\n`/`\r` → `⏎` 单行化，否则控制字符会经错误文案进弹窗）。`pathText` 保持原样——它是 5 处测试的菜单快照比较基准，且 `\n` 作分隔符的格式契约有测试钉住。守卫**只在剪贴板这一侧**：`open` 走 URL 不经文本，含换行的文件仍必须能打开，为此专门有一条测试（`openingStillAcceptsANameContainingALineBreak`）防止后来者把守卫挪进 `init`。
- **`applicationURL` 路径标准化**：导入时 `standardizedFileURL` 之后再读 `Bundle`（顺序是必须的——`standardizedFileURL` 是纯词法操作，不要求路径存在，而原始路径的中间目录可能不存在），校验侧只加 `..` 分量拒绝。**规范化不能放进 `validate`**：它在 `load` 和 `save` 都跑，必须保持纯检查，项目有多处「坏配置不被覆盖」的测试钉住这一点。**刻意不要求 `standardizedFileURL == applicationURL`**：`URL` 相等性受 `hasDirectoryPath` 影响，Codable 往返会带上尾斜杠，这种检查会让已落盘的好配置读不出来（菜单消失 + 设置窗口报「配置无效」），是最坏的一类回归；这一点在 `AGENTS.md` 里记为陷阱。
- **去掉按 bundle 标识反查应用**：`ApplicationResolver` 原先在存储路径失效时静默回落到 `NSWorkspace.urlForApplication(withBundleIdentifier:)`，把「选哪个二进制」交给 LaunchServices 注册顺序——抢注同标识的 bundle 即可接管，而菜单显示的名字来自别名表、与真实二进制解耦。**照字面删两行会让产品坏掉**：内置 Terminal 是 `applicationURL: nil` 且 `validate` 强制 `.terminal` 必须如此，它只能靠回落解析，删掉后全新安装的默认目标直接失效、目录菜单只剩「复制路径」。改为 Terminal 走固定的 `/System/Applications/Utilities/Terminal.app`（运行时默认值，不改 schema、不加迁移、旧配置原样可用）。`ApplicationResolver` 此前**完全没有测试**（既有测试都注入替身），新增 5 条，其中 `aStoredPathThatNoLongerExistsIsNeverReplacedByABundleIdentifierLookup` 是判别性的：旧代码会经 LaunchServices 返回系统 Terminal，新代码必须返回 `nil`。接受的功能代价：应用被移动/改名后菜单项消失，需重新导入。
- **错误文案上限**：`last-error.txt` 在 App Group 容器里，任何同用户进程都能写，内容随后渲染进设置窗口的 `.alert`，而触发它的分布式通知没有发送方认证。写入侧按字符截断（500），读取侧按字节截断（64 KB，用 `FileHandle.read(upToCount:)` 而非 `Data(contentsOf:)`——后者会把整个文件读进内存，截断之前进程就已经被打爆）。顺带把 `String(data:encoding:.utf8)` 换成 `String(decoding:as: UTF8.self)`，修掉「非法 UTF-8 让错误静默消失」这个既有缺陷；空文件返回 `nil`，不再弹出空弹窗。
- **entitlements 的只读例外不动，但把论证补全。** 三个收窄方向都查了：①不存在跟随 Finder 选区的 entitlement——`com.apple.security.files.user-selected.read-only` 已经在文件里，它正是不覆盖 `selectedItemURLs()` 的那个键（Powerbox 只由 `NSOpenPanel`/拖放触发），安全作用域书签要先有访问权才能签发；②把 open 移交无沙盒主 app 不可取——这套机制曾存在并在 2026-09-12 被主动删除，重建它要推翻「无后台进程」的不变量，而且**反转安全姿态**：主 app 从「只显示一行错误」变成「必须信任扩展写下的请求并据此执行打开」，攻击面净增；③前缀收窄原理上可行（数组可写若干绝对路径），但失败模式是**静默的**——清单漏掉某处，用户点「用 VS Code 打开」就是直接失败，而这是产品的核心动作，且要覆盖从 DMG 装的应用、`/opt/homebrew`、`/private/var/folders` 等，列表最后接近「用户可见的一切」。此前只有 `docs/verification.md` 记了 `home-relative-path` 那一条，不足以让后来者看出这是决定而非疏漏。
- 测试：新增 `ApplicationResolverTests`（5）、`SharedEnvironmentErrorTests`（5）、`RepositoryHygiene`（2），`SelectionContextTests` +2、`ActionExecutorTests` +2、`SettingsRepositoryTests` +2、`SettingsModelTests` +1。`standardizedFileURL` 对已干净路径是否恒等这个不确定项，由既有的 `customApplicationsDeduplicateByBundleAndCanBeRemoved` 哨兵测试直接验证通过。
- 文档同步：`AGENTS.md` 增三条运行时不变量（剪贴板格式、只打开用户选过的路径、App Group 内容不可信）与两条约定（Team ID 写占位符；`applicationURL` 规范化 + 校验保持纯检查，含 `hasDirectoryPath` 陷阱）；`docs/testing.md` 覆盖表增三行、`仍未自动化` 增两条真机验收项。
- **仍未真机验收**（在 `docs/testing.md` 的「仍未自动化」里列着）：应用改名/移动后菜单项消失而非打开别的 bundle；Terminal 仍能对文件夹工作。
