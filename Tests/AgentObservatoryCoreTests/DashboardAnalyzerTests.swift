import XCTest
@testable import AgentObservatoryCore

final class DashboardAnalyzerTests: XCTestCase {
    func testDashboardRanksActionableRisksBeforeSummaryGaps() {
        let brokenCommand = asset(
            path: "/Users/susu/.agents/skills/build/SKILL.md",
            owner: .agents,
            kind: .skill,
            title: "build",
            summary: "Build tools.",
            dependencies: ["~/.claude/scripts/missing.sh"],
            statusFlags: [.stalePath]
        )
        let undocumentedMemory = asset(
            path: "/Users/susu/.codex/memories/topic.md",
            owner: .codex,
            kind: .memory,
            title: "topic",
            summary: "No summary yet",
            statusFlags: [.needsSummary]
        )

        let summary = DashboardAnalyzer().summary(
            assets: [undocumentedMemory, brokenCommand],
            changeSummary: .empty,
            aiSummaries: [:],
            activeSourceCount: 4,
            existingSourceCount: 3,
            isIndexStale: true
        )

        XCTAssertEqual(summary.indexHealth.isStale, true)
        XCTAssertEqual(summary.indexHealth.activeSourceCount, 4)
        XCTAssertEqual(summary.indexHealth.existingSourceCount, 3)
        XCTAssertEqual(summary.topRisks.first?.category, .missingDependency)
        XCTAssertEqual(summary.topRisks.first?.assetPath, brokenCommand.path)
        XCTAssertTrue(summary.topRisks.contains { $0.category == .needsSummary && $0.assetPath == undocumentedMemory.path })
    }

    func testDashboardComputesDriftAndAICoverage() {
        let claudeSkill = asset(
            path: "/Users/susu/.claude/skills/build/SKILL.md",
            owner: .claude,
            kind: .skill,
            title: "build",
            summary: "Build tools.",
            preview: "Build tools."
        )
        let codexSkill = asset(
            path: "/Users/susu/.agents/skills/build/SKILL.md",
            owner: .agents,
            kind: .skill,
            title: "build",
            summary: "Build MCP tools.",
            preview: "Build MCP tools."
        )
        let onlyClaude = asset(
            path: "/Users/susu/.claude/commands/ship.md",
            owner: .claude,
            kind: .command,
            title: "ship",
            summary: "Ship command.",
            preview: "Ship command."
        )

        let summary = DashboardAnalyzer().summary(
            assets: [claudeSkill, codexSkill, onlyClaude],
            changeSummary: AssetChangeSummary(added: [AssetChange(path: onlyClaude.path, title: onlyClaude.title, owner: onlyClaude.owner, kind: onlyClaude.kind)], removed: [], changed: []),
            aiSummaries: [claudeSkill.contentHash: "AI summary"],
            activeSourceCount: 2,
            existingSourceCount: 2,
            isIndexStale: false
        )

        XCTAssertEqual(summary.drift.changed, 1)
        XCTAssertEqual(summary.drift.missingCounterpart, 1)
        XCTAssertEqual(summary.drift.same, 0)
        XCTAssertEqual(summary.aiCoverage.explained, 1)
        XCTAssertEqual(summary.aiCoverage.missing, 2)
        XCTAssertEqual(summary.recentChanges.added.map(\.path), [onlyClaude.path])
    }

    func testDashboardFindsDependencyHotspots() {
        let sharedSkill = asset(
            path: "/Users/susu/.agents/skills/shared/SKILL.md",
            owner: .agents,
            kind: .skill,
            title: "shared",
            summary: "Shared skill."
        )
        let firstCommand = asset(
            path: "/Users/susu/.claude/commands/one.md",
            owner: .claude,
            kind: .command,
            title: "one",
            summary: "Uses shared.",
            dependencies: ["~/.agents/skills/shared/SKILL.md"]
        )
        let secondCommand = asset(
            path: "/Users/susu/.codex/rules/two.md",
            owner: .codex,
            kind: .rule,
            title: "two",
            summary: "Uses shared.",
            dependencies: ["~/.agents/skills/shared/SKILL.md", "~/.claude/scripts/missing.sh"]
        )

        let summary = DashboardAnalyzer().summary(
            assets: [sharedSkill, firstCommand, secondCommand],
            changeSummary: .empty,
            aiSummaries: [:],
            activeSourceCount: 2,
            existingSourceCount: 2,
            isIndexStale: false
        )

        XCTAssertEqual(summary.dependencyHotspots.first?.assetPath, sharedSkill.path)
        XCTAssertEqual(summary.dependencyHotspots.first?.incomingCount, 2)
        XCTAssertTrue(summary.dependencyHotspots.contains { $0.assetPath == secondCommand.path && $0.missingOutgoingCount == 1 })
    }

    private func asset(
        path: String,
        owner: AgentOwner,
        kind: AssetKind,
        title: String,
        summary: String,
        dependencies: [String] = [],
        preview: String? = nil,
        statusFlags: [AssetStatusFlag] = []
    ) -> AgentAsset {
        let preview = preview ?? summary
        return AgentAsset(
            path: path,
            owner: owner,
            kind: kind,
            scope: "global",
            title: title,
            summary: summary,
            dependencies: dependencies,
            contentHash: StableHash.hash(path + preview),
            preview: preview,
            statusFlags: statusFlags
        )
    }
}
