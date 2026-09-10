import Foundation

enum OneClickCoreError: LocalizedError, Equatable {
    case invalidSelection(String)
    case invalidSettings(String)
    case malformedSettings
    case unsupportedSettingsVersion(Int)
    case cannotReadSettings
    case cannotSaveSettings

    var errorDescription: String? {
        switch self {
        case .invalidSelection(let reason):
            "无法使用所选项目：\(reason)"
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
        }
    }
}
