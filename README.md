<div align="center">

<img src="assets/icon.png" width="128" height="128" alt="OneClick">

# OneClick

Finder 右键菜单增强：选中文件或文件夹，直接用 Terminal、编辑器打开，或复制绝对路径。

</div>

选中文件夹想用 VS Code 打开，标准流程是「右键 → 打开方式 → 其他… → 找到应用 → 打开」；想拿一个路径，得先开终端敲 `pwd`。OneClick 把这些压到一次右键里。

要求 macOS 26+ 和 Apple Silicon，从源码构建需要 Xcode 26。无第三方依赖，无网络代码。

## 从源码构建

目前没有编译好的下载版本（见[发布状态](#发布状态)），只能从源码装：

```sh
git clone <仓库地址> && cd OneClick
printf 'DEVELOPMENT_TEAM = 你的十位TeamID\n' > config/Local.xcconfig
./script/build_and_run.sh --verify
```

`Local.xcconfig` 不进 Git。团队签名是硬要求：主程序和扩展靠 App Group 共享配置，ad hoc 签名会反复弹「访问其他 App 数据」。没有证书也可以 `./script/build_and_run.sh --build-only` 只编译，或跑 `./script/check.sh` 的测试。

首次打开 OneClick 后，按窗口底部的提示到「系统设置 → 通用 → 登录项与扩展 → 文件提供程序」启用扩展。系统初始化可能要几秒，之后 Finder 工具栏会出现 OneClick 按钮。

## 用法

- 选中**文件夹**右键：「用 XX 打开」（Terminal、你导入的应用）、「复制路径」（复制到剪贴板的是绝对路径，多选时每行一个）
- 在**空白处**右键：作用于当前目录；对文件取父目录，多选目录自动去重
- 选中**文件**或混选：交给系统「打开方式」，OneClick 不抢 —— 系统自己已经做得够好，「复制路径」照常可用
- **工具栏按钮**：常驻入口，没有选区时也能打开菜单和设置

前 3 个启用的应用直接显示，其余收进「用其他应用打开」子菜单，菜单不会越用越长。

名字太长会换短名：`用 VS Code 打开` 而不是 `用 Visual Studio Code 打开`（同理有 VS Code Insiders、Sublime、IntelliJ）。短名只影响右键菜单，配置窗口里仍是应用自己的全名。

配置窗口里可以导入 `.app`、调整顺序和开关、增减覆盖目录（默认是主目录及子目录）。改动即时生效，不用重启 Finder。

## 工作方式

主程序只是一个配置窗口，关掉就退出，不常驻后台。菜单构造和打开动作全部在 Finder 扩展进程里完成，平时只有这一个扩展进程，实测物理内存约 5.7 MB。

```text
┌────────────────────────┐        分布式通知        ┌──────────────────────────┐
│  OneClick.app          │ ───────────────────────▶ │  OneClickFinder.appex    │
│  SwiftUI 配置窗口       │   配置变更 / 错误回报     │  跑在 Finder 进程里       │
│  只在打开时运行          │ ◀─────────────────────── │  构造菜单、执行打开动作    │
└───────────┬────────────┘                          └────────────┬─────────────┘
            │            App Group（共享配置）                    │
            └───────────────────────────────────────────────────┘
```

菜单按当前选区现场构造：文件、文件夹、空白处、多选各有语义，反映的是此刻的状态。

**一条需要说明的权限。** macOS 有个已知问题（rdar://42874694）：Finder 把选中的文件交给扩展时，不附带读取这些文件的授权，导致扩展无法把文件转交给任何应用 —— Terminal 和编辑器一样打不开。因此扩展声明了一条只读的文件访问权限，第一次启用时系统弹的「访问文件」提示就是它。这条权限只给扩展、只读；主程序不参与文件操作。取舍细节见 [AGENTS.md](AGENTS.md#runtime-invariants)。

## 完全卸载

`script/uninstall.sh` 会清掉这个应用在这台 Mac 上留下的全部痕迹。**默认只报告、不删除**，先把要删的东西打出来给你看；确认无误再加 `--apply`：

```sh
./script/uninstall.sh                    # 报告：会删什么，一行一项，什么都不动
./script/uninstall.sh --apply            # 执行
./script/uninstall.sh --apply --build    # 连同 .build/、dist/（Xcode 与本仓库的产物）
```

它会处理：运行中的主程序与 Finder 扩展进程、LaunchServices 与 PluginKit 注册、**每一份** `OneClick.app`（包括 Xcode 的 DerivedData 副本）、App Group 共享容器、扩展的沙盒容器、偏好设置与缓存、登录项（本应用不注册，但脚本会核对）。

两点值得知道：

- **先关扩展再卸载。** 如果扩展还开着，先在「系统设置 → 通用 → 登录项与扩展 → 文件提供程序」关掉它。系统设置里只有开关、没有删除按钮，所以这一步是"卸载干净"的必要条件，脚本无法代劳（它只能在报告里提醒你）。
- **它不会乱删。** 归属判断读的是容器管理器自己写的元数据（`MCMMetadataCreator`），不是目录名 —— 名字里带 `oneclick` 但不属于本应用的容器会被跳过；`OneClick.app` 也必须 `CFBundleIdentifier` 匹配才会被删。卸载完成后按脚本提示 `killall Finder`，工具栏按钮随之消失。

## 常见问题

**右键菜单没了，系统设置里开关却是开的？**
扩展进程退出了，Finder 不会自动重启它。打开 OneClick 配置窗口，点底部状态卡重新加载即可。开发时 `build_and_run.sh` 每次构建后也会自动处理。

**为什么有的目录里没有菜单？**
Finder Sync 对 iCloud、File Provider、应用程序目录和扩展重叠有自己的限制，启用不代表每个目录都有菜单。默认覆盖主目录及子目录，可在配置里增减。参考 [Apple 论坛的相关讨论](https://developer.apple.com/forums/thread/756711)。

**为什么限定 macOS 26 和 Apple Silicon？**
界面用了 macOS 26 的 SwiftUI 新材质，工程按 arm64 单架构构建。

**会上传我的文件吗？**
不会。没有网络请求，没有遥测；扩展只在点击菜单项时读取选区路径，交给剪贴板或你选的应用。共享容器只用来同步配置。

## 开发

```sh
./script/check.sh          # Swift 测试 + 脚本测试 + 图标校对 + shell 语法检查
./script/check.sh --build  # 再编译主应用与扩展，不签名、不启动
./script/check.sh --filter FinderMenuTests     # 参数透传给 swift test
./script/build_and_run.sh --verify             # 构建并确认进程存活
./script/build_and_run.sh --telemetry          # 跟随 OneClick 的系统日志
```

产物在 `.build/DerivedData/Build/Products/Debug/OneClick.app`，构建日志在 `.build/logs/build.log`。图标源文件是 [`assets/icon.svg`](assets/icon.svg)，改完跑 `python3 script/generate_icon.py` 重新生成，`check.sh` 会核对输出与美术稿一致。

目录结构、运行时约束和踩坑记录在 [AGENTS.md](AGENTS.md)；测试细节见 [docs/testing.md](docs/testing.md)。

## 发布状态

目标是自有 tap 的 Homebrew Cask。签名、公证、ZIP 与 Cask 生成脚本已就绪，还缺 Developer ID 证书、公证配置和最终仓库地址，**尚未发布公开下载版本**。流程见 [docs/releasing.md](docs/releasing.md)。

## 许可证

尚未选定（暂无 `LICENSE` 文件，默认保留所有权利）。公开发布前会补上；在那之前如需使用或分发，请先开 issue 说明用途。

## 相关文档

[实施记录](docs/implementation-log.md) · [测试说明](docs/testing.md) · [验收记录](docs/verification.md) · [发布说明](docs/releasing.md) · [项目约定](AGENTS.md)
