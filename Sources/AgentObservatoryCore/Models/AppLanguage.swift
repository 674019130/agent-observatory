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

    public static func fromStoredValue(
        _ value: String?,
        preferredLanguages: [String] = Locale.preferredLanguages
    ) -> AppLanguage {
        guard let value, let language = AppLanguage(rawValue: value) else {
            return systemDefault(preferredLanguages: preferredLanguages)
        }
        return language
    }

    public static func systemDefault(preferredLanguages: [String] = Locale.preferredLanguages) -> AppLanguage {
        for preferredLanguage in preferredLanguages {
            let normalized = preferredLanguage.lowercased()
            if normalized.hasPrefix("zh-hans") || normalized == "zh_cn" || normalized == "zh-cn" {
                return .simplifiedChinese
            }
            if normalized.hasPrefix("en") {
                return .english
            }
        }
        return .english
    }
}
