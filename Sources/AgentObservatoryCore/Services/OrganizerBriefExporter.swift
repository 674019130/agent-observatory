import Foundation

public struct OrganizerBriefExporter: Sendable {
    public init() {}

    public func markdown(
        brief: OrganizerBrief,
        map: OrganizationMap,
        language: AppLanguage = .english
    ) -> String {
        if language == .simplifiedChinese {
            return chineseMarkdown(brief: brief, map: map)
        }
        return englishMarkdown(brief: brief, map: map)
    }

    private func chineseMarkdown(brief: OrganizerBrief, map: OrganizationMap) -> String {
        sections([
            "# Agent 配置简报",
            brief.headline,
            brief.summary,
            "资产总数：\(map.totalAssets)",
            "分组数量：\(map.buckets.count)",
            "推荐路径：\(L10n.cleanupGoal(brief.recommendedGoal, language: .simplifiedChinese))",
            listSection(title: "当前结构", items: brief.landscape),
            listSection(title: "优先关注", items: brief.focusAreas)
        ])
    }

    private func englishMarkdown(brief: OrganizerBrief, map: OrganizationMap) -> String {
        sections([
            "# Agent Configuration Brief",
            brief.headline,
            brief.summary,
            "Total assets: \(map.totalAssets)",
            "Buckets: \(map.buckets.count)",
            "Recommended route: \(L10n.cleanupGoal(brief.recommendedGoal, language: .english))",
            listSection(title: "Current Shape", items: brief.landscape),
            listSection(title: "Priority Focus", items: brief.focusAreas)
        ])
    }

    private func listSection(title: String, items: [String]) -> String {
        guard !items.isEmpty else { return "## \(title)\n- -" }
        return "## \(title)\n" + items.map { "- \($0)" }.joined(separator: "\n")
    }

    private func sections(_ values: [String]) -> String {
        values
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: "\n\n")
    }
}
