import Foundation

enum SharedEnvironment {
    static let appIdentifier = "local.oneclick.app"
    static let settingsChanged = Notification.Name("local.oneclick.settings.changed")
    static let errorOccurred = Notification.Name("local.oneclick.error.occurred")

    static func repository() throws -> SettingsRepository {
        SettingsRepository(fileURL: try SharedDirectory.prepare().appendingPathComponent("settings.json"))
    }

    /// `last-error.txt` sits in the shared directory, which any process
    /// running as this user can write, and whatever it holds is rendered in the
    /// settings alert. Neither its length nor its encoding is ours to assume,
    /// so both ends are bounded: characters because of the alert, bytes
    /// because of the read.
    static let errorTextCharacterLimit = 500
    static let errorTextByteLimit = 64 * 1024

    static func boundedErrorText(_ text: String, limit: Int = errorTextCharacterLimit) -> String {
        guard text.count > limit else { return text }
        // `prefix` counts Characters, so a multi-byte script is not cut mid-scalar.
        return String(text.prefix(limit)) + "…"
    }

    /// Reads with a ceiling. `Data(contentsOf:)` would load a huge file whole,
    /// which kills the process before anything gets a chance to truncate it.
    static func errorText(readingFrom url: URL, limit: Int = errorTextByteLimit) -> String? {
        guard let handle = try? FileHandle(forReadingFrom: url) else { return nil }
        defer { try? handle.close() }
        guard let data = try? handle.read(upToCount: limit), !data.isEmpty else { return nil }
        // Decoding rather than `String(data:encoding:)`: invalid bytes become
        // replacement characters instead of making the message disappear.
        return String(decoding: data, as: UTF8.self)
    }

    static func report(_ error: Error) {
        guard let directory = try? SharedDirectory.prepare() else { return }
        report(error, in: directory)
    }

    static func report(_ error: Error, in directory: URL) {
        let text = boundedErrorText(error.localizedDescription)
        try? Data(text.utf8).write(to: directory.appendingPathComponent("last-error.txt"), options: .atomic)
    }

    static func takeError() -> String? {
        guard let directory = try? SharedDirectory.prepare() else { return nil }
        return takeError(in: directory)
    }

    static func takeError(in directory: URL) -> String? {
        let url = directory.appendingPathComponent("last-error.txt")
        guard let text = errorText(readingFrom: url) else { return nil }
        try? FileManager.default.removeItem(at: url)
        return boundedErrorText(text)
    }
}

enum PlatformError: LocalizedError, Equatable {
    case sharedDirectoryUnavailable
    case applicationUnavailable(String)
    case emptySelection
    case clipboardUnavailable

    var errorDescription: String? {
        switch self {
        case .sharedDirectoryUnavailable: "无法访问 ~/Library/Application Support/OneClick/。请检查目录权限和归属标记；若目录已有其他数据，请先备份并移走后重试。"
        case .applicationUnavailable(let name): "无法打开 \(name)。请确认应用已安装，并在 OneClick 中重新选择。"
        case .emptySelection: "没有可操作的文件或文件夹。"
        case .clipboardUnavailable: "暂时无法写入剪贴板，请重试。"
        }
    }
}
