import Foundation

enum ClaudeLink {
    static func make(directory: URL) throws -> URL {
        guard directory.isLocalFileURL else {
            throw OneClickCoreError.invalidClaudeDirectory("仅支持本地文件夹。")
        }

        let path = directory.path
        guard !directory.pathComponents.contains("..") else {
            throw OneClickCoreError.invalidClaudeDirectory("路径不能包含“..”。")
        }
        guard !path.unicodeScalars.contains(where: \.isInvisibleOrBidiControl) else {
            throw OneClickCoreError.invalidClaudeDirectory("路径包含不受支持的控制字符。")
        }

        if let values = try? directory.resourceValues(forKeys: [.volumeIsLocalKey]),
           values.volumeIsLocal == false {
            throw OneClickCoreError.invalidClaudeDirectory("网络磁盘路径不受支持。")
        }

        var components = URLComponents()
        components.scheme = "claude-cli"
        components.host = "open"
        components.queryItems = [URLQueryItem(name: "cwd", value: path)]
        components.percentEncodedQuery = components.percentEncodedQuery?
            .replacingOccurrences(of: "+", with: "%2B")
        guard let url = components.url else {
            throw OneClickCoreError.invalidClaudeDirectory("无法生成安全的启动链接。")
        }
        return url
    }
}

private extension Unicode.Scalar {
    var isInvisibleOrBidiControl: Bool {
        switch properties.generalCategory {
        case .control, .format, .lineSeparator, .paragraphSeparator:
            true
        default:
            false
        }
    }
}
