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

    var pathText: String {
        urls.map(\.path).joined(separator: "\n")
    }

    func workingDirectories() throws -> [URL] {
        var directories: [URL] = []
        var seenPaths = Set<String>()

        for url in urls {
            guard url.isFileURL, url.isLocalFileURL else {
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
