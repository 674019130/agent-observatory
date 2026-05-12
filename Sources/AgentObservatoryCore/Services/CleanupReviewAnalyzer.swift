import Foundation

public struct CleanupReviewAnalyzer: Sendable {
    public init() {}

    public func session(
        goal: CleanupReviewGoal,
        assets: [AgentAsset],
        language: AppLanguage = .english
    ) -> CleanupReviewSession {
        let groups = groups(goal: goal, assets: assets, language: language)
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

    private func groups(goal: CleanupReviewGoal, assets: [AgentAsset], language: AppLanguage) -> [CleanupReviewGroup] {
        switch goal {
        case .fullReview:
            duplicateGroups(assets: assets, language: language)
                + staleClaudeGroups(assets: assets, language: language)
                + noiseGroups(assets: assets, language: language)
                + riskGroups(assets: assets, language: language)
                + unclearGroups(assets: assets, language: language)
        case .legacyClaudeCleanup:
            staleClaudeGroups(assets: assets, language: language)
                + duplicateGroups(assets: assets, language: language).filter { group in
                    group.assetPaths.contains { path in path.localizedCaseInsensitiveContains(".claude") }
                }
        case .duplicateCleanup:
            duplicateGroups(assets: assets, language: language)
        case .noiseCleanup:
            noiseGroups(assets: assets, language: language) + unclearGroups(assets: assets, language: language)
        case .riskCleanup:
            riskGroups(assets: assets, language: language)
        }
    }

    private func duplicateGroups(assets: [AgentAsset], language: AppLanguage) -> [CleanupReviewGroup] {
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
            let kindText = L10n.assetKind(primary.kind, language: language)
            let owners = Set(sorted.map { L10n.agentOwner($0.owner, language: language) }).sorted().joined(separator: ", ")
            return CleanupReviewGroup(
                id: "duplicates-\(primary.kind.rawValue)-\(primary.normalizedTitleKey)",
                title: language == .simplifiedChinese
                    ? "合并重复\(kindText)：\(primary.title)"
                    : "Merge duplicate \(primary.kind.rawValue): \(primary.title)",
                summary: language == .simplifiedChinese
                    ? "这些文件看起来定义了相同的\(kindText)行为。先合并行为并检查差异，再决定是否归档。"
                    : "These files appear to define the same \(primary.kind.rawValue.lowercased()) behavior. Merge the behavior first; archive only after checking the diff.",
                action: .merge,
                risk: .medium,
                confidence: 0.82,
                assetPaths: sorted.map(\.path),
                evidence: duplicateEvidence(
                    count: sorted.count,
                    normalizedName: primary.normalizedTitleKey,
                    preferredOwner: L10n.agentOwner(sorted[0].owner, language: language),
                    owners: owners,
                    language: language
                )
            )
        }
    }

    private func staleClaudeGroups(assets: [AgentAsset], language: AppLanguage) -> [CleanupReviewGroup] {
        assets
            .filter { $0.statusFlags.contains(.stalePath) }
            .map { asset in
                CleanupReviewGroup(
                    id: "stale-claude-\(StableHash.hash(asset.path))",
                    title: language == .simplifiedChinese
                        ? "复核 Claude 时期引用：\(asset.title)"
                        : "Review Claude-era reference: \(asset.title)",
                    summary: language == .simplifiedChinese
                        ? "这个文件仍引用 Claude 时期路径。判断它应该迁移、合并还是归档。"
                        : "This file still references a Claude-era path. Decide whether it should be migrated, merged, or archived.",
                    action: .review,
                    risk: .high,
                    confidence: 0.78,
                    assetPaths: [asset.path],
                    evidence: staleClaudeEvidence(asset: asset, language: language)
                )
            }
    }

    private func noiseGroups(assets: [AgentAsset], language: AppLanguage) -> [CleanupReviewGroup] {
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
                title: language == .simplifiedChinese
                    ? "隐藏低信号索引噪音"
                    : "Hide low-signal indexed noise",
                summary: language == .simplifiedChinese
                    ? "会话和未知文件通常只会增加扫描噪音；隐藏是可恢复操作，之后仍可从隐藏项目中恢复。"
                    : "Session and unknown files usually add scanning noise but are still recoverable from Hidden Items if hidden.",
                action: .hide,
                risk: .low,
                confidence: 0.74,
                assetPaths: noise.map(\.path),
                evidence: noiseEvidence(count: noise.count, language: language)
            )
        ]
    }

    private func riskGroups(assets: [AgentAsset], language: AppLanguage) -> [CleanupReviewGroup] {
        let riskAssets = assets
            .filter { asset in
                asset.statusFlags.contains(.secretRisk) || asset.statusFlags.contains(.unreadable)
            }
            .sorted { $0.path < $1.path }

        guard !riskAssets.isEmpty else { return [] }

        return [
            CleanupReviewGroup(
                id: "risk-sensitive-unreadable",
                title: language == .simplifiedChinese
                    ? "复核敏感或不可读文件"
                    : "Review sensitive or unreadable files",
                summary: language == .simplifiedChinese
                    ? "这些文件应该保留可见用于提醒，但不应发送给 AI，也不应批量归档。"
                    : "These files should stay visible for awareness, but should not be sent to AI or batch archived.",
                action: .review,
                risk: .high,
                confidence: 0.9,
                assetPaths: riskAssets.map(\.path),
                evidence: riskEvidence(count: riskAssets.count, language: language)
            )
        ]
    }

    private func unclearGroups(assets: [AgentAsset], language: AppLanguage) -> [CleanupReviewGroup] {
        let unclear = assets
            .filter { $0.statusFlags.contains(.needsSummary) }
            .sorted { $0.path < $1.path }

        guard !unclear.isEmpty else { return [] }

        return [
            CleanupReviewGroup(
                id: "unclear-needs-summary",
                title: language == .simplifiedChinese
                    ? "澄清缺少有效摘要的文件"
                    : "Clarify files with no useful summary",
                summary: language == .simplifiedChinese
                    ? "这些文件需要先补充描述，整理决策才可信。"
                    : "These files need a description before cleanup decisions are trustworthy.",
                action: .review,
                risk: .medium,
                confidence: 0.56,
                assetPaths: unclear.map(\.path),
                evidence: unclearEvidence(count: unclear.count, language: language)
            )
        ]
    }

    private func duplicateEvidence(
        count: Int,
        normalizedName: String,
        preferredOwner: String,
        owners: String,
        language: AppLanguage
    ) -> [String] {
        if language == .simplifiedChinese {
            return [
                "\(count) 个文件共享规范化名称“\(normalizedName)”。",
                "优先保留的活跃归属是 \(preferredOwner)。",
                "涉及归属：\(owners)。"
            ]
        }
        return [
            "\(count) files share normalized name \"\(normalizedName)\".",
            "Preferred active owner is \(preferredOwner).",
            "Owners involved: \(owners)."
        ]
    }

    private func staleClaudeEvidence(asset: AgentAsset, language: AppLanguage) -> [String] {
        if language == .simplifiedChinese {
            return [
                "扫描器将这个文件标记为过期 Claude 路径。",
                "归属是 \(L10n.agentOwner(asset.owner, language: language))，类型是 \(L10n.assetKind(asset.kind, language: language))。",
                "路径：\(asset.displayPath)"
            ]
        }
        return [
            "Scanner marked this file with a stale Claude path flag.",
            "Owner is \(asset.owner.rawValue), kind is \(asset.kind.rawValue).",
            "Path: \(asset.displayPath)"
        ]
    }

    private func noiseEvidence(count: Int, language: AppLanguage) -> [String] {
        if language == .simplifiedChinese {
            return [
                "\(count) 个会话或未知文件当前显示在活跃索引中。",
                "隐藏是可恢复操作，不会移动文件。",
                "敏感或不可读文件已从这批操作中排除。"
            ]
        }
        return [
            "\(count) session or unknown files are visible in the active index.",
            "Hide is reversible and does not move files.",
            "Sensitive or unreadable files are excluded from this batch."
        ]
    }

    private func riskEvidence(count: Int, language: AppLanguage) -> [String] {
        if language == .simplifiedChinese {
            return [
                "\(count) 个文件带有密钥风险或不可读状态。",
                "敏感路径会避开 AI 预览。",
                "需要人工检查权限和内容。"
            ]
        }
        return [
            "\(count) files carry secret or unreadable status flags.",
            "AI preview is avoided for sensitive paths.",
            "Manual permission and contents review is required."
        ]
    }

    private func unclearEvidence(count: Int, language: AppLanguage) -> [String] {
        if language == .simplifiedChinese {
            return [
                "\(count) 个文件没有明确的本地摘要。",
                "整理前先让 AI 解释单个文件，或手动补充描述。",
                "当前不建议自动执行文件操作。"
            ]
        }
        return [
            "\(count) files have no explicit local summary.",
            "Ask AI to explain individual files or add descriptions before cleanup.",
            "No automatic file operation is recommended."
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
