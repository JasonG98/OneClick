# 验收记录

## 当前状态

`v0.1.1` 的 [GitHub 发布任务](https://github.com/JasonG98/OneClick/actions/runs/35706502097)通过：
测试、Release 构建、打包及草稿上传完成。下载附件后，校验和、Cask 哈希、只读挂载内容、
静态图标、主程序与扩展的版本、arm64 架构和 ad hoc 签名均通过检查。

Release 和源码仓库均已公开，tap 已收录同一份 Cask。
`brew info --json=v2 --cask JasonG98/tap/oneclick` 解析正确，
`brew fetch --cask JasonG98/tap/oneclick` 下载与哈希校验通过。
此次未安装应用或重新操作真实 Finder。

## 已有桌面证据

此前在 macOS 27 / Apple Silicon 上验证过：ad hoc 应用与扩展启动、真实 home 路径解析、
生产权限下共享目录读写及相邻路径拒绝写入、DMG 内容与签名。
这些观察发生在本轮脚本精简之前，原始范围与限制见[历史验收记录](history/verification.md)。

## 发布前待验

- macOS 26 干净账户的安装、扩展开关、权限提示、重建和重启恢复。
- Finder 菜单点击，以及关闭设置后 Terminal / 编辑器仍能打开目录。
- 浏览器下载带 quarantine 的 DMG，按 README 解锁并使用。
- Homebrew 实际安装、升级和卸载。

旧账户上的成功不能证明干净安装无弹窗，脚本替身测试不能替代桌面验收。
