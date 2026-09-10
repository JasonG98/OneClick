# OneClick 实施记录

## 2026-09-10

- 用户确认 Finder Sync、原生 Liquid Glass 配置窗口、macOS 26+、仅 arm64；设计阶段结束，开始实施。
- 在空项目初始化 `feat/oneclick` 开发分支，直接使用当前专属项目目录。
- 按文件所有权拆分工作：子代理负责 `src/shared/core` 与纯行为测试；主代理负责 Xcode、平台集成、SwiftUI、运行验证及分发脚本。
- 测试以零依赖 Swift Package 执行，共享核心源文件同时编入主应用与扩展。这样测试不依赖 Finder 进程或图形会话。Xcode 工程保留两个产品 target，替代计划中另建 Xcode 测试 target 的工程组织。
- Xcode 初始构建阻碍：IDESimulatorFoundation 要求 DVTDownloads 中的符号，系统版本缺失该符号。Xcode 随附安装包中的对应框架包含该符号；仅调整 DYLD_FRAMEWORK_PATH 未生效，已调用官方 `xcodebuild -runFirstLaunch` 修复流程。
- Computer Use 返回“Computer Use permissions are not granted”。在授权可用前不将 GUI、Finder 菜单或玻璃外观写成已验证。

## 进度

- 核心选择语义与配置：完成，40 项 Swift Testing 通过。
- Finder 与系统动作：菜单、复制、Terminal、编辑器及主应用唤醒已实测；Claude Handler 本机不可用。
- 配置窗口：已实现并验收基本交互，详细覆盖见 `docs/verification.md`。
- Homebrew 分发准备：脚本与 6 项行为测试完成；真实公开发布待 Developer ID、公证配置与仓库地址。

## 实测调整

- Finder 菜单通过 tag 保存选择快照，避免 Finder IPC 丢失 representedObject。
- 崩溃栈证实 Finder 菜单回调在后台 XPC 队列，改用可测试的主线程桥接。
- Terminal 的扩展内直接打开失败，采用设计中的主应用执行后备路径：一次性类型化请求 + 自有 URL 唤醒。
- 用户报告反复“访问其他 App 数据”弹窗。立即暂停 OneClick 并停止开发进程，TCC 日志确认无有效 App Group 授权的 ad hoc 签名是问题来源。随后检测到 Apple Development 证书，读取证书 OU 作为真实 Team ID，配置有效签名与团队前缀共享组。
- Debug 和 Release 归档均通过嵌套签名及 arm64 校验；签名修复后的最后 10 分钟未发现 OneClick TCC 提示请求。
- 测试和发布凭据不进入 Git。旧设计文档是历史决策，实际覆盖与剩余工作以验收记录为准。

## 自动化验证补齐

- 根据用户反馈，日常验证改为先跑自动化测试和命令行构建，Computer Use 仅用于必要的真实系统接入和视觉验收。
- 增加 24 项行为测试，直接执行配置模型、NSMenu 构造、动作分流和一次性请求流程；只替换应用启动、系统剪贴板和权限查询等外部边界。
- 增加统一入口 `script/check.sh` 和 `docs/testing.md`。64 项 Swift 测试、6 项脚本测试与 arm64 编译通过，六个临时回归均被测试捕获。本轮没有 GUI 自动化操作。
