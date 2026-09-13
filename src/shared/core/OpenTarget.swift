import Foundation

enum TargetKind: String, Codable, Sendable {
    case application
    case terminal

    /// Retired kinds decode as a plain application so a configuration written by
    /// an older version can still be read. The load migration then drops the
    /// retired preset instead of failing the whole file, which would leave the
    /// user with a menu that never appears again.
    init(from decoder: any Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        self = TargetKind(rawValue: raw) ?? .application
    }
}

struct OpenTarget: Codable, Identifiable, Equatable, Sendable {
    var id: String
    var name: String
    var kind: TargetKind
    var bundleIdentifier: String?
    var applicationURL: URL?
    var isEnabled: Bool

    /// Finder 菜单里显示的名字：有别名用别名，否则用应用自己的名字。
    ///
    /// 与 `name` 故意分开：设置窗口、无障碍标签和报错文案要的是应用的身份
    /// （和 `/Applications` 里那个名字对得上才找得到），菜单要的是一行读得完的
    /// 短名。别名是**派生**的，不写进配置，所以 settings.json 不需要迁移；
    /// 将来若要支持用户自定义显示名，在 `??` 前面插一个字段即可，其余代码不动。
    var menuName: String {
        ApplicationAlias.shortName(forBundleIdentifier: bundleIdentifier) ?? name
    }

    /// Terminal is the only built-in target; every other application is imported
    /// by the user from `/Applications`.
    static let builtIns: [OpenTarget] = [
        OpenTarget(
            id: "terminal",
            name: "Terminal",
            kind: .terminal,
            bundleIdentifier: "com.apple.Terminal",
            applicationURL: nil,
            isEnabled: true
        ),
    ]
}

struct Settings: Codable, Equatable, Sendable {
    var version: Int = 1
    var targets: [OpenTarget] = OpenTarget.builtIns
    var directories: [URL] = []

    static func initial(home: URL) -> Settings {
        Settings(directories: [home])
    }
}
