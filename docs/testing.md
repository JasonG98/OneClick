# 测试方式

日常开发先运行受影响的 Swift Testing 用例；提交前运行 `./script/check.sh`。修改应用或扩展代码时用 `./script/check.sh --build` 增加真实 Xcode 编译。无需开发证书、Finder 激活或 Computer Use。

## 覆盖范围

| 测试 | 实际运行的生产逻辑 | 替换的系统边界 |
| --- | --- | --- |
| CoreTests | 文件选择、路径编码、配置校验、临时文件读写、过期/损坏请求、主线程桥接、菜单快照 | 无 |
| SettingsModelTests | 初次配置、持久化、开关、拖动及右键排序、应用/目录添加去重移除、刷新、读写错误 | Finder 状态、应用安装查询、通知和错误窗口 |
| FinderMenuTests | NSMenu 构造、可用目标过滤与排序、空白处选择、复制菜单、tag 对应的选择快照 | 应用查询和图标 |
| ActionExecutorTests | 编辑器/Terminal/Claude 分流，目录去重，特殊字符，失效选择，错误传递，复制文本 | NSWorkspace 和系统剪贴板 |
| OpenFlowTests | 发起请求 → 临时文件 → 唤醒链接 → 主应用重新读取配置 → 消费与执行；失败清理、禁止重放、13 类非法链接 | 主应用唤醒、目标应用启动 |
| AppGroupAccessTests | 缺少/错误签名必须在容器访问前失败；正确团队和不可用容器 | 受保护容器查询 |
| ReleaseScripts | 版本、架构、公证与 Cask 生成的输入输出和失败分支 | Apple/Homebrew 外部命令 |

`tests/behavior/TestSupport.swift` 的替身只记录系统调用边界的参数和错误。配置和请求仓库、菜单生成和动作分流始终使用生产实现；每个测试创建独立临时目录并在结束后清理。

## 常用命令

```sh
./script/check.sh
./script/check.sh --build
./script/test.sh --filter ActionExecutorTests
./script/test.sh --filter OpenFlowTests
./script/test.sh --enable-code-coverage
```

SwiftPM 覆盖率文件位于 `.build/core/*/debug/codecov/`。嵌套沙盒环境可追加 `--disable-sandbox`；警告检查可追加 `-Xswiftc -warnings-as-errors`。组合示例：

```sh
./script/check.sh --build --disable-sandbox -Xswiftc -warnings-as-errors
```

编译检查产物独立放在 `.build/Checks`，日志在 `.build/logs/check-build.log`；不替换正在运行的签名开发版。Xcode 会自动注册 macOS 构建产物，脚本通过退出清理撤销检查产物的注册，构建失败时也会清理。

## GUI 验收边界

Computer Use 用于自动化测试无法证明的部分：Finder 实际加载与菜单显示、系统权限对话框、真实应用接收行为、玻璃材质及布局。只有相关系统集成或视觉代码变更时才重测这些项目。设置增删、排序、分流、路径处理和错误分支的日常回归使用上面的测试。

系统替身不能证明 Apple 的签名授权、Finder 的进程间序列化或 Claude Handler 的安装正确；这些边界仍需要少量真实集成验收，不能用单元测试通过来代替。
