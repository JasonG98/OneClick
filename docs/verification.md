# OneClick 本地验收记录

日期：2026-09-10。环境：macOS 26.6.2、Apple Silicon、Xcode 26.6、Swift 6.3.3。

## 右键菜单文案与图标

用户截图反馈工具栏下拉菜单"UI 有点问题"。用 `.build/ui-review/menudump` 调**生产代码**把菜单建出来，先量数据再改，而不是凭截图猜：

| 项 | 改前 | 改后 |
| --- | --- | --- |
| 应用项文案 | `在 Visual Studio Code 中打开` | `用 Visual Studio Code 打开` |
| 最长标题文字宽 | **173.4 pt** | **160.5 pt** |
| 子菜单标题 | `在应用中打开` | `用其他应用打开` |
| `复制绝对路径` 图标 | **16×18** | 16×16 |

- **文案**：`在 X 中打开`里的"中"是多余的，Apple 中文界面用"用…打开"（"打开方式"）。子菜单标题一并改成"用其他应用打开"，这样内联项与子菜单项的动词一致——改前同一个应用会因为排在第几位而显示成"在 X 中打开"或光秃秃的"X"，同一个动作两种标签。
- **图标尺寸**：`FinderMenuBuilder` 原来只对**应用图标**设 `16x16`，SF Symbol 保留自然尺寸（`doc.on.doc` 是 16×18），图标列逐行高度不一致。测试 `everyMenuItemImageSharesTheSameBox` 锁住这条。
- **图标随外观变色（用户反馈浅色下"复制绝对路径"图标不变色）**：第一次尝试是修 `copy()` 并显式声明 `isTemplate = true`，**用户复测未通过**——说明图标不是以 template 到达 Finder 的，它变成了一张定色位图，渲染方不会再着色。现在改为**在构建菜单时把颜色烤进图标**：用 `SymbolConfiguration(paletteColors:)` 按系统外观取白或黑，并显式 `isTemplate = false`。菜单每次调用都重建，所以颜色始终是打开那一刻的外观。
- **颜色来源读的是系统设置（`AppleDefaults` 里的 `AppleInterfaceStyle`）而不是进程的 `effectiveAppearance`**：进程外观可能停留在启动时的模式，那正是这个 bug 的成因。
- **这个修复可以在不依赖菜单渲染器的前提下验证**：直接把生产代码产出的图标画进位图看颜色。实测深色系统下平均亮度 1.00（白）、浅色下 0.00（黑），`isTemplate` 均为 false。改用这种方式是因为本仓库的菜单预览 harness 在浅色下不可信（见下条）。
- **「OneClick 设置…」前的分隔线最终去掉，并换成用图标区分。** 过程走了三步弯路，值得记下来：① 先按"空隙太大"的猜测移除分隔线，用户回"分割线没了"，遂恢复；② 恢复后用户仍说"看不见"，于是在**用户的真实截图**上逐像素测量，分隔带内 35 行全是均匀的 `rgb(85,81,76)`，**确认 Finder 保留了分隔符的占位却没有画那条线**——本仓库的预览 harness 会画（自己绘制），差别在渲染方，扩展无法控制；③ 既然线画不出来，占位就只剩"一块像缺了一项的空白"。最终去掉分隔符，并让该行携带**应用自身的标记**（`cursorarrow.click.2`，与工具栏按钮同一个字形）而不是通用齿轮，从而与文件操作区分。
- 教训：用户说"布局有问题"时，"那里多了一块空白"和"那里少了一条线"是两种相反的诉求，仅凭"那块不对"无法区分，应当先问清现象再动手。
- **侧边栏的三次改动全部回退，恢复 `NavigationSplitView` 与折叠按钮。** 依次做过：移除折叠按钮、把列宽钉死为 202、改用 `HStack` 固定列以彻底消除拖拽。用户看到 `HStack` 版本后判断"太丑"，要求恢复。**原因是原生观感不可替代**：分栏视图会把侧边栏材质铺到窗口顶部（红绿灯落在侧边栏上），而 `HStack` 版本里标题栏下方多出一条通栏分隔线，侧边栏从标题栏下面才开始——这是 `HStack` 给不了的。现在的状态是 `NavigationSplitView` + `.navigationSplitViewColumnWidth(min: 190, ideal: 202, max: 250)` + 可拖拽分隔条 + 折叠按钮。
- 教训一：**约束能限制结果，但不能取消交互**。"把宽度钉死"和"不允许调整宽度"是两件事，验收时必须分别确认。
- 教训二：**为一个次要的交互偏好去替换原生容器，会连带丢掉它的视觉。** 折叠按钮和拖动宽度都是小问题，代价却是整个侧边栏的观感；这类取舍应当先摆出代价再动手，而不是做完再让用户否决。
- **浅色模式下的图标修复已获目视确认。** 系统稳定在浅色时重跑预览 harness，复制路径与设置两个图标都渲染为深色、清晰可见。同一张图里**文字仍是浅灰**（harness 自身的外观同步缺陷，原生对照菜单同样如此），而我们的图标颜色正确——这恰好从反面证明了修复的机制：图标不再受渲染方外观影响，颜色是按**系统设置**在构建菜单时烤进去的。
- **教训：浅色模式下本仓库的预览 harness 不可信。** 试着用 `osascript` 临时切到浅色复现时，harness 渲染出的菜单文字与符号都是近白色（整个菜单区域平均亮度 0.98、0 个暗像素），看起来完美复现了用户的报告。但**加入对照组合一个完全原生的普通 `NSMenu`，它在同样条件下同样渲染不出来**——说明这是 harness 自身的外观处理问题，不是产品缺陷。**做外观对照实验时必须带原生控件对照组**，否则会把工具的问题当成产品的 bug 去修。
- 回归：**74 项** Swift 测试、6 项脚本测试、arm64 编译通过。
- 预览方法：`menudump` harness 用生产 `FinderMenuBuilder` 建菜单后 `NSMenu.popUp`，外部 `screencapture` 截图，因此**不必真的去点右键**就能迭代菜单外观。注意让 harness 读 `/tmp` 下的配置副本，直接读 App Group 容器会触发"访问其他 App 的数据"系统授权框。
- 回归：**73 项** Swift 测试、6 项脚本测试、arm64 编译通过。

## 后台形态重做：扩展自足

- **冷启动不开窗已修复，并更正了原因。** 原判是"Scene body 赋值晚于 AppKit 回调"的时序竞争，实测证伪：日志里完全没有 `Settings requested by ordinary launch`，说明 `applicationShouldOpenUntitledFile` **根本没有被调用**——它是文档型 App 的 `NSDocumentController` 回调，普通窗口 App 收不到。改用 `applicationDidFinishLaunching` 后，连续冷启动 **10/10 出窗**（修复前 0/10，bisect 确认 HEAD 同样 0/3，属既有缺陷）。展示请求早于场景安装时会被记录并在安装后重放，有 4 项测试覆盖。
- **查明了扩展打不开文件的真正原因。** 用与 `OneClickFinder.appex` 完全相同的 entitlements 签名探针实测：`stat` 允许、读文件与枚举目录**拒绝**、启动应用允许、**把文件 URL 交给另一个应用打开拒绝**（`could not be launched because a miscellaneous error occurred`）。根因是 `selectedItemURLs()` 交出的 URL 不附带沙盒读取权限，LaunchServices 因此拒绝代打开——这与具体应用无关，**Terminal 不是特例**。对应 Apple 问题 [rdar://42874694](http://openradar.me/42874694)，2018 年提交至今仍为 Open。此前 `docs/verification.md` 只记了"Terminal 失败"未记原因，随后把所有目标都转交主程序；这解释了为什么菜单与复制路径一直正常，唯独打开必须绕路。
- **加了只读例外并验证生效。** `config/FinderExtension.entitlements` 增加 `temporary-exception.files.absolute-path.read-only = ["/"]`（只给扩展）。从**构建产物**导出真实 entitlements 重跑探针，五项全部通过；主程序 entitlements 确认**不含**该例外。实测确认没有更窄的可行选项：`home-relative-path.read-only` 同样能读到 `/Applications` 下的文件，真正窄的授权需要静态枚举子路径，追不上运行时可改的覆盖目录。
- **删除了整套请求中转**：`OpenRequestRepository`、`OpenRequestLink`、`OpenRequestDispatcher`、`OpenRequestHandler`、`oneclick://` URL scheme、`AppDelegate` 的 URL 处理与相应测试。主程序不再需要后台唤醒。
- **Claude Code 暂时移除，Terminal 恢复为预置。** `TargetKind.claude`、`ClaudeLink` 及其测试删除。旧配置迁移：先摘除退休预置再校验，未知 `kind` 宽容解码为 `.application`（否则老配置会以"配置已损坏"整体读不出来）；仅当确实摘除了东西才动列表，并在那时补齐缺失的内置目标。真实机器验证：配置从 `VS Code + Claude` 迁移为 `VS Code + Terminal`，导入应用与其开关保留。空目标列表不再被判为非法。
- **Finder 工具栏入口**：覆写 `FIFinderSync` 的 `toolbarItemName` / `toolbarItemImage` / `toolbarItemToolTip`（这三个是只读属性，文档要求覆写 getter，不是赋值给 `FIFinderSyncController`），并处理 `.toolbarItemMenu`。菜单尾部附「OneClick 设置…」，即使没有选区也可达。
- **图标缓存**：新增 `TargetAvailabilityCache`，只缓存正结果并随 `settingsChanged` 失效。动机是实测冷进程首次 `NSWorkspace.icon(forFile:)` 为 18.269 ms、稳态 0.644 ms，而菜单回调会阻塞 Finder。负结果不缓存，避免运行期间新装应用不出现。
- 回归：`./script/check.sh --build --disable-sandbox` 通过，**64 项** Swift 测试、6 项发布脚本测试、arm64 编译。
- 内存（`footprint` 的 `phys_footprint`，非 `ps` 的 RSS）：扩展常驻 **5.7 MB**，主程序无窗口 **17 MB**，主程序开设置窗口 **41 MB**。
- **生产代码路径在真实沙盒下做了对照实验。** 把 `ActionExecutor` 与 `SystemWorkspace` 的**源文件本身**（不是探针副本）编进一个沙盒程序，用扩展的真实 entitlements 签名后调用生产打开路径，唯一变量是那条只读例外：

  | 条件 | 结果 |
  | --- | --- |
  | 不带 `temporary-exception…read-only` | ❌ `The application "Terminal.app" could not be launched because a miscellaneous error occurred.` |
  | 带该例外 | ✅ 打开成功 |

  这证明打开动作可以在扩展进程内完成，且因果关系锁定在那条 entitlement 上。配合两条既有事实可以推断插件沙盒不会额外阻断：扩展此前**成功**通过 `NSWorkspace` 唤起过主应用（见"主应用退出后的请求"一行），说明插件 profile 不禁止 LaunchServices 调用；而文件交接失败的原因已确认是缺少读取权限，该权限现已具备。
- **Finder 工具栏入口已确认注册进真实 Finder 窗口。** `com.apple.finder.plist` 的 `NSToolbar Configuration Browser → TB Item Identifiers` 含 `local.oneclick.app.finder`，`FXSyncExtensionToolbarItemsAutomaticallyAdded` 也含它且 `PendingAdd` 为空。三条证据把因果锁定在本次改动：该偏好文件修改时间 `23:44:23`，扩展二进制构建于 `23:44:13`，即 Finder 在扩展重新加载后 10 秒内完成注册；`git show HEAD:src/finder-extension/FinderSync.swift` 中 `toolbarItem` 出现 **0 次**，旧代码不可能产生该注册。

- **真实 Finder 右键端到端已由用户手工确认通过。** 在覆盖目录内右键 → 「在 Terminal 中打开」，Terminal 正常打开，且操作前后 `pgrep -x OneClick` **均无输出**——主程序没有被拉起。这是本轮改造是否真正生效的硬判据，至此扩展自足已获端到端证实，不再依赖推断。扩展日志给出同一条链路的三个环节，全部落在扩展进程内：

  ```
  23:49:32  [finder]  Menu requested, kind 1        # FIMenuKindContextualMenuForContainer
  23:49:32  [finder]  Built menu for 1 items
  23:49:34  [actions] Opened target terminal, selection count 1
  ```

  注意 `Opened target` 的 category 是 `actions` 且进程为 `OneClickFinder[81539]`——打开动作确实由扩展执行。
- **Finder 工具栏按钮已确认可用。** 日志显示用户两次点击工具栏按钮（`FIMenuKindToolbarItemMenu` = kind 3），扩展每次都成功构造了菜单：

  ```
  23:50:30  [finder]  Menu requested, kind 3
  23:50:30  [finder]  Built menu for 1 items
  23:50:59  [finder]  Menu requested, kind 3
  23:50:59  [finder]  Built menu for 1 items
  ```

  结合先前确认的注册证据（`TB Item Identifiers` 含 `local.oneclick.app.finder`），工具栏入口从注册到点击可用已闭环。菜单里「OneClick 设置…」能否唤起配置窗口**未在日志中留下证据**（该时段无主程序启动记录），如需确认请点一次该项。

### 尚未验证

- 降低透明度与增强对比度仍未逐项人工验收。

## 配置窗口空状态修复

起因是补做"首次运行体验"验收——这一屏此前从未被真实看到过。步骤：备份真实配置 → 删除 → 应用自动写入新配置 → 截图。

- **全新安装的首屏不是空状态**：`Settings.initial(home:)` 会写入 `targets = [Terminal]` 与 `directories = [home]`，所以应用页显示一行 Terminal（1/1），覆盖目录页显示主目录。**应用页的空状态因此无法通过界面到达**：`ApplicationRow` 对内置目标不显示"移除"，Terminal 永远删不掉，只有手工改配置才能构造出空列表。这一点值得知悉——它意味着该空状态是死 UI，除非将来允许移除内置目标。
- **覆盖目录页的空状态则是用户可达的**（每行都有"移除目录"），而它当时是坏的。删除全部覆盖目录后，窗口内容整体从**顶边**开始布局：侧边栏第一行爬到红绿灯上方，"覆盖目录"区块标签被标题栏盖住，底部提示栏被挤出可视区。用取色器核对过窗口边界与截取范围一致（735→786 与探测的 335/452 吻合），确认是真实渲染而非截图偏移。
- 排除过的两个错误假设，都做了对照实验：一是"`emptyState` 自带贪婪 frame 被嵌套进同样贪婪的页面"（改成自然尺寸 + 调用处加 Spacer，**无效**）；二是"内容区里的 `.glassProminent` 按钮触发了 Liquid Glass 的窗口级协调"（换成 `.borderedProminent`，**同样无效**）。
- **真正的原因是手搓的空状态栈本身**：详情列里一旦没有 `List` 或任何滚动视图，`NavigationSplitView` 就把整个窗口从顶边布局，标题栏变成浮在内容上的一层。改用系统原生的 `ContentUnavailableView` 后，侧边栏、区块标签、空状态与底部提示栏全部正常。两个页面都已截图核对。
- 顺带修掉一处文案不自洽：列表为空时底部仍写着"拖动调整顺序；右键可上移、下移或移除"。现在空列表时改为"配置会自动保存"。
- **新增"恢复默认主目录"入口。** 删光覆盖目录后扩展不再监控任何位置，Finder 菜单彻底消失，而原来的界面只能靠文件选择器一个个加回来——这是个卡死状态。现在空状态提供次要操作「恢复默认主目录」（`SettingsModel.restoreDefaultDirectory()`，复用 `addDirectories` 的去重），覆盖目录页在**主目录确实缺失**时工具栏额外显示一个房子按钮，覆盖"列表非空但缺主目录"的情况。两个场景均已截图核对。新增 2 项测试：恢复后落盘且通知 Finder、主目录已存在时不重复添加。
- 验证后已恢复真实配置（`VS Code + Terminal`）并截图复核正常。回归：**66 项** Swift 测试、6 项脚本测试、arm64 编译通过。

## 配置窗口视觉重做

- 截图暴露出三个问题：窗口整面 `.ultraThinMaterial` 把侧边栏、列表和工具栏压成一块灰；页面标题写在内容里而工具栏为空，两个操作是不透明灰圆钮、看起来像禁用；`.inset` 列表与所在窗格同色，卡片边界不可见，两行内容下方留下大片空白。
- 现在窗口改用系统背景；页面标题与副标题交给工具栏，`+` 与刷新是 `.primaryAction` 中的玻璃按钮；侧边栏底部状态卡是唯一的自定义交互面，使用 `glassEffect` 并包在 `GlassEffectContainer` 内，开启降低透明度时回退为不透明卡片。
- 列表保留原生 `List`，因此拖拽排序、右键菜单和开关行为不变；在其上显式绘制卡片表面与发丝描边。行高固定，卡片按内容收缩而不是撑满窗格，每个页面底部固定一条提示栏。
- 实测取色确认 `.inset` 列表与其窗格同为 `#2F2F2D`：卡片必须显式绘制才有边界，这是列表看起来“没有容器”的原因。
- 应用、覆盖目录、关于三个页面以及深色、浅色两种外观均实际运行截图核对，截图在 `.build/screenshots/settings.png`、`settings-light.png`。
- 回归：`./script/check.sh --build --disable-sandbox` 通过，72 项 Swift 测试、6 项发布脚本测试、Shell 语法检查与 arm64 编译均无失败。

## Finder 静默唤醒修复

- 设置场景禁用默认启动展示、窗口恢复和外部 URL 路由；URL 由 AppDelegate 处理。普通启动、重新打开及设置菜单显式展示窗口。后台请求不初始化设置模型。
- 新增 4 项 AppLifecycleTests。`./script/check.sh --build --disable-sandbox`：68 项 Swift 测试、6 项发布脚本测试、Shell 语法检查、主应用及扩展的 arm64 构建通过。
- 签名开发版实测 Finder → Sublime Text 打开 `.build/fixtures/sample.txt`，冷启动及关闭设置后的请求均记录 `visible windows: 0, active: false`；Sublime Text 显示测试文件。
- 普通启动显示设置，关闭后再次主动打开也能显示设置。通过 Computer Use 检查实际窗口，并用应用日志核对后台状态；未重启 Finder。
- 单独禁止默认窗口展示仍会被 SwiftUI 的 URL 场景路由创建窗口；必须同时排除设置场景的外部事件。运行日志位于 `.build/logs/lifecycle-runtime.log`，测试日志位于 `.build/logs/lifecycle-check.log`。

## 自动化覆盖补齐

- 新增 24 项 Swift Testing 行为测试，覆盖配置模型、真实 NSMenu、应用动作、请求传递及共享容器访问前检查；原有 40 项核心测试保留。
- `./script/check.sh --build --disable-sandbox --enable-code-coverage -Xswiftc -warnings-as-errors` 通过：64 项 Swift 测试、6 项发布脚本测试、Shell 语法检查，以及主应用和扩展的 arm64 编译。测试构建不签名、不启动；退出时撤销 Xcode 自动注册，增量构建已经无注册时可重复运行。
- 临时注入六个回归：反转开关、菜单忽略禁用状态、主应用忽略目标禁用、漏清理请求、Terminal 传入文件、跳过共享组前缀检查。对应测试均产生断言失败；恢复源码后完整检查通过。
- 编入测试包的生产代码行覆盖率为 75.56%，包含未调用的系统适配层，不含 SwiftUI 视图和 Finder 进程接入。覆盖率文件在 `.build/core/arm64-apple-macosx/debug/codecov/`。
- 本轮未调用 Computer Use。下方 GUI 与签名结果保留为之前开发版的实测记录；本轮验证以自动化测试及编译为限。详细命令与测试边界见 [测试说明](testing.md)。

## 已通过

| 项目 | 证据 |
| --- | --- |
| Swift 核心行为 | `./script/test.sh --disable-sandbox -Xswiftc -warnings-as-errors`：40 项通过 |
| 分发脚本行为 | `tests/release-scripts/run_tests.sh`：6 项通过；Bash 语法检查通过 |
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
| 原生界面 | 实际运行 SwiftUI 配置窗口：原生工具栏、`glassEffect`、`GlassEffectContainer` 和玻璃按钮；截图在 `.build/screenshots/settings.png`。重做后的细节见本文首节 |
| 重复权限提示修复 | 换用有效团队签名后重新启动主应用、启用扩展并连续操作；最终查询最近 10 分钟 OneClick 的 TCC `AUTHREQ_PROMPTING` 日志为空 |

## 运行中发现并修复的问题

1. Finder 的菜单回调发生在 XPC 后台队列。原来的主线程假设触发 Swift 6 `EXC_BREAKPOINT`。现在先在回调内捕获选择，再通过有双向调用测试的 `MainThreadBridge` 同步构造菜单；动作仅把整数 tag 交给主线程。
2. Finder 不保留 `NSMenuItem.representedObject`。改用 tag 对应不可变选择快照，旧菜单的动作不会误用后来的选择。
3. 扩展直接打开 Terminal 失败。现在以 App Group 中限大小、带有效期的一次性请求唤醒主应用；主应用只按当前配置中的已启用目标执行，没有任意命令接口。消费后删除请求。
4. ad hoc 开发签名没有经过系统授权的 App Group 身份，触发“访问其他 App 数据”提示。已停用旧进程，改用 Apple Development 签名与实际团队前缀共享组；构建脚本禁止无团队配置的集成运行，代码在访问容器前检查签名团队。未要求 Full Disk Access，也未修改 TCC 数据库。
5. Claude 链接中的字面 `+` 现在编码为 `%2B`，避免被查询参数解析器误作空格。
6. 用户报告“Finder 扩展无法启用了”。开关实际是打开的，坏的是扩展进程：`00:25:21` 日志里扩展还在正常运行，`00:26:35` 随主程序重建退出，之后再没有任何 `OneClickFinder` 进程。**Finder 只在启动时载入一次 Finder Sync 扩展，进程退出后不会自动重启**——`pkill` 掉扩展后静置 25 秒确认它不会自己回来，`killall Finder` 会。这一条也正是开发期每次重建后菜单消失的原因。
7. 同时发现注册指向了错误副本：`pluginkit -m -v` 的路径一直是 `~/Library/Developer/Xcode/DerivedData/...`，而实际运行的是 `.build/DerivedData` 的产物。同一 bundle id 再执行 `pluginkit -a` **不会**顶掉先注册的那份，因此脚本构建的扩展永远加载不到。实测有效序列为 `lsregister -u`（旧宿主 app）+ `lsregister -f`（新产物）+ `pluginkit -e use`，注册路径随即切换到 `.build` 并立即拉起扩展，无需重启 Finder，其他扩展不受影响。
8. `script/check.sh` 的 `EXIT` trap 里调用 `exit`，用清理动作自身的状态覆盖了构建失败状态，于是 `** BUILD FAILED **` 仍以 0 退出。已改为只记录不退出，失败路径现在真的失败。

排障时临时关闭过 RClick 与 Keka 的 Finder 扩展，随后已恢复当时记录的开关。实际菜单在它们启用时也能显示；未将扩展冲突误认成此次菜单崩溃的原因。

### 2026-09-11 实测证据

| 项目 | 证据 |
| --- | --- |
| 扩展随重建退出且不自动恢复 | `pkill -f OneClickFinder.appex/...` 后 25 秒 `pgrep` 无输出；同一状态下 `killall Finder` 后进程立即出现 |
| 注册路径可被改写到本次产物 | 恢复序列执行后 `pluginkit -m -v -i local.oneclick.app.finder` 显示路径为 `.build/DerivedData/.../OneClickFinder.appex`，进程 pid 随之变化 |
| 构建脚本自动恢复扩展 | `./script/build_and_run.sh --verify` 输出 `Finder extension is running` 与 `Development OneClick is running (pid …)` |
| 心跳文件 | 共享容器中 `extension-heartbeat.json` 的 `processIdentifier` 与 `pgrep` 到的扩展 pid 一致，`recordedAt` 为扩展启动时刻 |
| “未在运行”状态可达 | 杀掉扩展后心跳仍指向已死 pid，正是状态卡第三种状态的判据 |
| 重新加载路径可用 | 被杀掉后执行 `pluginkit -e use -i local.oneclick.app.finder`，新 pid 出现，日志重新打印 `Observing 1 configured roots` / `Finder extension initialized` / `Finder began observing a configured directory` |
| 回归 | `./script/check.sh --build --disable-sandbox` 通过：72 项 Swift 测试、6 项发布脚本测试、Shell 语法检查与 arm64 编译 |

**未完成：** 右键菜单与工具栏按钮的最终确认需要真实点击。本次尝试用 `osascript` 的 `AXShowMenu` 打开 Finder 上下文菜单，被辅助功能权限拦下（系统弹出“osascript 不允许辅助访问”），因此扩展端到端的最后一步仍以用户手工确认为准。

## 尚未验证与已知边界

- Claude Code：本机 Handler 的可执行文件链接指向已删除的旧版 Claude CLI；配置显示不可用。已验证链接生成，尚未实测完整 Claude 会话启动。没有代替用户发送提示、修改 Claude 状态或修补第三方安装。
- 深色与浅色外观已实际运行截图核对（`.build/screenshots/settings.png`、`settings-light.png`）。降低透明度与增强对比度只在代码中分流（`accessibilityReduceTransparency` 回退为不透明卡片），尚未在系统设置中逐项开启后人工验收。
- 自定义应用添加/移除、拖动排序、外置盘、Downloads、Desktop、Documents、iCloud/File Provider 范围尚未完整逐项验收。右键排序与本地项目范围已验证；不能据此宣称所有目录通用。
- Finder 正常请求保持 `activates = false`，设置窗口不参与 URL 路由；发生操作错误时仍会主动显示错误提示。实现不依赖沙盒调用者会被忽略的 `NSWorkspace.OpenConfiguration.arguments`。
- 当前证书是 **Apple Development**。Release 归档可用于本地验证，但不是已公证的公开分发版本。
- Developer ID、公证、GitHub Release、Homebrew tap 安装/升级/卸载仍待真实发布环境与仓库地址。脚本测试使用模拟外部工具，不代表 Apple 公证或 Homebrew 安装已经完成。
