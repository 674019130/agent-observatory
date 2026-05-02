import Foundation

public struct OpenAIOrganizer: Sendable {
    private let session: URLSession

    public init(session: URLSession = .shared) {
        self.session = session
    }

    public func organize(
        map: OrganizationMap,
        assets: [AgentAsset],
        apiKey: String,
        model: String,
        baseURL: String = OpenAIConfiguration.defaultBaseURL
    ) async throws -> OrganizationPlan {
        let trimmedKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedKey.isEmpty else { throw OpenAIEnricherError.missingAPIKey }
        let endpoint: URL
        do {
            endpoint = try OpenAIConfiguration.responsesEndpoint(baseURL: baseURL)
        } catch {
            throw OpenAIEnricherError.invalidBaseURL(baseURL)
        }

        let payload: [String: Any] = [
            "model": model,
            "store": false,
            "max_output_tokens": 1_800,
            "instructions": """
            You are helping organize local AI-agent configuration assets.
            Return JSON only, with this shape:
            {
              "recommendations": [
                {
                  "action": "keep|merge|archive|hide|review",
                  "title": "short title",
                  "reason": "one concise reason",
                  "primaryAssetPath": "/absolute/path",
                  "relatedAssetPaths": ["/absolute/path"],
                  "confidence": 0.0
                }
              ]
            }

            Rules:
            - Do not recommend destructive hard delete.
            - Use archive for soft-delete candidates.
            - Use merge when two assets appear to overlap.
            - Use review when human judgment is needed before any file move.
            - Keep recommendations conservative and actionable.
            """,
            "input": prompt(map: map, assets: assets)
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
        guard let text = extractOutputText(from: data) else {
            throw OpenAIEnricherError.invalidResponse
        }

        let recommendations = try decodeRecommendations(from: text, validPaths: Set(assets.map(\.path)))
        return OrganizationPlan(
            map: map,
            recommendations: recommendations,
            source: "openai"
        )
    }

    private func prompt(map: OrganizationMap, assets: [AgentAsset]) -> String {
        let assetLines = assets.prefix(160).map { asset in
            [
                "path=\(asset.path)",
                "owner=\(asset.owner.rawValue)",
                "kind=\(asset.kind.rawValue)",
                "title=\(asset.title)",
                "summary=\(asset.summary)",
                "trigger=\(asset.trigger ?? "")",
                "deps=\(asset.dependencies.prefix(6).joined(separator: ", "))",
                "flags=\(asset.statusFlags.map(\.rawValue).joined(separator: ", "))",
                "preview=\(String(SecretRedactor.redact(asset.preview).prefix(700)))"
            ].joined(separator: " | ")
        }
        .joined(separator: "\n")

        let audienceSummary = map.audienceCounts
            .sorted { $0.key < $1.key }
            .map { "\($0.key): \($0.value)" }
            .joined(separator: ", ")

        return """
        Total assets: \(map.totalAssets)
        Audience counts: \(audienceSummary)

        Assets:
        \(assetLines)
        """
    }

    private func decodeRecommendations(from text: String, validPaths: Set<String>) throws -> [OrganizationRecommendation] {
        let jsonText = extractJSONObjectText(from: text)
        let data = Data(jsonText.utf8)
        let dto = try JSONDecoder().decode(OpenAIOrganizerResponse.self, from: data)

        return dto.recommendations.compactMap { item in
            guard let action = OrganizationAction.caseInsensitive(item.action) else { return nil }
            guard validPaths.contains(item.primaryAssetPath) else { return nil }
            let related = item.relatedAssetPaths.filter { validPaths.contains($0) && $0 != item.primaryAssetPath }
            return OrganizationRecommendation(
                action: action,
                title: item.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "\(action.rawValue) asset" : item.title,
                reason: item.reason.trimmingCharacters(in: .whitespacesAndNewlines),
                primaryAssetPath: item.primaryAssetPath,
                relatedAssetPaths: related,
                confidence: min(max(item.confidence, 0), 1)
            )
        }
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

    private func extractJSONObjectText(from text: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let start = trimmed.firstIndex(of: "{"), let end = trimmed.lastIndex(of: "}") else {
            return trimmed
        }
        return String(trimmed[start...end])
    }
}

private struct OpenAIOrganizerResponse: Decodable {
    let recommendations: [OpenAIOrganizerRecommendation]
}

private struct OpenAIOrganizerRecommendation: Decodable {
    let action: String
    let title: String
    let reason: String
    let primaryAssetPath: String
    let relatedAssetPaths: [String]
    let confidence: Double

    private enum CodingKeys: String, CodingKey {
        case action
        case title
        case reason
        case primaryAssetPath
        case relatedAssetPaths
        case confidence
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        action = try container.decode(String.self, forKey: .action)
        title = try container.decode(String.self, forKey: .title)
        reason = try container.decode(String.self, forKey: .reason)
        primaryAssetPath = try container.decode(String.self, forKey: .primaryAssetPath)
        relatedAssetPaths = try container.decodeIfPresent([String].self, forKey: .relatedAssetPaths) ?? []
        confidence = try container.decodeIfPresent(Double.self, forKey: .confidence) ?? 0.5
    }
}

private extension OrganizationAction {
    static func caseInsensitive(_ value: String) -> OrganizationAction? {
        let normalized = value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return OrganizationAction.allCases.first { $0.rawValue.lowercased() == normalized }
    }
}
