# 测试方式

日常开发先运行受影响的 Swift Testing 用例；提交前运行 `./script/check.sh`。修改应用或扩展代码时用 `./script/check.sh --build` 增加真实 Xcode 编译。无需开发证书、Finder 激活或 Computer Use。

## 覆盖范围

| 测试 | 实际运行的生产逻辑 | 替换的系统边界 |
| --- | --- | --- |
| CoreTests | 文件选择与工作目录、路径编码、配置校验与旧版迁移（含 `..` 路径穿越的拒绝与"文件名里带 `..` 不算穿越"）、临时文件读写、主线程桥接、菜单快照、应用别名表与菜单名解析（含"别名不写进配置"）、含换行路径的剪贴板拒绝 | 无 |
| SettingsModelTests | 初次配置、持久化、开关、拖动及右键排序、应用/目录添加去重移除（含导入时的路径规范化）、刷新、读写错误 | Finder 状态、应用安装查询、通知和错误窗口 |
| FinderMenuTests | NSMenu 构造、可用目标过滤与排序、空白处选择、复制菜单、工具栏菜单的设置入口、tag 对应的选择快照、别名在内联项与折叠子菜单项上的文案 | 应用查询和图标 |
| ActionExecutorTests | 编辑器/Terminal 分流，目录去重，特殊字符，失效选择，错误传递，复制文本，含换行路径拒绝复制但不影响打开 | NSWorkspace 和系统剪贴板 |
| ApplicationResolverTests | 只解析用户选过的路径；路径失效或 bundle 标识不符时返回 nil 而不是按标识反查；Terminal 走固定系统路径 | 临时应用包 |
| TargetAvailabilityCacheTests | 正结果缓存、负结果不缓存、失效后重查 | 应用解析与图标查询 |
| AppGroupAccessTests | 缺少/错误签名必须在容器访问前失败；正确团队和不可用容器 | 受保护容器查询 |
| SharedEnvironmentErrorTests | 错误文案的字符上限、读取的字节上限、非法 UTF-8 仍产生消息、空文件不弹空窗 | 临时文件 |
| RepositoryHygiene | `config/Local.xcconfig` 不得入库；真实 Team ID 不得出现在工作区任何位置 | 无（只读 Git 与工作区） |
| AppLifecycleTests | 重新打开请求设置（含窗口已关闭）、关闭窗口即退出 | 设置窗口展示回调 |
| ExtensionAvailabilityTests | 开关与进程两种事实的三种状态；重新加载成功与失败后的提示 | Finder 扩展开关、进程存活查询、`pluginkit` |
| ReleaseScripts | 版本、架构、公证与 Cask 生成的输入输出和失败分支 | Apple/Homebrew 外部命令 |
| UninstallScript | 只报告不删除、按容器元数据判定归属（名字像但不是它的容器必须留下）、注册撤销走注入的工具、可重复执行、`--build` 为显式开关 | `lsregister`、`pluginkit`、`pgrep`/`pkill`、临时 HOME |
| IconPipeline | SVG 解析的拒绝路径、填充与描边的光栅化、PNG 编码、`Contents.json`，以及已提交的图标阶梯与美术稿逐字节一致 | 无（纯计算） |

`tests/behavior/TestSupport.swift` 的替身只记录系统调用边界的参数和错误。配置仓库、菜单生成和动作分流始终使用生产实现；每个测试创建独立临时目录并在结束后清理。

## 常用命令

```sh
./script/check.sh
./script/check.sh --build
./script/check.sh --filter ActionExecutorTests
./script/check.sh --filter FinderMenuTests
./script/check.sh --enable-code-coverage
./script/check.sh --icons        # 额外组装 .icns 并核对十档尺寸
```

`check.sh` 只认 `--build` 和 `--icons`，其余参数原样交给 `swift test`，所以任何 SwiftPM 选项都能直接接在后面。SwiftPM 覆盖率文件位于 `.build/core/*/debug/codecov/`。警告检查可追加 `-Xswiftc -warnings-as-errors`。组合示例：

```sh
./script/check.sh --build -Xswiftc -warnings-as-errors
```

编译检查产物独立放在 `.build/Checks`，日志在 `.build/logs/check-build.log`；不替换正在运行的签名开发版。Xcode 会自动注册 macOS 构建产物，脚本通过退出清理撤销检查产物的注册，构建失败时也会清理。即使清理失败留下登记，`build_and_run.sh` 也会在下次构建时按 bundle id 清掉 `.build/` 下的其它副本。

## GUI 验收边界

Computer Use 用于自动化测试无法证明的部分：Finder 实际加载与菜单显示、工具栏按钮、系统权限对话框、真实应用接收行为、玻璃材质及布局。只有相关系统集成或视觉代码变更时才重测这些项目。设置增删、排序、分流、路径处理和错误分支的日常回归使用上面的测试。

**这条只读权限无法用单元测试证明。** 扩展能否打开用户选中的文件完全取决于 `config/FinderExtension.entitlements` 里的只读权限；去掉它，`selectedItemURLs()` 交出的 URL 就不带读取授权，LaunchServices 会拒绝把任何文件交给任何应用（Apple 问题 rdar://42874694）。改 entitlement 后必须重跑两级探针：

```sh
# 第一级：系统能力。用扩展构建产物的真实 entitlements 签名探针，
# 逐项检查"读文件 / 枚举目录 / 交给应用打开"。
codesign -d --entitlements :- \
  .build/DerivedData/Build/Products/Debug/OneClick.app/Contents/PlugIns/OneClickFinder.appex \
  2>/dev/null > /tmp/ent.plist
codesign --force --deep --sign "$(security find-identity -v -p codesigning | awk 'NR==1{print $2}')" \
  --entitlements /tmp/ent.plist --options runtime .build/ui-review/SandboxProbe.app
.build/ui-review/SandboxProbe.app/Contents/MacOS/SandboxProbe <文件> <目录>

# 第二级：生产代码路径。把 ActionExecutor / SystemWorkspace 的源文件本身编进
# 一个以扩展 entitlements 签名的探针程序（注意必须加 -swift-version 6，否则
# 默认参数的主 actor 隔离会报错），带这条权限与不带各跑一次做对照。
```

第二级才是真正的证据：它跑的是扩展实际执行的代码，而不是探针副本；只改变唯一变量（那条 entitlement）就能得到成功/失败两种结果，因果关系没有别的解释空间。

修改窗口生命周期时，额外验证：连续冷启动多次都应出现设置窗口。`applicationShouldOpenUntitledFile` 对非文档型 App 不会被调用，窗口是由 `applicationDidFinishLaunching` 打开的；单元测试只能覆盖展示请求的转发与重放，不能代替真实启动检查。

## 扩展"已启用但不工作"必须实测

开关状态与扩展进程是两件事，单元测试只能证明两者被分别读取，不能证明真实注册指向哪一份产物。改构建脚本或扩展注册后，按下面三步在真机确认（每一步都要看真实进程，不能只看系统设置里的开关）：

```sh
# 1. 构建脚本应当把扩展拉起来，并指向本次产物
./script/build_and_run.sh --verify
pluginkit -m -v -i local.oneclick.app.finder   # 路径必须是 .build/DerivedData 下刚构建的那份

# 2. 存活判据是进程注册表：app 侧走 NSRunningApplication，shell 侧就是这个
pgrep -f OneClickFinder.appex

# 3. 杀掉扩展模拟"开关还开着但进程已死"，再用恢复路径验证能起来
pkill -f "OneClickFinder.appex/Contents/MacOS/OneClickFinder"
pluginkit -e use -i local.oneclick.app.finder
pgrep -f OneClickFinder.appex
```

第 3 步对应设置窗口状态卡上的「重新加载」按钮，两者走同一条 `pluginkit` 恢复路径。

## 工具栏按钮消失：先看 Finder 偏好，不要先怀疑代码

现象是 Finder 窗口工具栏里没有 OneClick 按钮，容易误判成"扩展没启用"。这个判断是错的——**开关、进程、菜单三者可以都正常，只有按钮不在**。已实测确认过的一次事故与代码无关，排查顺序如下：

```sh
# 1. 三个事实：开关是开的、进程活着、菜单能构造
pluginkit -m -i local.oneclick.app.finder -v          # 行首 + 表示已启用
pgrep -f OneClickFinder.appex
log show --last 5m --info --predicate 'process == "OneClickFinder"' \
  | grep -E "Menu requested|Built menu"               # 右键一次后应出现

# 2. 决定性证据：Finder 的浏览器工具栏里还登记着这个按钮吗
defaults read com.apple.finder "NSToolbar Configuration Browser"
```

若输出里**没有 `TB Item Identifiers` 键**，说明 Finder 的窗口工具栏配置被整体重置过（默认项和扩展项一起没了），而 `FXSyncExtensionToolbarItemsAutomaticallyAdded` 仍记着这个 bundle id —— **Finder 只在首次自动添加，之后永不补**，所以按钮不会自己回来。

恢复办法（会重启 Finder，先备份偏好）：

```sh
cp ~/Library/Preferences/com.apple.finder.plist /tmp/finder.plist.bak
defaults write com.apple.finder FXSyncExtensionToolbarItemsAutomaticallyAdded -array
defaults write com.apple.finder FXSyncExtensionToolbarItemsPendingAdd -array \
  com.aone.keka.KekaFinderIntegration cn.better365.iRightMouse.Extension \
  cn.wflixu.RClick.FinderSyncExt local.oneclick.app.finder
killall Finder
```

重启后 `TB Item Identifiers` 里应重新出现各个扩展项。也可以不用命令：Finder → 右键工具栏 → 自定义工具栏，手动拖回来。

**这条不是 OneClick 的问题。** 同一次事故里 Keka、iRightMouse、RClick 三个第三方扩展的按钮一起消失，说明是 Finder 侧的整体重置。已经验证过完整构建流程（含 `pluginkit -a` 与 `-e use` 重新选举、等待扩展重启）**不会**弄丢按钮，所以不必怀疑 `script/build_and_run.sh` 的注册逻辑。

## 右键菜单外观：不必真的去点右键

菜单是扩展唯一的产品面，但它只能在 Finder 里点开，改文案或图标时没法快速核对。用生产代码把菜单建出来再弹到屏幕上即可预览：

```sh
# 1. 编译 harness（main.swift 必须在独立目录里，顶层代码要求这个名字）
mkdir -p .build/ui-review/menudump
swiftc -O -swift-version 6 -sdk "$(xcrun --sdk macosx --show-sdk-path)" \
  -target arm64-apple-macos26.0 -o .build/ui-review/menudump/menudump \
  .build/ui-review/menudump/main.swift src/shared/core/*.swift src/shared/platform/*.swift

# 2. 配置复制到 /tmp 再读。直接读 App Group 容器会触发「访问其他 App 的数据」授权框，
#    挡住要预览的菜单。
cp ~/Library/Group\ Containers/*.local.oneclick.shared/settings.json /tmp/preview-settings.json
(.build/ui-review/menudump/menudump /tmp/preview-settings.json <某个文件夹> &)
sleep 3 && screencapture -x /tmp/menu.png && pkill -f menudump
```

harness 会先把每项的标题、图标尺寸、是否有分隔符打到 `/tmp/menu-structure.txt`，所以宽度这类问题是**量出来**的，不是看出来的。`-swift-version 6` 不能省，否则默认参数的主 actor 隔离会报错。

## 仍未自动化

以下边界需要真实集成验收，不能用单元测试通过来代替：苹果的签名与授权、Finder 的进程间序列化与工具栏按钮渲染、目标应用实际收到的文件与工作目录。

去掉按 bundle 标识反查应用之后，有两项要真机确认（`ApplicationResolverTests` 只能覆盖到解析这一层）：

- 把某个已导入的应用改名或移到别处，右键菜单里那一项应当**消失**，而不是打开另一个自称同一标识的 bundle。
- Terminal 仍能对文件夹正常工作（它不存路径，走固定的系统位置，是这条规则唯一的例外）。
