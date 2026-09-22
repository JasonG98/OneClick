# 开发 OneClick

需要 macOS 26+、Apple Silicon 和完整 Xcode 26+。脚本使用系统 Python 3 与 Ruby，无额外 Python 依赖。
两个 target 均使用 ad hoc 签名，无需开发者账号。旧 `config/Local.xcconfig` 不再读取。

## 常用命令

```sh
./script/build_and_run.sh              # 构建、启动并确认扩展运行
./script/build_and_run.sh --build-only # 只构建和检查签名
./script/check.sh                      # Swift、脚本测试与 shell 语法检查
./script/check.sh --build              # 再编译主程序和扩展，不签名、不启动
```

首次运行需在系统设置中启用 Finder 扩展。调试构建位于
`.build/DerivedData/Build/Products/Debug/OneClick.app`，日志在 `.build/logs/build.log`。

`check.sh` 将其他参数传给 `swift test`，例如 `--filter FinderMenuTests`。
嵌套沙盒中可加 `--disable-sandbox`；若 Xcode 的 Swift 宏仍无法启动，需在外层环境构建，勿修改应用权限。
文档改动检查链接、命令及 `git diff --check` 即可。[测试说明](docs/testing.md)列出覆盖范围。

## 目录与修改约定

- `src/app/`：SwiftUI 设置窗口；`src/finder-extension/`：Finder 菜单与操作。
- `src/shared/core/`：纯逻辑；`src/shared/platform/`：macOS 集成。保持这些边界。
- `assets/`：静态图标与 `Assets.xcassets`；直接替换素材，不再维护绘制或生成脚本。
- `config/`：plist、权限与签名配置；`tests/`：测试；`script/`：五个开发维护入口。

工程设置修改 `script/generate_project.py` 后运行它，并确认连续两次生成结果一致。
新增 Swift 文件会由 Xcode 同步目录自动接入；移动文件时同步 `Package.swift` 的显式路径。

涉及进程、权限、存储或菜单时查阅[运行约束](docs/runtime-invariants.md)。
有意义的修改与验证写入[实施记录](docs/implementation-log.md)，真实桌面观察写入[验收记录](docs/verification.md)。
发布使用 `python3 script/release.py VERSION`，详见[发布说明](docs/releasing.md)。
