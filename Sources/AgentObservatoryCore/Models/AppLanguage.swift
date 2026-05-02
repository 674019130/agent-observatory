import Foundation

public enum AppLanguage: String, CaseIterable, Codable, Identifiable, Sendable {
    case english = "en"
    case simplifiedChinese = "zh-Hans"

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .english:
            "English"
        case .simplifiedChinese:
            "简体中文"
        }
    }

    public static func fromStoredValue(_ value: String?) -> AppLanguage {
        guard let value, let language = AppLanguage(rawValue: value) else {
            return .english
        }
        return language
    }
}
