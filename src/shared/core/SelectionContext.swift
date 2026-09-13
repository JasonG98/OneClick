import Foundation

struct SelectionContext: Sendable {
    let urls: [URL]

    init(selected: [URL], targeted: URL?, isContainer: Bool) {
        if isContainer {
            urls = targeted.map { [$0] } ?? []
        } else if selected.isEmpty {
            urls = targeted.map { [$0] } ?? []
        } else {
            urls = selected
        }
    }

    /// The raw join, for menu snapshots and comparisons. Writing it to the
    /// clipboard needs `clipboardText()` instead.
    var pathText: String {
        urls.map(\.path).joined(separator: "\n")
    }

    /// The clipboard payload: one absolute path per line.
    ///
    /// The newline doubling as separator is why a path containing one is
    /// refused rather than escaped: escaped, it would be indistinguishable
    /// from two paths, and the paste target is an arbitrary application --
    /// a shell would run the injected line. Nothing here restricts `open`,
    /// which passes URLs and never text, so a file whose name contains a
    /// line break still opens.
    func clipboardText() throws -> String {
        guard let offending = urls.first(where: { $0.path.contains(where: { $0.isNewline }) }) else {
            return pathText
        }
        throw OneClickCoreError.invalidSelection("“\(offending.path.singleLineForm)”的名称包含换行符，无法复制路径。")
    }

    func workingDirectories() throws -> [URL] {
        var directories: [URL] = []
        var seenPaths = Set<String>()

        for url in urls {
            guard url.isLocalFileURL else {
                throw OneClickCoreError.invalidSelection("仅支持本地文件和文件夹。")
            }

            var isDirectory: ObjCBool = false
            guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory) else {
                throw OneClickCoreError.invalidSelection("“\(url.path)”不存在。")
            }

            let directory: URL
            if isDirectory.boolValue {
                directory = url
            } else {
                let resolvedURL = url.resolvingSymlinksInPath()
                let values: URLResourceValues
                do {
                    values = try resolvedURL.resourceValues(forKeys: [.isRegularFileKey])
                } catch {
                    throw OneClickCoreError.invalidSelection("无法读取“\(url.path)”的文件类型。")
                }
                guard values.isRegularFile == true else {
                    throw OneClickCoreError.invalidSelection("“\(url.path)”不是普通文件或文件夹。")
                }
                directory = url.deletingLastPathComponent()
            }

            let key = directory.standardizedFileURL.path
            if seenPaths.insert(key).inserted {
                directories.append(directory)
            }
        }

        return directories
    }
}

extension URL {
    var isLocalFileURL: Bool {
        guard isFileURL, path.hasPrefix("/") else { return false }
        guard let host, !host.isEmpty else { return true }
        return host.caseInsensitiveCompare("localhost") == .orderedSame
    }
}

private extension String {
    /// Names the offending path in an error message without carrying the line
    /// break into it: the message travels to `last-error.txt` and then into
    /// the settings alert.
    var singleLineForm: String {
        replacingOccurrences(of: "\n", with: "⏎").replacingOccurrences(of: "\r", with: "⏎")
    }
}
