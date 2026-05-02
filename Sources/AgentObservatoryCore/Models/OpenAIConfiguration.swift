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
    public static let defaultModel = "gpt-4.1"
    public static let defaultBaseURL = "https://api.openai.com/v1"

    public static func normalizedModel(_ value: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? defaultModel : trimmed
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
