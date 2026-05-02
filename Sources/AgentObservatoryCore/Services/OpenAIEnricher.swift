import Foundation

public enum OpenAIEnricherError: LocalizedError, Sendable {
    case missingAPIKey
    case invalidResponse
    case requestFailed(String)

    public var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            "OpenAI API key is missing."
        case .invalidResponse:
            "OpenAI returned a response the app could not read."
        case .requestFailed(let message):
            message
        }
    }
}

public struct OpenAIEnricher: Sendable {
    private let session: URLSession
    private let endpoint = URL(string: "https://api.openai.com/v1/responses")!

    public init(session: URLSession = .shared) {
        self.session = session
    }

    public func summarize(asset: AgentAsset, apiKey: String, model: String) async throws -> String {
        let trimmedKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedKey.isEmpty else { throw OpenAIEnricherError.missingAPIKey }

        let input = prompt(for: asset)
        let payload: [String: Any] = [
            "model": model,
            "store": false,
            "max_output_tokens": 320,
            "instructions": """
            You explain local agent configuration files for a technical macOS app.
            Be concise and factual. Do not claim to have executed code.
            Return Chinese prose in this exact shape:
            用途: ...
            触发: ...
            依赖: ...
            风险: ...
            """,
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
            let body = String(data: data, encoding: .utf8) ?? "HTTP \(httpResponse.statusCode)"
            throw OpenAIEnricherError.requestFailed(body)
        }

        guard let text = extractOutputText(from: data), !text.isEmpty else {
            throw OpenAIEnricherError.invalidResponse
        }
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func prompt(for asset: AgentAsset) -> String {
        let preview = String(SecretRedactor.redact(asset.preview).prefix(7_000))
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
