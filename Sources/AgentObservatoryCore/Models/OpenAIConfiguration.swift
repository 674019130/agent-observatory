import Foundation

public enum OpenAIConfigurationError: LocalizedError, Equatable, Sendable {
    case invalidBaseURL(String)

    public var errorDescription: String? {
        switch self {
        case .invalidBaseURL(let value):
            "Invalid OpenAI base URL: \(value)"
        }
    }
}

public struct OpenAIConfiguration: Sendable {
    public static let defaultModel = OpenAIModelPreset.frontier.modelID
    public static let defaultBaseURL = "https://api.openai.com/v1"

    public static func normalizedModel(_ value: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? defaultModel : trimmed
    }

    public static func normalizedStoredModel(_ value: String?) -> String {
        let normalized = normalizedModel(value ?? "")
        let legacyDefaults: Set<String> = [
            "gpt-4.1",
            "gpt-4.1-mini"
        ]
        return legacyDefaults.contains(normalized) ? defaultModel : normalized
    }

    public static func normalizedBaseURL(_ value: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return defaultBaseURL }

        var normalized = trimmed
        while normalized.hasSuffix("/") {
            normalized.removeLast()
        }
        return normalized
    }

    public static func responsesEndpoint(baseURL: String) throws -> URL {
        let normalized = normalizedBaseURL(baseURL)
        guard var components = URLComponents(string: normalized),
              let scheme = components.scheme,
              ["http", "https"].contains(scheme.lowercased()),
              components.host != nil else {
            throw OpenAIConfigurationError.invalidBaseURL(baseURL)
        }

        var path = components.path
        while path.hasSuffix("/") && path.count > 1 {
            path.removeLast()
        }

        if components.host == "api.openai.com", path.isEmpty || path == "/" {
            path = "/v1"
        }

        if path.hasSuffix("/responses") {
            components.path = path
        } else if path.isEmpty || path == "/" {
            components.path = "/responses"
        } else {
            components.path = "\(path)/responses"
        }

        guard let url = components.url else {
            throw OpenAIConfigurationError.invalidBaseURL(baseURL)
        }
        return url
    }
}

public enum OpenAIModelPreset: String, CaseIterable, Identifiable, Sendable {
    case frontier
    case mini
    case nano

    public var id: String { rawValue }

    public var modelID: String {
        switch self {
        case .frontier:
            "gpt-5.5"
        case .mini:
            "gpt-5.4-mini"
        case .nano:
            "gpt-5.4-nano"
        }
    }

    public var title: String {
        switch self {
        case .frontier:
            "GPT-5.5"
        case .mini:
            "GPT-5.4 mini"
        case .nano:
            "GPT-5.4 nano"
        }
    }

    public var summary: String {
        switch self {
        case .frontier:
            "Best quality for planning and complex organization."
        case .mini:
            "Balanced latency and cost for routine cleanup plans."
        case .nano:
            "Lowest-cost option for quick classification-style passes."
        }
    }
}
