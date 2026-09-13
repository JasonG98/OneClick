import Foundation

struct SettingsRepository: Sendable {
    private let fileURL: URL

    init(fileURL: URL) {
        self.fileURL = fileURL
    }

    func loadOrCreate(initial: Settings) throws -> Settings {
        if FileManager.default.fileExists(atPath: fileURL.path) { return try load() }
        try save(initial)
        return initial
    }

    func load() throws -> Settings {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return Settings()
        }

        let data: Data
        do {
            data = try Data(contentsOf: fileURL)
        } catch {
            throw OneClickCoreError.cannotReadSettings
        }

        let decoded: Settings
        do {
            decoded = try JSONDecoder().decode(Settings.self, from: data)
        } catch {
            throw OneClickCoreError.malformedSettings
        }

        let settings = migrated(decoded)
        try validate(settings)
        return settings
    }

    /// Drops presets that earlier versions shipped and this one no longer
    /// supports. Applications imported by the user carry an `applicationURL` and
    /// are never touched. Migration runs before validation so a configuration
    /// holding nothing but retired presets still loads.
    private func migrated(_ settings: Settings) -> Settings {
        var settings = settings
        let retiredPresets: [String: String] = [
            "vscode": "com.microsoft.VSCode",
            "cursor": "com.todesktop.230313mzl4w4u92",
            "sublime": "com.sublimetext.4",
            "claude": "com.anthropic.claude-code-url-handler",
        ]
        let countBefore = settings.targets.count
        settings.targets.removeAll { target in
            target.applicationURL == nil
                && retiredPresets[target.id].map { $0 == target.bundleIdentifier } == true
        }
        // Only touch the list when something actually had to be removed. A
        // configuration the user curated must not gain targets behind their
        // back, and a list they deliberately emptied has to stay empty.
        guard settings.targets.count != countBefore else { return settings }

        guard !settings.targets.isEmpty else {
            settings.targets = OpenTarget.builtIns
            return settings
        }
        // The rewrite above means this configuration predates the current
        // built-ins, so make sure they are represented. Terminal used to be a
        // removable preset and is a built-in now.
        for builtIn in OpenTarget.builtIns where !settings.targets.contains(where: { $0.id == builtIn.id }) {
            settings.targets.append(builtIn)
        }
        return settings
    }

    func save(_ settings: Settings) throws {
        try validate(settings)

        let data: Data
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.sortedKeys]
            data = try encoder.encode(settings)
        } catch {
            throw OneClickCoreError.cannotSaveSettings
        }

        do {
            try FileManager.default.createDirectory(
                at: fileURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            try data.write(to: fileURL, options: .atomic)
        } catch {
            throw OneClickCoreError.cannotSaveSettings
        }
    }

    private func validate(_ settings: Settings) throws {
        guard settings.version == 1 else {
            throw OneClickCoreError.unsupportedSettingsVersion(settings.version)
        }
        // An empty target list is a legitimate choice — the user may want only
        // the copy-path action — so it is no longer treated as invalid.

        var targetIDs = Set<String>()
        for target in settings.targets {
            let id = target.id.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !id.isEmpty else {
                throw OneClickCoreError.invalidSettings("目标标识不能为空。")
            }
            guard targetIDs.insert(id).inserted else {
                throw OneClickCoreError.invalidSettings("目标标识“\(id)”重复。")
            }
            guard !target.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw OneClickCoreError.invalidSettings("目标名称不能为空。")
            }

            let bundleIdentifier = try validatedBundleIdentifier(target.bundleIdentifier)
            if let applicationURL = target.applicationURL {
                // Climbing components are rejected; canonical equality is
                // deliberately not required. `URL` equality is sensitive to
                // `hasDirectoryPath`, and a Codable round trip adds a trailing
                // slash, so demanding it would make already-saved good
                // configuration unreadable.
                guard applicationURL.isLocalFileURL,
                      !applicationURL.pathComponents.contains(".."),
                      applicationURL.pathExtension.caseInsensitiveCompare("app") == .orderedSame else {
                    throw OneClickCoreError.invalidSettings("“\(target.name)”的应用路径必须是规范化的本地绝对 .app 路径。")
                }
            }

            switch target.kind {
            case .application:
                guard bundleIdentifier != nil || target.applicationURL != nil else {
                    throw OneClickCoreError.invalidSettings("“\(target.name)”缺少应用标识或应用路径。")
                }
            case .terminal:
                guard bundleIdentifier == "com.apple.Terminal",
                      target.applicationURL == nil else {
                    throw OneClickCoreError.invalidSettings("Terminal 目标必须使用系统终端。")
                }
            }
        }

        for directory in settings.directories {
            guard directory.isLocalFileURL else {
                throw OneClickCoreError.invalidSettings("监控目录必须是本地绝对路径。")
            }

            var isDirectory: ObjCBool = false
            if FileManager.default.fileExists(atPath: directory.path, isDirectory: &isDirectory) {
                guard isDirectory.boolValue else {
                    throw OneClickCoreError.invalidSettings("监控路径“\(directory.path)”不是文件夹。")
                }
            } else if !directory.hasDirectoryPath {
                throw OneClickCoreError.invalidSettings("监控路径“\(directory.path)”必须表示文件夹。")
            }
        }
    }

    private func validatedBundleIdentifier(_ value: String?) throws -> String? {
        guard let value else { return nil }
        let identifier = value.trimmingCharacters(in: .whitespacesAndNewlines)
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: ".-"))
        guard !identifier.isEmpty,
              identifier.rangeOfCharacter(from: allowed.inverted) == nil,
              !identifier.hasPrefix("."),
              !identifier.hasSuffix(".") else {
            throw OneClickCoreError.invalidSettings("应用标识格式无效。")
        }
        return identifier
    }
}
