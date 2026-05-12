import Foundation

public struct OrganizerAdvisor: Sendable {
    public init() {}

    public func brief(
        map: OrganizationMap,
        assets: [AgentAsset],
        language: AppLanguage = .english
    ) -> OrganizerBrief {
        guard map.totalAssets > 0 else {
            return emptyBrief(language: language)
        }

        let recommendedGoal = recommendedGoal(map: map, assets: assets)
        let goalName = L10n.cleanupGoal(recommendedGoal, language: language)
        let headline = headline(for: map, language: language)
        let summary = summary(for: map, recommendedGoalName: goalName, language: language)

        return OrganizerBrief(
            headline: headline,
            summary: summary,
            landscape: landscape(for: map, assets: assets, language: language),
            focusAreas: focusAreas(for: map, assets: assets, language: language),
            recommendedGoal: recommendedGoal
        )
    }

    private func emptyBrief(language: AppLanguage) -> OrganizerBrief {
        OrganizerBrief(
            headline: language == .simplifiedChinese
                ? "还没有索引到 agent 资产。"
                : "No agent assets indexed yet.",
            summary: language == .simplifiedChinese
                ? "先从启用来源生成地图，再让整理顾问判断应该清理、合并还是保留。"
                : "Build a map from enabled sources before deciding what to clean up, merge, or keep.",
            landscape: [],
            focusAreas: [
                language == .simplifiedChinese
                    ? "生成地图后再开始完整整理审查。"
                    : "Build a map, then start a full cleanup review."
            ],
            recommendedGoal: .fullReview
        )
    }

    private func headline(for map: OrganizationMap, language: AppLanguage) -> String {
        if language == .simplifiedChinese {
            return "当前有 \(map.totalAssets) 个 agent 资产，分布在 \(map.buckets.count) 个整理分组。"
        }
        return "\(map.totalAssets) agent assets across \(map.buckets.count) organization buckets."
    }

    private func summary(
        for map: OrganizationMap,
        recommendedGoalName: String,
        language: AppLanguage
    ) -> String {
        let owner = dominantOwner(in: map)
        let ownerLabel = owner.map { OrganizationAnalyzer().audience(for: $0, language: language) }
            ?? L10n.text(.unknown, language: language)
        let ownerCount = owner.flatMap { map.ownerCounts[$0] } ?? 0

        if language == .simplifiedChinese {
            return "主要活动面在 \(ownerLabel)（\(ownerCount) 个），建议先做“\(recommendedGoalName)”。"
        }
        return "The main active surface is \(ownerLabel) (\(ownerCount) items), so start with \(recommendedGoalName)."
    }

    private func landscape(
        for map: OrganizationMap,
        assets: [AgentAsset],
        language: AppLanguage
    ) -> [String] {
        let ownerBreakdown = topCounts(map.ownerCounts) { owner in
            OrganizationAnalyzer().audience(for: owner, language: language)
        }
        let kindBreakdown = topCounts(map.kindCounts) { kind in
            L10n.assetKind(kind, language: language)
        }
        let warningCount = warningCount(in: map)
        let aiCovered = aiCoveredAssetCount(in: map)

        if language == .simplifiedChinese {
            return [
                ownerBreakdown.isEmpty ? nil : "归属分布：\(ownerBreakdown)。",
                kindBreakdown.isEmpty ? nil : "主要类型：\(kindBreakdown)。",
                warningCount > 0 ? "本地扫描发现 \(warningCount) 个需要关注的状态标记。" : "本地扫描暂未发现明显风险标记。",
                "AI 摘要覆盖：\(aiCovered)/\(assets.count) 个资产。"
            ].compactMap { $0 }
        }

        return [
            ownerBreakdown.isEmpty ? nil : "Ownership: \(ownerBreakdown).",
            kindBreakdown.isEmpty ? nil : "Main categories: \(kindBreakdown).",
            warningCount > 0 ? "\(warningCount) local status flags need attention." : "No obvious local warning flags in this map.",
            "AI summary coverage: \(aiCovered)/\(assets.count) assets."
        ].compactMap { $0 }
    }

    private func focusAreas(
        for map: OrganizationMap,
        assets: [AgentAsset],
        language: AppLanguage
    ) -> [String] {
        var focus: [String] = []
        let riskCount = statusCount([.secretRisk, .unreadable], in: map)
        let duplicateCount = statusCount([.duplicate], in: map)
        let staleCount = statusCount([.stalePath], in: map)
        let noiseCount = assets.filter { $0.kind == .session || $0.kind == .unknown }.count
        let unclearCount = statusCount([.needsSummary], in: map)

        if riskCount > 0 {
            focus.append(language == .simplifiedChinese
                ? "先人工复核 \(riskCount) 个敏感或不可读文件，不要把它们发送给 AI。"
                : "Review \(riskCount) sensitive or unreadable files before sending anything to AI.")
        }
        if staleCount > 0 {
            focus.append(language == .simplifiedChinese
                ? "复核 \(staleCount) 个 Claude 旧路径引用，判断迁移、合并还是归档。"
                : "Review \(staleCount) Claude-era path references before migrating or archiving.")
        }
        if duplicateCount > 0 {
            focus.append(language == .simplifiedChinese
                ? "把 \(duplicateCount) 个重复标记整理成少量清晰的合并决策。"
                : "Turn \(duplicateCount) duplicate flags into a smaller set of merge decisions.")
        }
        if noiseCount > 0 {
            focus.append(language == .simplifiedChinese
                ? "隐藏 \(noiseCount) 个会话或未知文件，降低默认索引噪音。"
                : "Hide \(noiseCount) session or unknown files to reduce default index noise.")
        }
        if unclearCount > 0 {
            focus.append(language == .simplifiedChinese
                ? "为 \(unclearCount) 个缺少摘要的文件补充说明，再做管理决策。"
                : "Clarify \(unclearCount) files with missing summaries before making management decisions.")
        }

        if focus.isEmpty {
            focus.append(language == .simplifiedChinese
                ? "当前没有明显整理压力，可以从完整整理开始做一次抽样复核。"
                : "No obvious cleanup pressure; start with a full review for a light sanity check.")
        }

        return Array(focus.prefix(4))
    }

    private func recommendedGoal(map: OrganizationMap, assets: [AgentAsset]) -> CleanupReviewGoal {
        if statusCount([.secretRisk, .unreadable], in: map) > 0 {
            return .riskCleanup
        }
        if statusCount([.duplicate], in: map) > 0 {
            return .duplicateCleanup
        }
        if statusCount([.stalePath], in: map) > 0 {
            return .legacyClaudeCleanup
        }
        if assets.contains(where: { $0.kind == .session || $0.kind == .unknown })
            || statusCount([.needsSummary], in: map) > 0 {
            return .noiseCleanup
        }
        return .fullReview
    }

    private func dominantOwner(in map: OrganizationMap) -> AgentOwner? {
        map.ownerCounts.sorted { left, right in
            if left.value != right.value { return left.value > right.value }
            return left.key.rawValue < right.key.rawValue
        }
        .first?
        .key
    }

    private func topCounts<Value>(
        _ counts: [Value: Int],
        label: (Value) -> String
    ) -> String where Value: Hashable {
        counts
            .sorted { left, right in
                if left.value != right.value { return left.value > right.value }
                return label(left.key) < label(right.key)
            }
            .prefix(4)
            .map { "\(label($0.key)) \($0.value)" }
            .joined(separator: ", ")
    }

    private func aiCoveredAssetCount(in map: OrganizationMap) -> Int {
        map.buckets
            .flatMap(\.assets)
            .filter { digest in
                guard let aiSummary = digest.aiSummary else { return false }
                return !aiSummary.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            }
            .count
    }

    private func warningCount(in map: OrganizationMap) -> Int {
        statusCount([.duplicate, .stalePath, .needsSummary, .secretRisk, .largeFile, .unreadable], in: map)
    }

    private func statusCount(_ flags: [AssetStatusFlag], in map: OrganizationMap) -> Int {
        flags.reduce(0) { total, flag in
            total + (map.statusCounts[flag] ?? 0)
        }
    }
}
