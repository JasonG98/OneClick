<div align="center">
<img src="assets/icon.png" width="128" height="128" alt="OneClick">

# OneClick

在 Finder 右键菜单中，用常用应用打开文件夹，或复制文件路径。
</div>

- 支持 Terminal 和自行导入的应用，可调整顺序与开关。
- 支持多选、空白处菜单和工具栏入口。
- 设置窗口关闭即退出，菜单操作由 Finder 扩展完成。无网络请求。

需要 macOS 26+ 和 Apple Silicon。

## 安装与使用

从 [Releases](https://github.com/JasonG98/OneClick/releases) 下载 DMG，将 OneClick 拖入 Applications。
若还没有发布版本，可按下方命令从源码运行。

应用使用 ad hoc 签名，未经 Apple 公证。下载后若被系统拦截，确认来源并核对附件中的 SHA-256，再执行：

```sh
xattr -dr com.apple.quarantine /Applications/OneClick.app
```

首次打开后，到「系统设置 → 通用 → 登录项与扩展 → 文件提供程序」启用 OneClick。
在设置中导入应用、选择覆盖目录，随后在 Finder 中右键使用。
文件夹可用指定应用打开；文件或混选保留系统的「打开方式」，仍可复制路径。

菜单消失时，打开 OneClick，点击底部状态卡重新加载扩展。
部分 iCloud / File Provider 目录受 Finder Sync 限制，可能不显示菜单。

## 开发

安装 Xcode 26+，克隆本仓库后运行；无需 Apple 开发者账号：

```sh
./script/build_and_run.sh
./script/check.sh
```

构建、测试与目录说明见 [CONTRIBUTING.md](CONTRIBUTING.md)，打包见[发布说明](docs/releasing.md)。
图标直接使用 `assets/` 中的静态文件。

## 卸载

先在系统设置关闭扩展。运行 `./script/uninstall.sh` 查看清单，确认后加 `--apply` 执行。
脚本清理可确认归属的应用与当前数据，保留旧版 Group Containers、构建目录及本地配置。
旧版设置需要[手动迁移](docs/releasing.md#旧版配置迁移)。

## 许可证

尚未选定许可证，目前保留所有权利。
