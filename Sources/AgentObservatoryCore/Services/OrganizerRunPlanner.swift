import Foundation

public struct OrganizerRunPlanner: Sendable {
    public init() {}

    public func plan(
        map: OrganizationMap,
        assets: [AgentAsset],
        language: AppLanguage = .english
    ) -> OrganizerRun {
        guard !assets.isEmpty else {
            return OrganizerRun(
                status: .empty,
                title: language == .simplifiedChinese ? "还没有可整理的资产" : "No assets to organize yet",
                summary: language == .simplifiedChinese
                    ? "先生成地图，整理器会基于启用来源诊断配置形态。"
                    : "Build a map first so the organizer can diagnose enabled sources.",
                totalAssetCount: 0,
                duplicateAssetCount: 0,
                noiseAssetCount: 0,
                sensitiveAssetCount: 0,
                stalePathAssetCount: 0,
                unclearAssetCount: 0,
                actionPacks: []
            )
        }

        let duplicateGroups = duplicateAssetGroups(in: assets)
        let duplicatePaths = duplicateGroups.flatMap { $0.map(\.path) }
        let noiseAssets = assets.filter { asset in
            (asset.kind == .session || asset.kind == .unknown)
                && !asset.statusFlags.contains(.secretRisk)
                && !asset.statusFlags.contains(.unreadable)
        }
        let sensitiveAssets = assets.filter { $0.statusFlags.contains(.secretRisk) }
        let unreadableAssets = assets.filter { asset in
            asset.statusFlags.contains(.unreadable) && !asset.statusFlags.contains(.secretRisk)
        }
        let stalePathAssets = assets.filter { $0.statusFlags.contains(.stalePath) }
        let unclearAssets = assets.filter { $0.statusFlags.contains(.needsSummary) }

        var packs: [OrganizerActionPack] = []
        if !duplicateGroups.isEmpty {
            packs.append(duplicatePack(groups: duplicateGroups, language: language))
        }
        if !noiseAssets.isEmpty {
            packs.append(noisePack(assets: noiseAssets, language: language))
        }
        if !sensitiveAssets.isEmpty {
            packs.append(sensitivePack(assets: sensitiveAssets, language: language))
        }
        if !unreadableAssets.isEmpty {
            packs.append(unreadablePack(assets: unreadableAssets, language: language))
        }
        if !unclearAssets.isEmpty {
            packs.append(unclearPack(assets: unclearAssets, language: language))
        }
        if !stalePathAssets.isEmpty {
            packs.append(stalePack(assets: stalePathAssets, language: language))
        }

        return OrganizerRun(
            status: .ready,
            title: title(total: assets.count, map: map, language: language),
            summary: summary(
                total: assets.count,
                duplicateCount: duplicatePaths.count,
                noiseCount: noiseAssets.count,
            sensitiveCount: sensitiveAssets.count,
                language: language
            ),
            totalAssetCount: assets.count,
            duplicateAssetCount: duplicatePaths.count,
            noiseAssetCount: noiseAssets.count,
            sensitiveAssetCount: sensitiveAssets.count,
            stalePathAssetCount: stalePathAssets.count,
            unclearAssetCount: unclearAssets.count,
            actionPacks: packs
        )
    }

    private func duplicateAssetGroups(in assets: [AgentAsset]) -> [[AgentAsset]] {
        Dictionary(grouping: assets) { asset in
            "\(asset.kind.rawValue)::\(asset.normalizedTitleKey)"
        }
        .values
        .filter { $0.count > 1 }
        .map { group in
            group.sorted { left, right in
                if ownerPriority(left.owner) != ownerPriority(right.owner) {
                    return ownerPriority(left.owner) < ownerPriority(right.owner)
                }
                return left.path < right.path
            }
        }
        .sorted { left, right in
            (left.first?.title ?? "") < (right.first?.title ?? "")
        }
    }

    private func duplicatePack(groups: [[AgentAsset]], language: AppLanguage) -> OrganizerActionPack {
        let allPaths = groups.flatMap { $0.map(\.path) }
        let archivePaths = groups.flatMap { group in group.dropFirst().map(\.path) }
        return OrganizerActionPack(
            id: "merge-duplicates",
            kind: .mergeDuplicates,
            title: language == .simplifiedChinese ? "合并重复资产" : "Merge duplicate assets",
            summary: language == .simplifiedChinese
                ? "保留每组优先资产，归档 \(archivePaths.count) 个重复项。"
                : "Keep the preferred asset in each group and archive \(archivePaths.count) duplicates.",
            risk: .medium,
            assetPaths: allPaths,
            executableAssetPaths: archivePaths,
            isReversible: true,
            requiresHumanReview: false
        )
    }

    private func noisePack(assets: [AgentAsset], language: AppLanguage) -> OrganizerActionPack {
        OrganizerActionPack(
            id: "hide-noise",
            kind: .hideNoise,
            title: language == .simplifiedChinese ? "隐藏低信号噪音" : "Hide low-signal noise",
            summary: language == .simplifiedChinese
                ? "隐藏 \(assets.count) 个会话或未知文件，降低默认列表噪音。"
                : "Hide \(assets.count) session or unknown files from the default list.",
            risk: .low,
            assetPaths: assets.map(\.path),
            executableAssetPaths: assets.map(\.path),
            isReversible: true,
            requiresHumanReview: false
        )
    }

    private func sensitivePack(assets: [AgentAsset], language: AppLanguage) -> OrganizerActionPack {
        OrganizerActionPack(
            id: "review-sensitive",
            kind: .reviewSensitive,
            title: language == .simplifiedChinese ? "保留敏感文件提醒" : "Keep sensitive files visible",
            summary: language == .simplifiedChinese
                ? "\(assets.count) 个敏感文件不会发送给 AI，也不会批量归档。"
                : "\(assets.count) sensitive files will not be sent to AI or archived in bulk.",
            risk: .high,
            assetPaths: assets.map(\.path),
            executableAssetPaths: [],
            isReversible: false,
            requiresHumanReview: true
        )
    }

    private func unreadablePack(assets: [AgentAsset], language: AppLanguage) -> OrganizerActionPack {
        OrganizerActionPack(
            id: "review-unreadable",
            kind: .reviewUnreadable,
            title: language == .simplifiedChinese ? "检查不可读文件" : "Check unreadable files",
            summary: language == .simplifiedChinese
                ? "\(assets.count) 个文件扫描器无法读取。先检查权限或文件状态。"
                : "\(assets.count) files could not be read. Check permissions or file state first.",
            risk: .medium,
            assetPaths: assets.map(\.path),
            executableAssetPaths: [],
            isReversible: false,
            requiresHumanReview: true
        )
    }

    private func unclearPack(assets: [AgentAsset], language: AppLanguage) -> OrganizerActionPack {
        OrganizerActionPack(
            id: "clarify-unknown",
            kind: .clarifyUnknown,
            title: language == .simplifiedChinese ? "澄清缺少说明的文件" : "Clarify files without descriptions",
            summary: language == .simplifiedChinese
                ? "\(assets.count) 个文件需要先补充说明，再决定是否整理。"
                : "\(assets.count) files need clearer descriptions before cleanup decisions.",
            risk: .medium,
            assetPaths: assets.map(\.path),
            executableAssetPaths: [],
            isReversible: false,
            requiresHumanReview: true
        )
    }

    private func stalePack(assets: [AgentAsset], language: AppLanguage) -> OrganizerActionPack {
        OrganizerActionPack(
            id: "review-stale-paths",
            kind: .reviewStalePaths,
            title: language == .simplifiedChinese ? "复核旧路径引用" : "Review stale path references",
            summary: language == .simplifiedChinese
                ? "\(assets.count) 个文件仍引用旧路径，需要人工判断迁移或归档。"
                : "\(assets.count) files still reference stale paths and need manual migration or archive decisions.",
            risk: .high,
            assetPaths: assets.map(\.path),
            executableAssetPaths: [],
            isReversible: false,
            requiresHumanReview: true
        )
    }

    private func title(total: Int, map: OrganizationMap, language: AppLanguage) -> String {
        if language == .simplifiedChinese {
            return "\(total) 个资产，\(map.buckets.count) 个配置分组"
        }
        return "\(total) assets across \(map.buckets.count) configuration groups"
    }

    private func summary(
        total: Int,
        duplicateCount: Int,
        noiseCount: Int,
        sensitiveCount: Int,
        language: AppLanguage
    ) -> String {
        if language == .simplifiedChinese {
            return "整理器已诊断 \(total) 个资产：\(duplicateCount) 个重复信号，\(noiseCount) 个低信号噪音，\(sensitiveCount) 个敏感文件。"
        }
        return "Organizer diagnosed \(total) assets: \(duplicateCount) duplicate signals, \(noiseCount) low-signal files, and \(sensitiveCount) sensitive files."
    }

    private func ownerPriority(_ owner: AgentOwner) -> Int {
        switch owner {
        case .agents: 0
        case .codex: 1
        case .project: 2
        case .claude: 3
        case .unknown: 4
        }
    }
}
