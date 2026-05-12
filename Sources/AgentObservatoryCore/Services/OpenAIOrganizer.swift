import Foundation

public enum OpenAIOrganizerError: LocalizedError, Sendable {
    case missingAPIKey
    case invalidBaseURL(String)
    case invalidResponse(String)
    case requestFailed(statusCode: Int, message: String)
    case invalidJSON(reason: String, excerpt: String)
    case noValidRecommendations(returned: Int)

    public var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            "OpenAI API key is missing."
        case .invalidBaseURL(let value):
            "Invalid OpenAI base URL: \(value)"
        case .invalidResponse(let details):
            "OpenAI returned a response the app could not read. \(details)"
        case .requestFailed(let statusCode, let message):
            "OpenAI request failed (HTTP \(statusCode)): \(message)"
        case .invalidJSON(let reason, let excerpt):
            "AI plan could not be parsed as JSON: \(reason)\nModel output: \(excerpt)"
        case .noValidRecommendations(let returned):
            "AI plan returned \(returned) recommendations, but none matched the current indexed asset paths."
        }
    }
}

public struct OpenAIOrganizer: Sendable {
    private let session: URLSession
    private let planningOutputTokenBudget = 6_000
    private let repairOutputTokenBudget = 3_000

    public init(session: URLSession = .shared) {
        self.session = session
    }

    public func organize(
        map: OrganizationMap,
        assets: [AgentAsset],
        apiKey: String,
        model: String,
        baseURL: String = OpenAIConfiguration.defaultBaseURL,
        language: AppLanguage = .english
    ) async throws -> OrganizationPlan {
        let trimmedKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedKey.isEmpty else { throw OpenAIOrganizerError.missingAPIKey }
        let endpoint: URL
        do {
            endpoint = try OpenAIConfiguration.responsesEndpoint(baseURL: baseURL)
        } catch {
            throw OpenAIOrganizerError.invalidBaseURL(baseURL)
        }

        let safeAssets = OpenAIPayloadGuard.safeAssets(assets)
        guard !safeAssets.isEmpty else {
            throw OpenAIPayloadGuardError.noSafeAssets
        }

        let text = try await requestOutputText(
            endpoint: endpoint,
            apiKey: trimmedKey,
            payload: try organizationPayload(map: map, assets: safeAssets, model: model, language: language)
        )

        let validPaths = Set(safeAssets.map(\.path))
        let recommendations = try await decodeOrRepairRecommendations(
            from: text,
            validPaths: validPaths,
            model: model,
            endpoint: endpoint,
            apiKey: trimmedKey,
            language: language
        )
        return OrganizationPlan(
            map: map,
            recommendations: recommendations,
            source: "openai"
        )
    }

    private func organizationPayload(
        map: OrganizationMap,
        assets: [AgentAsset],
        model: String,
        language: AppLanguage
    ) throws -> [String: Any] {
        [
            "model": model,
            "store": false,
            "max_output_tokens": planningOutputTokenBudget,
            "text": structuredOutputFormat(),
            "instructions": instructions(language: language),
            "input": try prompt(map: map, assets: assets, language: language)
        ]
    }

    private func instructions(language: AppLanguage) -> String {
        let languageRule = language == .simplifiedChinese
            ? "Write recommendation titles and reasons in Simplified Chinese."
            : "Write recommendation titles and reasons in English."

        return """
        You are helping organize local AI-agent configuration assets.
        \(languageRule)

        Rules:
        - Do not recommend destructive hard delete.
        - Use archive for soft-delete candidates.
        - Use merge when two assets appear to overlap.
        - Use review when human judgment is needed before any file move.
        - Keep recommendations conservative and actionable.
        - Return at most 12 recommendations.
        - Prefer the highest-confidence recommendations and skip low-value notes.
        - primaryAssetPath and relatedAssetPaths must be copied exactly from indexed asset paths in the input.
        """
    }

    private func prompt(map: OrganizationMap, assets: [AgentAsset], language: AppLanguage) throws -> String {
        let assetLines = try assets.prefix(160).map { asset in
            [
                "path=\(asset.path)",
                "owner=\(L10n.agentOwner(asset.owner, language: language))",
                "kind=\(L10n.assetKind(asset.kind, language: language))",
                "title=\(asset.title)",
                "summary=\(asset.summary)",
                "trigger=\(asset.trigger ?? "")",
                "deps=\(asset.dependencies.prefix(6).joined(separator: ", "))",
                "flags=\(asset.statusFlags.map(\.rawValue).joined(separator: ", "))",
                "preview=\(try OpenAIPayloadGuard.safePreview(asset, limit: 700))"
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

    private func decodeRecommendations(
        from text: String,
        validPaths: Set<String>,
        language: AppLanguage
    ) throws -> [OrganizationRecommendation] {
        let jsonText = extractJSONObjectText(from: text)
        let data = Data(jsonText.utf8)
        let dto: OpenAIOrganizerResponse
        do {
            dto = try JSONDecoder().decode(OpenAIOrganizerResponse.self, from: data)
        } catch {
            throw OpenAIOrganizerError.invalidJSON(
                reason: error.localizedDescription,
                excerpt: clipped(text)
            )
        }

        let recommendations: [OrganizationRecommendation] = dto.recommendations.compactMap { item -> OrganizationRecommendation? in
            guard let action = OrganizationAction.caseInsensitive(item.action) else { return nil }
            guard validPaths.contains(item.primaryAssetPath) else { return nil }
            let related = item.relatedAssetPaths.filter { validPaths.contains($0) && $0 != item.primaryAssetPath }
            return OrganizationRecommendation(
                action: action,
                title: item.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    ? "\(L10n.organizationAction(action, language: language)) \(L10n.text(.asset, language: language))"
                    : item.title,
                reason: item.reason.trimmingCharacters(in: .whitespacesAndNewlines),
                primaryAssetPath: item.primaryAssetPath,
                relatedAssetPaths: related,
                confidence: min(max(item.confidence, 0), 1)
            )
        }
        if !dto.recommendations.isEmpty && recommendations.isEmpty {
            throw OpenAIOrganizerError.noValidRecommendations(returned: dto.recommendations.count)
        }
        return recommendations
    }

    private func decodeOrRepairRecommendations(
        from text: String,
        validPaths: Set<String>,
        model: String,
        endpoint: URL,
        apiKey: String,
        language: AppLanguage
    ) async throws -> [OrganizationRecommendation] {
        do {
            return try decodeRecommendations(from: text, validPaths: validPaths, language: language)
        } catch OpenAIOrganizerError.invalidJSON {
            let repairedText = try await requestOutputText(
                endpoint: endpoint,
                apiKey: apiKey,
                payload: repairPayload(
                    malformedText: text,
                    validPaths: validPaths,
                    model: model,
                    language: language
                )
            )
            return try decodeRecommendations(from: repairedText, validPaths: validPaths, language: language)
        }
    }

    private func requestOutputText(endpoint: URL, apiKey: String, payload: [String: Any]) async throws -> String {
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw OpenAIOrganizerError.invalidResponse("The URL response was not HTTP.")
        }
        guard (200..<300).contains(httpResponse.statusCode) else {
            throw OpenAIOrganizerError.requestFailed(
                statusCode: httpResponse.statusCode,
                message: responseErrorMessage(from: data)
            )
        }
        try validateCompleteResponse(data)
        guard let text = extractOutputText(from: data), !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw OpenAIOrganizerError.invalidResponse("Response did not contain output text.")
        }
        return text
    }

    private func repairPayload(
        malformedText: String,
        validPaths: Set<String>,
        model: String,
        language: AppLanguage
    ) -> [String: Any] {
        let languageRule = language == .simplifiedChinese
            ? "Keep Chinese title and reason text when it is recoverable."
            : "Keep English title and reason text when it is recoverable."
        let paths = validPaths.sorted().joined(separator: "\n")
        return [
            "model": model,
            "store": false,
            "max_output_tokens": repairOutputTokenBudget,
            "text": structuredOutputFormat(),
            "instructions": """
            Convert malformed model output into valid JSON matching the organization_plan schema.
            Return JSON only.
            Do not invent new recommendations.
            Drop any item whose primaryAssetPath is not in the valid path list.
            relatedAssetPaths must always be an array.
            \(languageRule)
            """,
            "input": """
            Valid asset paths:
            \(paths)

            Malformed model output:
            \(malformedText)
            """
        ]
    }

    private func validateCompleteResponse(_ data: Data) throws {
        guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return
        }
        guard let status = object["status"] as? String, status == "incomplete" else {
            return
        }

        let reason = ((object["incomplete_details"] as? [String: Any])?["reason"] as? String) ?? "unknown"
        throw OpenAIOrganizerError.invalidResponse(
            "OpenAI response was incomplete (\(reason)). The model output was likely cut off before valid JSON could finish."
        )
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

    private func responseErrorMessage(from data: Data) -> String {
        if let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let error = object["error"] as? [String: Any],
           let message = error["message"] as? String,
           !message.isEmpty {
            return clipped(SecretRedactor.auditSafe(message))
        }

        let body = String(data: data, encoding: .utf8) ?? "OpenAI returned a non-UTF8 error body."
        return clipped(SecretRedactor.auditSafe(body))
    }

    private func clipped(_ value: String, limit: Int = 700) -> String {
        let trimmed = SecretRedactor.auditSafe(value).trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count > limit else { return trimmed }
        return "\(trimmed.prefix(limit))..."
    }

    private func structuredOutputFormat() -> [String: Any] {
        [
            "format": [
                "type": "json_schema",
                "name": "organization_plan",
                "strict": true,
                "schema": [
                    "type": "object",
                    "additionalProperties": false,
                    "properties": [
                        "recommendations": [
                            "type": "array",
                            "items": [
                                "type": "object",
                                "additionalProperties": false,
                                "properties": [
                                    "action": [
                                        "type": "string",
                                        "enum": ["keep", "merge", "archive", "hide", "review"]
                                    ],
                                    "title": ["type": "string"],
                                    "reason": ["type": "string"],
                                    "primaryAssetPath": ["type": "string"],
                                    "relatedAssetPaths": [
                                        "type": "array",
                                        "items": ["type": "string"]
                                    ],
                                    "confidence": [
                                        "type": "number",
                                        "minimum": 0,
                                        "maximum": 1
                                    ]
                                ],
                                "required": [
                                    "action",
                                    "title",
                                    "reason",
                                    "primaryAssetPath",
                                    "relatedAssetPaths",
                                    "confidence"
                                ]
                            ]
                        ]
                    ],
                    "required": ["recommendations"]
                ]
            ]
        ]
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
        relatedAssetPaths = try container.decodeFlexibleStringArrayIfPresent(forKey: .relatedAssetPaths)
        confidence = try container.decodeFlexibleDoubleIfPresent(forKey: .confidence) ?? 0.5
    }
}

private extension KeyedDecodingContainer {
    func decodeFlexibleStringArrayIfPresent(forKey key: K) throws -> [String] {
        if let values = try? decodeIfPresent([String].self, forKey: key) {
            return values
        }
        if let value = try? decodeIfPresent(String.self, forKey: key) {
            let trimmed = value.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
            return trimmed.isEmpty ? [] : [trimmed]
        }
        return []
    }

    func decodeFlexibleDoubleIfPresent(forKey key: K) throws -> Double? {
        if let value = try? decodeIfPresent(Double.self, forKey: key) {
            return value
        }
        if let value = try? decodeIfPresent(String.self, forKey: key) {
            let normalized = value
                .trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
                .replacingOccurrences(of: "O", with: "0")
                .replacingOccurrences(of: "o", with: "0")
            return Double(normalized)
        }
        return nil
    }
}

private extension OrganizationAction {
    static func caseInsensitive(_ value: String) -> OrganizationAction? {
        let normalized = value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return OrganizationAction.allCases.first { $0.rawValue.lowercased() == normalized }
    }
}
