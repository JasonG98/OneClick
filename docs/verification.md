# 验收记录

## 当前状态

本轮精简验证覆盖自动测试、静态图标接入与应用编译；未重新操作真实 Finder 或触发远程发布。
本地打包结果见[实施记录](implementation-log.md)。

## 已有桌面证据

此前在 macOS 27 / Apple Silicon 上验证过：ad hoc 应用与扩展启动、真实 home 路径解析、
生产权限下共享目录读写及相邻路径拒绝写入、DMG 内容与签名。
这些观察发生在本轮脚本精简之前，原始范围与限制见[历史验收记录](history/verification.md)。

## 发布前待验

- macOS 26 干净账户的安装、扩展开关、权限提示、重建和重启恢复。
- Finder 菜单点击，以及关闭设置后 Terminal / 编辑器仍能打开目录。
- 浏览器下载带 quarantine 的 DMG，按 README 解锁并使用。
- GitHub Actions 草稿产物，以及公开 Homebrew tap 的安装、升级和卸载。

旧账户上的成功不能证明干净安装无弹窗，脚本替身测试不能替代桌面验收。
