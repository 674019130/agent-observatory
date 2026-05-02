import Foundation

public struct DashboardAnalyzer: Sendable {
    public init() {}

    public func summary(
        assets: [AgentAsset],
        changeSummary: AssetChangeSummary,
        aiSummaries: [String: String],
        activeSourceCount: Int,
        existingSourceCount: Int,
        isIndexStale: Bool
    ) -> DashboardSummary {
        let referenceIndex = AssetReferenceIndex(assets: assets)
        let impactAnalyzer = AssetImpactAnalyzer(index: referenceIndex)
        let impacts = Dictionary(uniqueKeysWithValues: assets.map { asset in
            (asset.path, impactAnalyzer.impact(for: asset))
        })

        return DashboardSummary(
            indexHealth: DashboardIndexHealth(
                totalAssets: assets.count,
                warningCount: assets.filter { !$0.statusFlags.isEmpty }.count,
                activeSourceCount: activeSourceCount,
                existingSourceCount: existingSourceCount,
                isStale: isIndexStale
            ),
            topRisks: topRisks(for: assets, impacts: impacts),
            drift: driftSummary(for: assets),
            recentChanges: changeSummary,
            dependencyHotspots: dependencyHotspots(for: assets, impacts: impacts),
            aiCoverage: aiCoverage(for: assets, aiSummaries: aiSummaries)
        )
    }

    private func topRisks(for assets: [AgentAsset], impacts: [String: AssetImpact]) -> [DashboardRiskItem] {
        var risks: [DashboardRiskItem] = []

        for asset in assets {
            if let impact = impacts[asset.path] {
                risks.append(contentsOf: impact.outgoingReferences.compactMap { link in
                    guard link.isMissing else { return nil }
                    return risk(
                        asset: asset,
                        category: .missingDependency,
                        severity: .critical,
                        message: "Missing reference: \(link.reference)",
                        score: 100
                    )
                })

                if impact.staleReferenceCount > 0 {
                    risks.append(
                        risk(
                            asset: asset,
                            category: .staleReference,
                            severity: .high,
                            message: "\(impact.staleReferenceCount) reference still points at Claude-era paths.",
                            score: 82
                        )
                    )
                }
            }

            for flag in asset.statusFlags {
                risks.append(risk(asset: asset, flag: flag))
            }
        }

        return Array(
            Dictionary(grouping: risks, by: \.id)
                .compactMap { $0.value.first }
        )
        .sorted { left, right in
            if left.score != right.score { return left.score > right.score }
            return left.assetTitle.localizedCaseInsensitiveCompare(right.assetTitle) == .orderedAscending
        }
        .prefix(10)
        .map { $0 }
    }

    private func risk(asset: AgentAsset, flag: AssetStatusFlag) -> DashboardRiskItem {
        switch flag {
        case .secretRisk:
            risk(asset: asset, category: .sensitiveFile, severity: .high, message: "Sensitive file is protected from preview and LLM enrichment.", score: 86)
        case .unreadable:
            risk(asset: asset, category: .unreadable, severity: .high, message: "The scanner could not read this file.", score: 84)
        case .stalePath:
            risk(asset: asset, category: .stalePath, severity: .high, message: "File content still references Claude-era paths.", score: 80)
        case .duplicate:
            risk(asset: asset, category: .duplicate, severity: .medium, message: "Another indexed asset has the same normalized identity.", score: 55)
        case .largeFile:
            risk(asset: asset, category: .largeFile, severity: .medium, message: "Preview was limited because the file is large.", score: 45)
        case .needsSummary:
            risk(asset: asset, category: .needsSummary, severity: .low, message: "No local description was found.", score: 20)
        case .hasScripts:
            risk(asset: asset, category: .staleReference, severity: .low, message: "This asset has nearby scripts or script dependencies.", score: 10)
        }
    }

    private func risk(
        asset: AgentAsset,
        category: DashboardRiskCategory,
        severity: DashboardRiskSeverity,
        message: String,
        score: Int
    ) -> DashboardRiskItem {
        DashboardRiskItem(
            assetPath: asset.path,
            assetTitle: asset.title,
            owner: asset.owner,
            kind: asset.kind,
            category: category,
            severity: severity,
            message: message,
            score: score
        )
    }

    private func driftSummary(for assets: [AgentAsset]) -> DashboardDriftSummary {
        let comparable = assets.filter { [.claude, .codex, .agents].contains($0.owner) }
        let grouped = Dictionary(grouping: comparable, by: \.normalizedKey)

        var same = 0
        var changed = 0
        var missing = 0

        for group in grouped.values {
            let owners = Set(group.map(\.owner))
            guard owners.contains(.claude) || owners.contains(.codex) || owners.contains(.agents) else {
                continue
            }

            if group.count < 2 {
                missing += 1
                continue
            }

            let hashes = Set(group.map(\.contentHash))
            if hashes.count == 1 {
                same += 1
            } else {
                changed += 1
            }
        }

        return DashboardDriftSummary(same: same, changed: changed, missingCounterpart: missing)
    }

    private func dependencyHotspots(for assets: [AgentAsset], impacts: [String: AssetImpact]) -> [DashboardDependencyHotspot] {
        assets.compactMap { asset in
            guard let impact = impacts[asset.path] else { return nil }
            let hotspot = DashboardDependencyHotspot(
                assetPath: asset.path,
                assetTitle: asset.title,
                owner: asset.owner,
                kind: asset.kind,
                incomingCount: impact.incomingReferences.count,
                missingOutgoingCount: impact.missingReferenceCount,
                staleReferenceCount: impact.staleReferenceCount
            )
            return hotspot.score > 0 ? hotspot : nil
        }
        .sorted { left, right in
            if left.score != right.score { return left.score > right.score }
            return left.assetTitle.localizedCaseInsensitiveCompare(right.assetTitle) == .orderedAscending
        }
        .prefix(8)
        .map { $0 }
    }

    private func aiCoverage(for assets: [AgentAsset], aiSummaries: [String: String]) -> DashboardAICoverage {
        let explained = assets.filter { aiSummaries[$0.contentHash]?.isEmpty == false }.count
        return DashboardAICoverage(explained: explained, missing: max(0, assets.count - explained))
    }
}
