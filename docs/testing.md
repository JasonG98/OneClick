# 测试

```sh
./script/check.sh
./script/check.sh --build
./script/check.sh --filter FinderMenuTests
```

默认运行 Swift 测试、Python 脚本测试和 shell 语法检查；`--build` 再进行 arm64 无签名编译，不启动应用。
筛选参数仅影响 Swift 用例。嵌套沙盒可加 `--disable-sandbox`，宏进程限制见[开发指南](../CONTRIBUTING.md)。

## 覆盖范围

| 目录 | 内容 |
| --- | --- |
| `tests/core/` | 设置校验、选区、菜单快照、路径与别名 |
| `tests/behavior/` | 共享目录归属、设置模型、应用解析、菜单与系统调用边界 |
| `tests/release-scripts/` | 构建失败、扩展恢复、打包与草稿、卸载归属和仓库敏感配置 |

脚本测试使用临时仓库、临时 HOME / Applications 及系统工具替身，不接触真实安装或发布服务。
发布测试验证版本、架构、签名、镜像失败恢复、Cask 内容，以及拒绝修改已公开版本。
卸载测试覆盖默认只报告、归属标记与符号链接保护、失败退出和保留旧数据。
静态图标通过应用编译验证接入，不再重绘或做像素比对。

## 桌面验证

涉及系统集成时，用真实 Finder 确认菜单、打开/复制、关闭设置后仍可操作，以及重建后的扩展恢复。
发布前另验首次安装、扩展开关、下载隔离提示和升级。自动测试不能替代这些观察。
已有证据与待验项目见[验收记录](verification.md)。
