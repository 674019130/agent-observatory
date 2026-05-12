import Foundation

public struct OrganizationAnalyzer: Sendable {
    public init() {}

    public func map(
        assets: [AgentAsset],
        aiSummaries: [String: String],
        language: AppLanguage = .english
    ) -> OrganizationMap {
        let digests = assets.map { asset in
            OrganizationAssetDigest(asset: asset, aiSummary: aiSummaries[asset.contentHash])
        }
        let grouped = Dictionary(grouping: digests) { digest in
            BucketKey(audience: audience(for: digest.owner, language: language), kind: digest.kind)
        }
        let buckets = grouped.map { key, bucketAssets in
            let sortedAssets = bucketAssets.sorted { left, right in
                left.title.localizedCaseInsensitiveCompare(right.title) == .orderedAscending
            }
            return OrganizationBucket(
                audience: key.audience,
                kind: key.kind,
                title: bucketTitle(audience: key.audience, kind: key.kind, language: language),
                summary: bucketSummary(audience: key.audience, kind: key.kind, count: sortedAssets.count, language: language),
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
            audienceCounts: countBy(digests.map { audience(for: $0.owner, language: language) }),
            kindCounts: countBy(assets.map(\.kind)),
            ownerCounts: countBy(assets.map(\.owner)),
            statusCounts: countBy(assets.flatMap(\.statusFlags))
        )
    }

    public func recommendations(
        for map: OrganizationMap,
        assets: [AgentAsset],
        language: AppLanguage = .english
    ) -> OrganizationPlan {
        var recommendations: [OrganizationRecommendation] = []
        recommendations.append(contentsOf: duplicateRecommendations(assets: assets, language: language))
        recommendations.append(contentsOf: statusRecommendations(assets: assets, language: language))

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

    public func audience(for owner: AgentOwner, language: AppLanguage = .english) -> String {
        switch (owner, language) {
        case (.claude, _):
            "Claude Code"
        case (.codex, _):
            "Codex"
        case (.agents, .simplifiedChinese):
            "共享 Agents"
        case (.agents, _):
            "Shared Agents"
        case (.project, .simplifiedChinese):
            "项目"
        case (.project, _):
            "Project"
        case (.unknown, .simplifiedChinese):
            L10n.text(.unknown, language: language)
        case (.unknown, _):
            "Unknown"
        }
    }

    private func bucketTitle(audience: String, kind: AssetKind, language: AppLanguage) -> String {
        "\(audience) \(L10n.assetKind(kind, language: language))"
    }

    private func bucketSummary(audience: String, kind: AssetKind, count: Int, language: AppLanguage) -> String {
        if language == .simplifiedChinese {
            return "\(audience) 下有 \(count) 个\(L10n.assetKind(kind, language: language))资产。"
        }
        return "\(count) \(kind.rawValue.lowercased()) asset\(count == 1 ? "" : "s") for \(audience)."
    }

    private func duplicateRecommendations(assets: [AgentAsset], language: AppLanguage) -> [OrganizationRecommendation] {
        let groups = Dictionary(grouping: assets) { asset in
            "\(asset.kind.rawValue)::\(asset.normalizedTitleKey)"
        }
        var recommendations: [OrganizationRecommendation] = []

        for group in groups.values where group.count > 1 {
            let sortedGroup = group.sorted { left, right in
                ownerPriority(left.owner) < ownerPriority(right.owner)
            }
            guard let primary = sortedGroup.first else { continue }
            let kindText = L10n.assetKind(primary.kind, language: language)
            recommendations.append(
                OrganizationRecommendation(
                    action: .merge,
                    title: language == .simplifiedChinese
                        ? "合并重复\(kindText)：\(primary.title)"
                        : "Merge duplicate \(primary.kind.rawValue): \(primary.title)",
                    reason: language == .simplifiedChinese
                        ? "多个\(kindText)资产使用相同的规范化名称。先复核并合并重复行为，再决定是否归档。"
                        : "Multiple \(primary.kind.rawValue.lowercased()) assets share the same normalized name. Review and merge the duplicate behavior before archiving anything.",
                    primaryAssetPath: primary.path,
                    relatedAssetPaths: sortedGroup.dropFirst().map(\.path),
                    confidence: 0.82
                )
            )
        }

        return recommendations
    }

    private func statusRecommendations(assets: [AgentAsset], language: AppLanguage) -> [OrganizationRecommendation] {
        assets.flatMap { asset in
            asset.statusFlags.compactMap { flag -> OrganizationRecommendation? in
                switch flag {
                case .stalePath:
                    OrganizationRecommendation(
                        action: .review,
                        title: language == .simplifiedChinese
                            ? "检查 \(asset.title) 中的过期路径引用"
                            : "Review stale path references in \(asset.title)",
                        reason: language == .simplifiedChinese
                            ? "过期路径风险：这个文件看起来仍引用 Claude 时期路径。确认它应该迁移、合并还是归档。"
                            : "Stale path risk: the file still appears to reference Claude-era paths. Confirm whether it should be migrated, merged, or archived.",
                        primaryAssetPath: asset.path,
                        confidence: 0.78
                    )
                case .secretRisk:
                    OrganizationRecommendation(
                        action: .keep,
                        title: language == .simplifiedChinese
                            ? "保护敏感文件：\(asset.title)"
                            : "Keep sensitive file protected: \(asset.title)",
                        reason: language == .simplifiedChinese
                            ? "这个文件看起来包含敏感内容。保留在索引中用于提醒，但不要发送给 AI，也不要自动归档。"
                            : "This file looks sensitive. Keep it indexed for awareness, but do not send it to AI or archive it automatically.",
                        primaryAssetPath: asset.path,
                        confidence: 0.9
                    )
                case .unreadable:
                    OrganizationRecommendation(
                        action: .review,
                        title: language == .simplifiedChinese
                            ? "检查不可读文件：\(asset.title)"
                            : "Review unreadable file: \(asset.title)",
                        reason: language == .simplifiedChinese
                            ? "扫描器无法读取该文件。先检查权限，再决定保留还是归档。"
                            : "The scanner could not read this file. Check permissions before deciding whether to keep or archive it.",
                        primaryAssetPath: asset.path,
                        confidence: 0.72
                    )
                case .needsSummary:
                    OrganizationRecommendation(
                        action: .review,
                        title: language == .simplifiedChinese
                            ? "为 \(asset.title) 补充摘要"
                            : "Add or generate summary for \(asset.title)",
                        reason: language == .simplifiedChinese
                            ? "本地没有找到明确描述。整理前需要先弄清它的用途。"
                            : "No explicit local description was found. This should be clarified before cleanup decisions.",
                        primaryAssetPath: asset.path,
                        confidence: 0.56
                    )
                case .largeFile:
                    OrganizationRecommendation(
                        action: .review,
                        title: language == .simplifiedChinese
                            ? "检查大文件：\(asset.title)"
                            : "Review large file: \(asset.title)",
                        reason: language == .simplifiedChinese
                            ? "文件较大，预览已被限制。确认它是否应该继续留在活跃 agent 配置面中。"
                            : "The file is large enough that preview was limited. Confirm it belongs in the active agent surface.",
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
