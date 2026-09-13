import Foundation

/// 名字太长、菜单里该用短名显示的应用。
///
/// 菜单会在名字前面加动词（`用 … 打开`），"Visual Studio Code" 这种全名几乎占满
/// 一整行，而用户平时就叫它 VS Code。别名按 **bundle id** 匹配：应用从哪个目录导入
/// 都命中，配置里存的就是这个 id。
///
/// 扩展方式：加一条。`shortName` 必须比应用自己的名字短（测试会断言这条），
/// bundle id 一律从真实来源读出来，不要凭记忆写：
///     /usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' /Applications/<App>.app/Contents/Info.plist
/// 查不到已安装的应用时，用厂商的发行渠道核对（例如 Homebrew Cask 的
/// `uninstall quit:` 与 `zap` 里会写出真实 bundle id）。核不到就不要收录。
///
/// 只收录能用来"打开文件夹"的应用：菜单里的应用项只在目录选区出现，
/// 浏览器、聊天工具之类不会走到这里。
enum ApplicationAlias {
    struct Entry: Sendable {
        let bundleIdentifier: String
        /// 应用自己的显示名。只用于说明这一条是谁、以及"短名确实更短"的断言，
        /// 不参与匹配 —— 匹配只看 bundle id。
        let applicationName: String
        let shortName: String
    }

    /// 可见性故意留 internal：测试要检查这张表自身的约定。
    static let entries: [Entry] = [
        Entry(
            bundleIdentifier: "com.microsoft.VSCode",
            applicationName: "Visual Studio Code",
            shortName: "VS Code"
        ),
        Entry(
            bundleIdentifier: "com.microsoft.VSCodeInsiders",
            applicationName: "Visual Studio Code - Insiders",
            shortName: "VS Code Insiders"
        ),
        Entry(
            bundleIdentifier: "com.sublimetext.4",
            applicationName: "Sublime Text",
            shortName: "Sublime"
        ),
        Entry(
            bundleIdentifier: "com.jetbrains.intellij",
            applicationName: "IntelliJ IDEA",
            shortName: "IDEA"
        ),
        Entry(
            bundleIdentifier: "com.jetbrains.intellij.ce",
            applicationName: "IntelliJ IDEA CE",
            shortName: "IDEA CE"
        ),
    ]

    /// 没有别名时返回 `nil`，由调用方回退到应用自己的名字。
    static func shortName(forBundleIdentifier identifier: String?) -> String? {
        guard let identifier else { return nil }
        return entries.first { $0.bundleIdentifier == identifier }?.shortName
    }
}
