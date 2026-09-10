# OneClick 后台形态与右键菜单优化方案

日期：2026-09-10
状态：**步骤 0–6 已实施**。验收结果见 [验收记录](../../verification.md) 的"后台形态重做"一节；剩余两项需在真实 Finder 中手工确认。

## 已定方向

| 决策 | 选择 | 直接后果 |
| --- | --- | --- |
| 平时入口 | **C. Finder 工具栏按钮** | 入口由已常驻的扩展提供，不新增进程、不需要登录项，平时只占 5.7 MB |
| 沙盒路线 | **加全盘只读 entitlement，让扩展自足** | 删掉整套主程序请求中转；零冷启动 |
| Claude | **暂时完全删除** | `TargetKind.claude`、`ClaudeLink` 及其测试全部移除 |
| Terminal | **恢复为预置目标** | `.terminal` 与"工作目录"保留，不再是死代码 |
| 文件选区 | **维持现状** | 文件只显示"复制绝对路径"，不出现应用入口 |

最终产品面：右键菜单只有**两个动作**——用指定应用打开、复制绝对路径；预置目标为 Terminal，其余由用户导入。

## 决定性发现：沙盒扩展为什么打不开文件

用与 `OneClickFinder.appex` **完全相同的 entitlements** 签名探针，在本机 macOS 26.6.2 实测：

| 能力 | 扩展同等授权 | 加全盘只读例外 |
| --- | --- | --- |
| `stat` 文件（元数据） | ✅ 允许 | ✅ 允许 |
| 读取文件内容 | ❌ **拒绝** | ✅ 允许 |
| 枚举目录内容 | ❌ **拒绝** | ✅ 允许 |
| 启动应用（不带文件 URL） | ✅ 允许 | ✅ 允许 |
| **把文件 URL 交给另一个应用打开** | ❌ **拒绝** | ✅ 允许 |

拒绝时的错误：`The application "Terminal.app" could not be launched because a miscellaneous error occurred.`

**根因**：LaunchServices 代打开时要求调用方对被打开项有沙盒读取权限，而 `FIFinderSyncController.selectedItemURLs()` 交出的 URL 不附带这个权限。Apple 已知且至今未修——[rdar://42874694](http://openradar.me/42874694)，2018 年提交，状态 Open，描述与本次实测一致。

**Terminal 不是特例**：VS Code 等任何目标同样打不开。`docs/verification.md` 只记了"扩展直接打开 Terminal 失败"、未记原因，随后把所有目标都转交主程序。菜单能用是因为只做 `stat`；复制路径能用是因为不碰文件数据——只有"打开"必须绕主程序。

**没有更窄的选项**：实测 `home-relative-path.read-only = ["/"]` 同样能读到 `/Applications` 下的文件，并不比全盘更窄。真正窄的授权需要静态枚举子路径，而覆盖目录是运行时可改的，静态 entitlement 追不上。所以只能二选一：沙盒锁死打不开任何文件，或全盘只读。

**风险缓解**：主程序当前**根本没有沙盒**（`config/OneClick.entitlements` 只有 app group），全盘读权限已在产品现有信任边界内；本方案只是把能力从主程序挪进扩展，没有扩大边界。该 entitlement 属 "temporary exception"，Mac App Store 不接受，本项目走 Homebrew / Developer ID，不受此限。

## 实测数据

物理内存取 `footprint` 的 `phys_footprint`。**`ps` 的 RSS 会严重高估**（含共享库）：同一时刻 RSS 78.2 MB，实际物理占用 17 MB。

| 状态 | 物理内存 | RSS（对照） |
| --- | --- | --- |
| Finder 扩展常驻 | **5.7 MB** | 31.3 MB |
| 主程序常驻，无窗口 | **17 MB** | 78.2 MB |
| 主程序 + 配置窗口 | **41 MB** | 123.9 MB |

菜单热路径（冷 / 稳态）：`NSWorkspace.icon(forFile:)` 18.269 / 0.644 ms；`urlForApplication(bundleID)` 0.230 / 0.006 ms；`settings.json` 读取 0.231 ms；解码 0.003 ms；**一次完整菜单构造（2 目标，含图标与 copy）稳态 0.160 ms**。菜单构造不是瓶颈，只有新进程首次右键的图标查找值得处理。

## 执行计划

### 步骤 0（前置依赖）：修掉冷启动不开窗

**这一步是步骤 3 的前提**：工具栏按钮的"打开设置"必须唤起主程序，而当前冷启动有约 2/3 概率不出现窗口（实测 HEAD 版本 3 次全不出现，本方案改动后 6 次全不出现）。入口依赖它，必须先修。

- **根因**：`AppDelegate.applicationShouldOpenUntitledFile` 在 Scene body 给 `delegate.showSettings` 赋值之前就可能被调用，此时 `showSettings` 还是空实现，于是没有任何窗口被创建。
- **修法**：`AppDelegate` 增加一个"已请求显示设置"的标记；`applicationShouldOpenUntitledFile` / `applicationShouldHandleReopen` 只置位；Scene body 安装 `showSettings` 时立即消费该标记。这样两条时序都能落到同一个结果，不再依赖调用顺序。
- **验证**：连续冷启动 10 次，每次都出现窗口；再验证应用已在运行时点工具栏按钮能把窗口带到前台。`AppLifecycleTests` 补一条覆盖"请求早于闭包安装"的用例。

### 步骤 1：扩展自足，删掉请求中转

- `config/FinderExtension.entitlements` 增加 `com.apple.security.temporary-exception.files.absolute-path.read-only = ["/"]`（**只给扩展**，主程序保持未沙盒）。
- `FinderSync.openTarget` 改为直接 `ActionExecutor().open(...)`，删除请求写入与主程序唤醒。
- 删除：`OpenRequestRepository.swift`、`OpenRequestLink.swift`、`OpenRequestDispatcher.swift`、`OpenRequestHandler.swift`、`AppDelegate` 的 `application(_:open:)`、`config/OneClick-Info.plist` 的 `oneclick` URL scheme、对应行为测试。
- **验证**：先用探针确认新 entitlements 生效（读文件 / 枚举目录 / 交给 Terminal 打开三项全通过），再在真实 Finder 里右键文件夹打开 Terminal，并用 `pgrep -x OneClick` 确认主程序**没有**被拉起。

### 步骤 2：删 Claude，恢复 Terminal 预置

- `OpenTarget.builtIns` 改为 Terminal：`kind: .terminal`、`bundleIdentifier: com.apple.Terminal`。
- `SettingsRepository` **当前会拒绝空目标列表**（`repositoryRejectsAnEmptyTargetList`）：删 Claude 后如果用户移除了所有目标，保存会被拒绝。必须放行空列表，否则用户无法清空。
- 删除：`ClaudeLink.swift`、全部 `claudeLink*` 测试、`TargetKind.claude`、以及 `ApplicationResolver` / `ActionExecutor` / `ApplicationRow` / `OpenTarget` 中的 claude 分支与文案。
- 保留并确认 `.terminal` 路径：`SelectionContext.workingDirectories()`、多选去重、文件取父目录。
- **验证**：`./script/check.sh --build --disable-sandbox`；真实 Finder 中选中文件夹与文件分别打开 Terminal，用 `lsof -d cwd` 核对工作目录（沿用既有验收方法）。

### 步骤 3：Finder 工具栏入口

- 设置 `FIFinderSyncController.default().toolbarItemName` / `toolbarItemImage`，并在 `menu(for:)` 中处理 `.toolbarItemMenu`。
- 菜单内容：当前 Finder 窗口选区对应的两个动作 + 分隔线 + **"OneClick 设置…"**。
- "打开设置"通过 `NSWorkspace.openApplication(at:)` 启动容器 App（含 `Contents/PlugIns/...` 向上三级得到 `.app` 路径），依赖步骤 0 的修复。
- **验证**：Finder 工具栏出现按钮；选中文件夹后点按钮能打开 Terminal；点"设置"能唤起配置窗口；全程 `pgrep -x OneClick` 只在点设置后出现。

### 步骤 4：右键菜单热路径与文案

1. 扩展进程内按 bundle id 缓存图标，消掉新进程首次右键的 18.269 ms，随 `settingsChanged` 失效。
2. 扩展进程内缓存配置快照，同样随通知失效，让菜单构造完全不碰磁盘。
3. 文案：只有 1–3 个目标时"在 Visual Studio Code 中打开"会占据顶级菜单，统一为"用 X 打开"。
4. 折叠阈值 `index < 3`（`FinderMenuBuilder.swift:21,28`）需要拿 4–6 个真实目标复核。

### 步骤 5：首次运行引导

- 现在：装好 → 打开 App → 手动去系统设置启用扩展，`showExtensionManagementInterface()` 只能跳到面板。
- `FIFinderSyncController.isExtensionEnabled` 目前只在 `didBecomeActive` 时刷新（`SettingsModel.swift:28`），引导流程中需在窗口内轮询，否则切回来之前界面一直是旧状态。

### 步骤 6：文档与测试同步

- `README.md` 与 `docs/superpowers/specs/2026-09-10-oneclick-design.md` 目前仍以 Claude Code 与 Terminal 双目标为核心场景，且设计文档写着"首版不增加菜单栏常驻图标"——与本方案的工具栏入口结论不同，需要显式改写而不是绕过。
- `docs/verification.md` 补上沙盒实测结论与"Terminal 不是特例"的更正。
- `docs/implementation-log.md` 记录本次方向调整。

## 验证方式

- **沙盒能力**：复用 `.build/ui-review/SandboxProbe.swift`——用扩展的 entitlements 签 `SandboxProbe.app`，逐项验证读文件 / 枚举目录 / 交给应用打开。改 entitlement 后必须重跑，这是不依赖 Finder 交互就能验证授权的手段。
- **右键延迟**：扩展已埋日志（`Menu requested` → `Built menu for N items`），`log show --predicate 'subsystem == "local.oneclick.app"'` 统计 P50 / P95，改前改后各一轮。
- **常驻成本**：`footprint <pid>` 取 `phys_footprint`，**不要用 `ps` 的 RSS**。
- **是否仍唤醒主程序**：动作前后 `pgrep -x OneClick` 对比，这是步骤 1 是否真正生效的判据。
- **回归**：`./script/check.sh --build --disable-sandbox`。

## 遗留问题

- 冷启动不开窗是既有缺陷（bisect 确认 HEAD 同样复现），步骤 0 顺带修掉；若你想单独跟踪，也可以拆出来先修。
- ~~`script/generate_project.py` 已被删除但 `AGENTS.md` 仍在引用它~~ **已解决**：该文件是在工作区里被误删的（HEAD 中仍在），且它生成的正是当前布局。已从 HEAD 恢复，并验证重复运行与现有工程**逐字节一致**，`check.sh --build` 通过。README 补上了使用说明与"重复运行应零差异"的自查方法。

## 实施中的两处主动偏离

计划里的两项经复核后**决定不做**，理由如下，不是遗漏：

- **步骤 4 的菜单文案保持"在 X 中打开"未改。** 计划中"统一为'用 X 打开'"是写方案时的臆测，没有证据表明现文案有问题：它是 macOS 中文的惯用说法，且只短一个字。在无法真实右键目视核对的前提下改文案属于无据改动，与"用实测替代推测"的原则相悖。若实测后觉得顶级菜单过长，再改不迟。
- **步骤 5 不加轮询。** 计划担心"用户切回来之前界面一直是旧状态"，但 `SettingsModel` 已在 `NSApplication.didBecomeActiveNotification` 上刷新，而用户从系统设置切回时**必然**触发该通知——刷新时机本就正确，轮询只会增加定时器和反复的 pluginkit 查询。改为解决真正的摩擦点：提示文案写明确切位置"点按打开「登录项与扩展」"，因为用户找不到那个开关才是首启的实际困难。
