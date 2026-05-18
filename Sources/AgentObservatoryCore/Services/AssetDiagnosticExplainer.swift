import Foundation

public struct AssetDiagnosticExplanation: Equatable, Sendable {
    public let summary: String
    public let detailRows: [AssetDiagnosticDetailRow]

    public init(summary: String, detailRows: [AssetDiagnosticDetailRow] = []) {
        self.summary = summary
        self.detailRows = detailRows
    }
}

public struct AssetDiagnosticDetailRow: Identifiable, Equatable, Sendable {
    public let id: String
    public let label: String
    public let value: String
    public let path: String?

    public init(id: String, label: String, value: String, path: String? = nil) {
        self.id = id
        self.label = label
        self.value = value
        self.path = path
    }
}

public struct AssetDiagnosticExplainer: Sendable {
    public init() {}

    public func explanation(
        for flag: AssetStatusFlag,
        asset: AgentAsset,
        allAssets: [AgentAsset],
        language: AppLanguage
    ) -> AssetDiagnosticExplanation {
        switch flag {
        case .duplicate:
            duplicateExplanation(asset: asset, allAssets: allAssets, language: language)
        case .stalePath:
            stalePathExplanation(asset: asset, language: language)
        default:
            AssetDiagnosticExplanation(summary: L10n.statusFlagMessage(flag, language: language))
        }
    }

    private func duplicateExplanation(
        asset: AgentAsset,
        allAssets: [AgentAsset],
        language: AppLanguage
    ) -> AssetDiagnosticExplanation {
        let peers = allAssets
            .filter { $0.id != asset.id && $0.normalizedKey == asset.normalizedKey }
            .sorted { $0.displayPath.localizedStandardCompare($1.displayPath) == .orderedAscending }

        let summary: String
        if peers.isEmpty {
            summary = text(
                english: "This asset was marked duplicate because another indexed item shared the same normalized kind and title during scan. The matching item may now be hidden, archived, or filtered out.",
                chinese: "扫描时发现另一个资产和它使用相同的规范化类型与标题，因此被标记为重复；匹配项可能已经被隐藏、归档或过滤掉。",
                language: language
            )
        } else {
            summary = text(
                english: "This asset shares the same normalized identity with \(peers.count) other indexed item(s): \(asset.normalizedKey).",
                chinese: "这个资产和 \(peers.count) 个已索引资产共享同一个规范化身份：\(asset.normalizedKey)。",
                language: language
            )
        }

        var rows = [
            AssetDiagnosticDetailRow(
                id: "rule",
                label: text(english: "Rule", chinese: "命中规则", language: language),
                value: text(
                    english: "Same asset kind plus normalized title.",
                    chinese: "资产类型相同，标题规范化后相同。",
                    language: language
                )
            )
        ]

        rows.append(contentsOf: peers.enumerated().map { index, peer in
            AssetDiagnosticDetailRow(
                id: "peer-\(peer.id.uuidString)",
                label: text(english: "Duplicate \(index + 1)", chinese: "重复项 \(index + 1)", language: language),
                value: peer.displayPath,
                path: peer.path
            )
        })

        return AssetDiagnosticExplanation(summary: summary, detailRows: rows)
    }

    private func stalePathExplanation(
        asset: AgentAsset,
        language: AppLanguage
    ) -> AssetDiagnosticExplanation {
        let snippets = stalePathSnippets(in: asset.preview)
        let summary = text(
            english: "This \(asset.owner.rawValue) asset is not owned by Claude, but its safe preview still references Claude-era paths. Review whether those references should migrate to Codex, Agents, or project-local locations.",
            chinese: "这个 \(ownerLabel(asset.owner, language: language)) 资产不属于 Claude，但安全预览里仍引用 Claude 时期路径。需要确认这些引用应该迁移到 Codex、Agents，还是项目本地位置。",
            language: language
        )

        var rows = [
            AssetDiagnosticDetailRow(
                id: "rule",
                label: text(english: "Rule", chinese: "命中规则", language: language),
                value: text(
                    english: "Owner is not Claude and preview contains ~/.claude.",
                    chinese: "资产归属不是 Claude，且预览文本包含 ~/.claude。",
                    language: language
                )
            )
        ]

        if snippets.isEmpty {
            rows.append(
                AssetDiagnosticDetailRow(
                    id: "snippet-missing",
                    label: text(english: "Matched text", chinese: "命中片段", language: language),
                    value: text(
                        english: "The scan flag is present, but no Claude path snippet is available in the current preview.",
                        chinese: "当前扫描标记存在，但当前预览里没有可展示的 Claude 路径片段。",
                        language: language
                    )
                )
            )
        } else {
            rows.append(contentsOf: snippets.enumerated().map { index, snippet in
                AssetDiagnosticDetailRow(
                    id: "snippet-\(index)",
                    label: text(english: "Snippet \(index + 1)", chinese: "命中片段 \(index + 1)", language: language),
                    value: snippet
                )
            })
        }

        return AssetDiagnosticExplanation(summary: summary, detailRows: rows)
    }

    private func stalePathSnippets(in preview: String) -> [String] {
        preview
            .components(separatedBy: .newlines)
            .lazy
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty && $0.lowercased().contains(".claude") }
            .map { String($0.prefix(180)) }
            .prefix(3)
            .map { String($0) }
    }

    private func ownerLabel(_ owner: AgentOwner, language: AppLanguage) -> String {
        owner == .claude ? "Claude Code" : L10n.agentOwner(owner, language: language)
    }

    private func text(english: String, chinese: String, language: AppLanguage) -> String {
        switch language {
        case .english:
            english
        case .simplifiedChinese:
            chinese
        }
    }
}
