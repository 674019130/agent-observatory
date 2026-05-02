import Foundation

public struct CleanupReviewAnalyzer: Sendable {
    public init() {}

    public func session(goal: CleanupReviewGoal, assets: [AgentAsset]) -> CleanupReviewSession {
        let groups = groups(goal: goal, assets: assets)
            .sorted { left, right in
                if riskPriority(left.risk) != riskPriority(right.risk) {
                    return riskPriority(left.risk) > riskPriority(right.risk)
                }
                if left.canApplyAutomatically != right.canApplyAutomatically {
                    return left.canApplyAutomatically && !right.canApplyAutomatically
                }
                return left.title.localizedCaseInsensitiveCompare(right.title) == .orderedAscending
            }

        return CleanupReviewSession(goal: goal, groups: groups, totalAssets: assets.count)
    }

    private func groups(goal: CleanupReviewGoal, assets: [AgentAsset]) -> [CleanupReviewGroup] {
        switch goal {
        case .fullReview:
            duplicateGroups(assets: assets)
                + staleClaudeGroups(assets: assets)
                + noiseGroups(assets: assets)
                + riskGroups(assets: assets)
                + unclearGroups(assets: assets)
        case .legacyClaudeCleanup:
            staleClaudeGroups(assets: assets)
                + duplicateGroups(assets: assets).filter { group in
                    group.assetPaths.contains { path in path.localizedCaseInsensitiveContains(".claude") }
                }
        case .duplicateCleanup:
            duplicateGroups(assets: assets)
        case .noiseCleanup:
            noiseGroups(assets: assets) + unclearGroups(assets: assets)
        case .riskCleanup:
            riskGroups(assets: assets)
        }
    }

    private func duplicateGroups(assets: [AgentAsset]) -> [CleanupReviewGroup] {
        Dictionary(grouping: assets) { asset in
            "\(asset.kind.rawValue)::\(asset.normalizedTitleKey)"
        }
        .values
        .filter { $0.count > 1 }
        .map { group in
            let sorted = group.sorted { left, right in
                ownerPriority(left.owner) < ownerPriority(right.owner)
            }
            let primary = sorted[0]
            return CleanupReviewGroup(
                id: "duplicates-\(primary.kind.rawValue)-\(primary.normalizedTitleKey)",
                title: "Merge duplicate \(primary.kind.rawValue): \(primary.title)",
                summary: "These files appear to define the same \(primary.kind.rawValue.lowercased()) behavior. Merge the behavior first; archive only after checking the diff.",
                action: .merge,
                risk: .medium,
                confidence: 0.82,
                assetPaths: sorted.map(\.path),
                evidence: [
                    "\(sorted.count) files share normalized name \"\(primary.normalizedTitleKey)\".",
                    "Preferred active owner is \(sorted[0].owner.rawValue).",
                    "Owners involved: \(Set(sorted.map(\.owner.rawValue)).sorted().joined(separator: ", "))."
                ]
            )
        }
    }

    private func staleClaudeGroups(assets: [AgentAsset]) -> [CleanupReviewGroup] {
        assets
            .filter { $0.statusFlags.contains(.stalePath) }
            .map { asset in
                CleanupReviewGroup(
                    id: "stale-claude-\(StableHash.hash(asset.path))",
                    title: "Review Claude-era reference: \(asset.title)",
                    summary: "This file still references a Claude-era path. Decide whether it should be migrated, merged, or archived.",
                    action: .review,
                    risk: .high,
                    confidence: 0.78,
                    assetPaths: [asset.path],
                    evidence: [
                        "Scanner marked this file with a stale Claude path flag.",
                        "Owner is \(asset.owner.rawValue), kind is \(asset.kind.rawValue).",
                        "Path: \(asset.displayPath)"
                    ]
                )
            }
    }

    private func noiseGroups(assets: [AgentAsset]) -> [CleanupReviewGroup] {
        let noise = assets
            .filter { asset in
                (asset.kind == .session || asset.kind == .unknown)
                    && !asset.statusFlags.contains(.secretRisk)
                    && !asset.statusFlags.contains(.unreadable)
            }
            .sorted { $0.path < $1.path }

        guard !noise.isEmpty else { return [] }

        return [
            CleanupReviewGroup(
                id: "noise-low-signal",
                title: "Hide low-signal indexed noise",
                summary: "Session and unknown files usually add scanning noise but are still recoverable from Hidden Items if hidden.",
                action: .hide,
                risk: .low,
                confidence: 0.74,
                assetPaths: noise.map(\.path),
                evidence: [
                    "\(noise.count) session or unknown files are visible in the active index.",
                    "Hide is reversible and does not move files.",
                    "Sensitive or unreadable files are excluded from this batch."
                ]
            )
        ]
    }

    private func riskGroups(assets: [AgentAsset]) -> [CleanupReviewGroup] {
        let riskAssets = assets
            .filter { asset in
                asset.statusFlags.contains(.secretRisk) || asset.statusFlags.contains(.unreadable)
            }
            .sorted { $0.path < $1.path }

        guard !riskAssets.isEmpty else { return [] }

        return [
            CleanupReviewGroup(
                id: "risk-sensitive-unreadable",
                title: "Review sensitive or unreadable files",
                summary: "These files should stay visible for awareness, but should not be sent to AI or batch archived.",
                action: .review,
                risk: .high,
                confidence: 0.9,
                assetPaths: riskAssets.map(\.path),
                evidence: [
                    "\(riskAssets.count) files carry secret or unreadable status flags.",
                    "AI preview is avoided for sensitive paths.",
                    "Manual permission and contents review is required."
                ]
            )
        ]
    }

    private func unclearGroups(assets: [AgentAsset]) -> [CleanupReviewGroup] {
        let unclear = assets
            .filter { $0.statusFlags.contains(.needsSummary) }
            .sorted { $0.path < $1.path }

        guard !unclear.isEmpty else { return [] }

        return [
            CleanupReviewGroup(
                id: "unclear-needs-summary",
                title: "Clarify files with no useful summary",
                summary: "These files need a description before cleanup decisions are trustworthy.",
                action: .review,
                risk: .medium,
                confidence: 0.56,
                assetPaths: unclear.map(\.path),
                evidence: [
                    "\(unclear.count) files have no explicit local summary.",
                    "Ask AI to explain individual files or add descriptions before cleanup.",
                    "No automatic file operation is recommended."
                ]
            )
        ]
    }

    private func ownerPriority(_ owner: AgentOwner) -> Int {
        switch owner {
        case .agents:
            0
        case .codex:
            1
        case .project:
            2
        case .claude:
            3
        case .unknown:
            4
        }
    }

    private func riskPriority(_ risk: CleanupReviewRisk) -> Int {
        switch risk {
        case .high:
            3
        case .medium:
            2
        case .low:
            1
        }
    }
}
