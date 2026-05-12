import Foundation

public enum OpenAIEnricherError: LocalizedError, Sendable {
    case missingAPIKey
    case invalidResponse
    case requestFailed(String)
    case invalidBaseURL(String)

    public var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            "OpenAI API key is missing."
        case .invalidResponse:
            "OpenAI returned a response the app could not read."
        case .requestFailed(let message):
            message
        case .invalidBaseURL(let value):
            "Invalid OpenAI base URL: \(value)"
        }
    }
}

public struct OpenAIEnricher: Sendable {
    private let session: URLSession

    public init(session: URLSession = .shared) {
        self.session = session
    }

    public func summarize(
        asset: AgentAsset,
        apiKey: String,
        model: String,
        baseURL: String = OpenAIConfiguration.defaultBaseURL,
        language: AppLanguage = AppLanguage.systemDefault()
    ) async throws -> String {
        let trimmedKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedKey.isEmpty else { throw OpenAIEnricherError.missingAPIKey }
        let endpoint: URL
        do {
            endpoint = try OpenAIConfiguration.responsesEndpoint(baseURL: baseURL)
        } catch {
            throw OpenAIEnricherError.invalidBaseURL(baseURL)
        }

        let input = try prompt(for: asset)
        let payload: [String: Any] = [
            "model": model,
            "store": false,
            "max_output_tokens": 320,
            "instructions": instructions(language: language),
            "input": input
        ]

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.addValue("Bearer \(trimmedKey)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw OpenAIEnricherError.invalidResponse
        }

        guard (200..<300).contains(httpResponse.statusCode) else {
            let body = SecretRedactor.auditSafe(String(data: data, encoding: .utf8) ?? "HTTP \(httpResponse.statusCode)")
            throw OpenAIEnricherError.requestFailed(body)
        }

        guard let text = extractOutputText(from: data), !text.isEmpty else {
            throw OpenAIEnricherError.invalidResponse
        }
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func instructions(language: AppLanguage) -> String {
        if language == .simplifiedChinese {
            return """
            You explain local agent configuration files for a technical macOS app.
            Be concise and factual. Do not claim to have executed code.
            Return Chinese prose in this exact shape:
            用途: ...
            触发: ...
            依赖: ...
            风险: ...
            """
        }

        return """
        You explain local agent configuration files for a technical macOS app.
        Be concise and factual. Do not claim to have executed code.
        Return English prose in this exact shape:
        Purpose: ...
        Trigger: ...
        Dependencies: ...
        Risks: ...
        """
    }

    private func prompt(for asset: AgentAsset) throws -> String {
        let preview = try OpenAIPayloadGuard.safePreview(asset, limit: 7_000)
        return """
        File path: \(asset.displayPath)
        Owner: \(asset.owner.rawValue)
        Kind: \(asset.kind.rawValue)
        Scope: \(asset.scope)
        Existing local summary: \(asset.summary)
        Trigger: \(asset.trigger ?? "unknown")
        Dependencies: \(asset.dependencies.joined(separator: ", "))
        Related files: \(asset.relatedFiles.joined(separator: ", "))
        Status flags: \(asset.statusFlags.map(\.rawValue).joined(separator: ", "))

        File preview:
        \(preview)
        """
    }

    private func extractOutputText(from data: Data) -> String? {
        guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }

        if let outputText = object["output_text"] as? String {
            return outputText
        }

        guard let output = object["output"] as? [[String: Any]] else { return nil }
        let chunks = output.flatMap { item -> [String] in
            guard let content = item["content"] as? [[String: Any]] else { return [] }
            return content.compactMap { contentItem in
                contentItem["text"] as? String
            }
        }
        return chunks.joined(separator: "\n")
    }
}
