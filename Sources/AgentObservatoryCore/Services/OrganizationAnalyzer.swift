import Foundation

public struct OrganizationAnalyzer: Sendable {
    public init() {}

    public func map(assets: [AgentAsset], aiSummaries: [String: String]) -> OrganizationMap {
        let digests = assets.map { asset in
            OrganizationAssetDigest(asset: asset, aiSummary: aiSummaries[asset.contentHash])
        }
        let grouped = Dictionary(grouping: digests) { digest in
            BucketKey(audience: audience(for: digest.owner), kind: digest.kind)
        }
        let buckets = grouped.map { key, bucketAssets in
            let sortedAssets = bucketAssets.sorted { left, right in
                left.title.localizedCaseInsensitiveCompare(right.title) == .orderedAscending
            }
            return OrganizationBucket(
                audience: key.audience,
                kind: key.kind,
                title: "\(key.audience) \(key.kind.rawValue)",
                summary: bucketSummary(audience: key.audience, kind: key.kind, count: sortedAssets.count),
                assets: sortedAssets
            )
        }
        .sorted { left, right in
            if left.audience != right.audience {
                return left.audience < right.audience
            }
            return left.kind.rawValue < right.kind.rawValue
        }

        return OrganizationMap(
            totalAssets: assets.count,
            buckets: buckets,
            audienceCounts: countBy(digests.map { audience(for: $0.owner) }),
            kindCounts: countBy(assets.map(\.kind)),
            ownerCounts: countBy(assets.map(\.owner)),
            statusCounts: countBy(assets.flatMap(\.statusFlags))
        )
    }

    public func recommendations(for map: OrganizationMap, assets: [AgentAsset]) -> OrganizationPlan {
        var recommendations: [OrganizationRecommendation] = []
        recommendations.append(contentsOf: duplicateRecommendations(assets: assets))
        recommendations.append(contentsOf: statusRecommendations(assets: assets))

        let uniqueRecommendations = unique(recommendations)
        return OrganizationPlan(
            map: map,
            recommendations: uniqueRecommendations.sorted { left, right in
                if left.confidence != right.confidence { return left.confidence > right.confidence }
                return left.title.localizedCaseInsensitiveCompare(right.title) == .orderedAscending
            },
            source: "local"
        )
    }

    public func audience(for owner: AgentOwner) -> String {
        switch owner {
        case .claude:
            "Claude Code"
        case .codex:
            "Codex"
        case .agents:
            "Shared Agents"
        case .project:
            "Project"
        case .unknown:
            "Unknown"
        }
    }

    private func bucketSummary(audience: String, kind: AssetKind, count: Int) -> String {
        "\(count) \(kind.rawValue.lowercased()) asset\(count == 1 ? "" : "s") for \(audience)."
    }

    private func duplicateRecommendations(assets: [AgentAsset]) -> [OrganizationRecommendation] {
        let groups = Dictionary(grouping: assets) { asset in
            "\(asset.kind.rawValue)::\(asset.normalizedTitleKey)"
        }
        var recommendations: [OrganizationRecommendation] = []

        for group in groups.values where group.count > 1 {
            let sortedGroup = group.sorted { left, right in
                ownerPriority(left.owner) < ownerPriority(right.owner)
            }
            guard let primary = sortedGroup.first else { continue }
            recommendations.append(
                OrganizationRecommendation(
                    action: .merge,
                    title: "Merge duplicate \(primary.kind.rawValue): \(primary.title)",
                    reason: "Multiple \(primary.kind.rawValue.lowercased()) assets share the same normalized name. Review and merge the duplicate behavior before archiving anything.",
                    primaryAssetPath: primary.path,
                    relatedAssetPaths: sortedGroup.dropFirst().map(\.path),
                    confidence: 0.82
                )
            )
        }

        return recommendations
    }

    private func statusRecommendations(assets: [AgentAsset]) -> [OrganizationRecommendation] {
        assets.flatMap { asset in
            asset.statusFlags.compactMap { flag -> OrganizationRecommendation? in
                switch flag {
                case .stalePath:
                    OrganizationRecommendation(
                        action: .review,
                        title: "Review stale path references in \(asset.title)",
                        reason: "Stale path risk: the file still appears to reference Claude-era paths. Confirm whether it should be migrated, merged, or archived.",
                        primaryAssetPath: asset.path,
                        confidence: 0.78
                    )
                case .secretRisk:
                    OrganizationRecommendation(
                        action: .keep,
                        title: "Keep sensitive file protected: \(asset.title)",
                        reason: "This file looks sensitive. Keep it indexed for awareness, but do not send it to AI or archive it automatically.",
                        primaryAssetPath: asset.path,
                        confidence: 0.9
                    )
                case .unreadable:
                    OrganizationRecommendation(
                        action: .review,
                        title: "Review unreadable file: \(asset.title)",
                        reason: "The scanner could not read this file. Check permissions before deciding whether to keep or archive it.",
                        primaryAssetPath: asset.path,
                        confidence: 0.72
                    )
                case .needsSummary:
                    OrganizationRecommendation(
                        action: .review,
                        title: "Add or generate summary for \(asset.title)",
                        reason: "No explicit local description was found. This should be clarified before cleanup decisions.",
                        primaryAssetPath: asset.path,
                        confidence: 0.56
                    )
                case .largeFile:
                    OrganizationRecommendation(
                        action: .review,
                        title: "Review large file: \(asset.title)",
                        reason: "The file is large enough that preview was limited. Confirm it belongs in the active agent surface.",
                        primaryAssetPath: asset.path,
                        confidence: 0.48
                    )
                case .duplicate:
                    nil
                case .hasScripts:
                    nil
                }
            }
        }
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

    private func unique(_ recommendations: [OrganizationRecommendation]) -> [OrganizationRecommendation] {
        var seen: Set<String> = []
        return recommendations.filter { recommendation in
            seen.insert(recommendation.id).inserted
        }
    }
}

private struct BucketKey: Hashable {
    let audience: String
    let kind: AssetKind
}

private func countBy<Value: Hashable>(_ values: [Value]) -> [Value: Int] {
    Dictionary(values.map { ($0, 1) }, uniquingKeysWith: +)
}
