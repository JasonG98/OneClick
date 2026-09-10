import Foundation

enum OneClickCoreError: LocalizedError, Equatable {
    case invalidSelection(String)
    case invalidClaudeDirectory(String)
    case invalidSettings(String)
    case malformedSettings
    case unsupportedSettingsVersion(Int)
    case cannotReadSettings
    case cannotSaveSettings
    case invalidOpenRequest(String)
    case openRequestExpired
    case openRequestTooLarge
    case openRequestUnavailable
    case cannotStoreOpenRequest
    case cannotConsumeOpenRequest

    var errorDescription: String? {
        switch self {
        case .invalidSelection(let reason):
            "无法使用所选项目：\(reason)"
        case .invalidClaudeDirectory(let reason):
            "Claude Code 无法打开此目录：\(reason)"
        case .invalidSettings(let reason):
            "配置无效：\(reason)"
        case .malformedSettings:
            "无法读取配置文件，内容已损坏。"
        case .unsupportedSettingsVersion(let version):
            "不支持配置版本 \(version)。"
        case .cannotReadSettings:
            "无法读取配置文件。"
        case .cannotSaveSettings:
            "无法保存配置文件。"
        case .invalidOpenRequest(let reason):
            "打开请求无效：\(reason)"
        case .openRequestExpired:
            "打开请求已过期。"
        case .openRequestTooLarge:
            "打开请求超过大小限制。"
        case .openRequestUnavailable:
            "找不到打开请求，或请求已被处理。"
        case .cannotStoreOpenRequest:
            "无法保存打开请求。"
        case .cannotConsumeOpenRequest:
            "无法读取或移除打开请求。"
        }
    }
}
