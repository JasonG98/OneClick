import Foundation
import Security

enum SharedEnvironment {
    static let appIdentifier = "local.oneclick.app"
    static let extensionIdentifier = "local.oneclick.app.finder"
    static let settingsChanged = Notification.Name("local.oneclick.settings.changed")
    static let errorOccurred = Notification.Name("local.oneclick.error.occurred")

    static func containerURL() throws -> URL {
        guard let identifier = Bundle.main.object(forInfoDictionaryKey: "OneClickAppGroup") as? String,
              let team = signingTeam, identifier.hasPrefix(team + "."),
              let url = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: identifier) else {
            throw PlatformError.sharedContainerUnavailable
        }
        return url
    }

    // Check before touching a protected container. An ad hoc build has no team
    // membership and must never turn repeated refreshes into macOS TCC prompts.
    private static let signingTeam: String? = {
        var code: SecCode?
        guard SecCodeCopySelf([], &code) == errSecSuccess, let code else { return nil }
        var staticCode: SecStaticCode?
        guard SecCodeCopyStaticCode(code, [], &staticCode) == errSecSuccess, let staticCode else { return nil }
        var information: CFDictionary?
        guard SecCodeCopySigningInformation(staticCode, SecCSFlags(rawValue: kSecCSSigningInformation), &information) == errSecSuccess,
              let values = information as? [String: Any],
              let team = values[kSecCodeInfoTeamIdentifier as String] as? String,
              !team.isEmpty else { return nil }
        return team
    }()

    static func repository() throws -> SettingsRepository {
        SettingsRepository(fileURL: try containerURL().appendingPathComponent("settings.json"))
    }

    static func report(_ error: Error) {
        guard let container = try? containerURL() else { return }
        try? Data(error.localizedDescription.utf8).write(to: container.appendingPathComponent("last-error.txt"), options: .atomic)
    }

    static func takeError() -> String? {
        guard let container = try? containerURL() else { return nil }
        let url = container.appendingPathComponent("last-error.txt")
        guard let data = try? Data(contentsOf: url) else { return nil }
        try? FileManager.default.removeItem(at: url)
        return String(data: data, encoding: .utf8)
    }
}

enum PlatformError: LocalizedError {
    case sharedContainerUnavailable
    case applicationUnavailable(String)
    case emptySelection
    case clipboardUnavailable

    var errorDescription: String? {
        switch self {
        case .sharedContainerUnavailable: "共享配置需要有效的 Apple 开发者签名，且主应用和 Finder 扩展必须属于同一团队。请配置 DEVELOPMENT_TEAM 后重新构建。"
        case .applicationUnavailable(let name): "无法打开 \(name)。请确认应用已安装，并在 OneClick 中重新选择。"
        case .emptySelection: "没有可操作的文件或文件夹。"
        case .clipboardUnavailable: "暂时无法写入剪贴板，请重试。"
        }
    }
}
