import Foundation

public struct AssetDiffAnalyzer: Sendable {
    public init() {}

    public func comparison(for asset: AgentAsset, in assets: [AgentAsset]) -> AssetComparison {
        guard let counterpart = counterpart(for: asset, in: assets) else {
            return AssetComparison(base: asset, counterpart: nil, rows: [])
        }

        let rows = [
            row("Path", asset.displayPath, counterpart.displayPath),
            row("Summary", asset.summary, counterpart.summary),
            row("Trigger", asset.trigger ?? "", counterpart.trigger ?? ""),
            row("Dependencies", joined(asset.dependencies), joined(counterpart.dependencies)),
            row("Related Files", joined(asset.relatedFiles), joined(counterpart.relatedFiles)),
            row("Status Flags", joined(asset.statusFlags.map(\.rawValue)), joined(counterpart.statusFlags.map(\.rawValue))),
            row("Frontmatter Name", frontMatterValue("name", in: asset), frontMatterValue("name", in: counterpart)),
            row("Frontmatter Description", frontMatterValue("description", in: asset), frontMatterValue("description", in: counterpart)),
            row("Preview Hash", StableHash.hash(asset.preview), StableHash.hash(counterpart.preview))
        ]

        return AssetComparison(base: asset, counterpart: counterpart, rows: rows)
    }

    private func counterpart(for asset: AgentAsset, in assets: [AgentAsset]) -> AgentAsset? {
        let candidates = assets.filter { candidate in
            candidate.id != asset.id
                && candidate.kind == asset.kind
                && candidate.normalizedTitleKey == asset.normalizedTitleKey
        }

        let preferredOwners = ownerPriority(for: asset.owner)
        return candidates.sorted { left, right in
            let leftIndex = preferredOwners.firstIndex(of: left.owner) ?? preferredOwners.count
            let rightIndex = preferredOwners.firstIndex(of: right.owner) ?? preferredOwners.count
            if leftIndex != rightIndex { return leftIndex < rightIndex }
            return left.path.localizedCaseInsensitiveCompare(right.path) == .orderedAscending
        }.first
    }

    private func ownerPriority(for owner: AgentOwner) -> [AgentOwner] {
        switch owner {
        case .claude:
            [.codex, .agents, .project]
        case .codex, .agents:
            [.claude, .codex, .agents, .project]
        case .project:
            [.claude, .codex, .agents]
        case .unknown:
            [.claude, .codex, .agents, .project]
        }
    }

    private func row(_ field: String, _ leftValue: String, _ rightValue: String) -> AssetDiffRow {
        let left = leftValue.trimmingCharacters(in: .whitespacesAndNewlines)
        let right = rightValue.trimmingCharacters(in: .whitespacesAndNewlines)
        let status: AssetDiffRowStatus
        if left == right {
            status = .same
        } else if left.isEmpty {
            status = .missingLeft
        } else if right.isEmpty {
            status = .missingRight
        } else {
            status = .changed
        }
        return AssetDiffRow(field: field, leftValue: left, rightValue: right, status: status)
    }

    private func joined(_ values: [String]) -> String {
        values.isEmpty ? "" : values.joined(separator: "\n")
    }

    private func frontMatterValue(_ key: String, in asset: AgentAsset) -> String {
        FrontMatterParser.parse(asset.preview).frontMatter[key] ?? ""
    }
}
