import Foundation

public struct AssetClassifier: Sendable {
    public init() {}

    public func makeAsset(
        url: URL,
        owner: AgentOwner,
        kind: AssetKind,
        scope: String,
        preview: String,
        modifiedAt: Date?,
        byteCount: Int64,
        relatedFiles: [String],
        isSensitive: Bool,
        isLarge: Bool,
        unreadable: Bool
    ) -> AgentAsset {
        let parsed = FrontMatterParser.parse(preview)
        let title = titleFor(url: url, kind: kind, frontMatter: parsed.frontMatter, body: parsed.body)
        let description = summaryFor(url: url, kind: kind, frontMatter: parsed.frontMatter, body: parsed.body)
        let dependencies = DependencyExtractor.extract(from: preview)
        let trigger = triggerFor(url: url, kind: kind, frontMatter: parsed.frontMatter)
        let redactedPreview = isSensitive ? "Sensitive file intentionally not previewed." : SecretRedactor.redact(preview)
        let hashInput = "\(url.path)\n\(kind.rawValue)\n\(preview)"

        var flags: [AssetStatusFlag] = []
        if isSensitive { flags.append(.secretRisk) }
        if isLarge { flags.append(.largeFile) }
        if unreadable { flags.append(.unreadable) }
        if description == "No summary yet" { flags.append(.needsSummary) }
        if owner != .claude && preview.contains("~/.claude") { flags.append(.stalePath) }
        if !relatedFiles.isEmpty || dependencies.contains(where: { $0.contains("scripts/") || $0.contains("/scripts/") }) {
            flags.append(.hasScripts)
        }

        return AgentAsset(
            path: url.path,
            owner: owner,
            kind: kind,
            scope: scope,
            title: title,
            summary: description,
            trigger: trigger,
            dependencies: dependencies,
            relatedFiles: relatedFiles,
            modifiedAt: modifiedAt,
            byteCount: byteCount,
            contentHash: StableHash.hash(hashInput),
            preview: redactedPreview,
            statusFlags: unique(flags)
        )
    }

    private func titleFor(url: URL, kind: AssetKind, frontMatter: [String: String], body: String) -> String {
        if let name = frontMatter["name"], !name.isEmpty {
            return name
        }

        if let heading = firstMarkdownHeading(in: body) {
            return heading
        }

        if kind == .skill && url.lastPathComponent.lowercased() == "skill.md" {
            return url.deletingLastPathComponent().lastPathComponent
        }

        return url.deletingPathExtension().lastPathComponent
    }

    private func summaryFor(url: URL, kind: AssetKind, frontMatter: [String: String], body: String) -> String {
        if let description = frontMatter["description"], !description.isEmpty {
            return description
        }

        if let firstLine = firstUsefulLine(in: body) {
            return firstLine
        }

        switch kind {
        case .command:
            return "Slash command definition for \(url.deletingPathExtension().lastPathComponent)."
        case .config:
            return "Configuration file used by \(url.lastPathComponent)."
        case .mcp:
            return "MCP-related configuration or documentation."
        default:
            return "No summary yet"
        }
    }

    private func triggerFor(url: URL, kind: AssetKind, frontMatter: [String: String]) -> String? {
        if let trigger = frontMatter["trigger"], !trigger.isEmpty {
            return trigger
        }

        switch kind {
        case .command:
            return "/" + url.deletingPathExtension().lastPathComponent
        case .skill:
            return frontMatter["description"].map { "Auto-selected when task matches: \($0)" }
        default:
            return nil
        }
    }

    private func firstMarkdownHeading(in body: String) -> String? {
        body.components(separatedBy: .newlines)
            .lazy
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .first { $0.hasPrefix("# ") }?
            .replacingOccurrences(of: "# ", with: "")
    }

    private func firstUsefulLine(in body: String) -> String? {
        body.components(separatedBy: .newlines)
            .lazy
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .first { line in
                line.count > 24
                    && !line.hasPrefix("#")
                    && !line.hasPrefix("```")
                    && !line.hasPrefix("---")
            }
    }

    private func unique(_ flags: [AssetStatusFlag]) -> [AssetStatusFlag] {
        Array(Set(flags)).sorted { $0.rawValue < $1.rawValue }
    }
}
