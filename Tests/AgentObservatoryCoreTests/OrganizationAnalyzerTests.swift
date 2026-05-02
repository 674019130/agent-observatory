import XCTest
@testable import AgentObservatoryCore

final class OrganizationAnalyzerTests: XCTestCase {
    func testMapGroupsAssetsByAudienceAndKind() {
        let assets = [
            asset(path: "/tmp/.claude/commands/build.md", owner: .claude, kind: .command, title: "build"),
            asset(path: "/tmp/.agents/skills/build/SKILL.md", owner: .agents, kind: .skill, title: "build"),
            asset(path: "/tmp/project/AGENTS.md", owner: .project, kind: .instruction, title: "AGENTS")
        ]

        let map = OrganizationAnalyzer().map(assets: assets, aiSummaries: [:])

        XCTAssertEqual(map.totalAssets, 3)
        XCTAssertEqual(map.audienceCounts["Claude Code"], 1)
        XCTAssertEqual(map.audienceCounts["Shared Agents"], 1)
        XCTAssertEqual(map.audienceCounts["Project"], 1)
        XCTAssertTrue(map.buckets.contains { $0.audience == "Claude Code" && $0.kind == .command && $0.assets.map(\.title) == ["build"] })
        XCTAssertTrue(map.buckets.contains { $0.audience == "Shared Agents" && $0.kind == .skill && $0.assets.map(\.title) == ["build"] })
    }

    func testRecommendationsFlagDuplicatesAndStalePathsForHumanReview() {
        let claude = asset(
            path: "/tmp/.claude/skills/build/SKILL.md",
            owner: .claude,
            kind: .skill,
            title: "build",
            summary: "Build tools"
        )
        let agents = asset(
            path: "/tmp/.agents/skills/build/SKILL.md",
            owner: .agents,
            kind: .skill,
            title: "build",
            summary: "Build tools",
            statusFlags: [.duplicate, .stalePath]
        )

        let plan = OrganizationAnalyzer().recommendations(
            for: OrganizationAnalyzer().map(assets: [claude, agents], aiSummaries: [:]),
            assets: [claude, agents]
        )

        XCTAssertTrue(plan.requiresHumanApproval)
        XCTAssertTrue(plan.recommendations.contains { recommendation in
            recommendation.action == .merge
                && recommendation.primaryAssetPath == agents.path
                && recommendation.relatedAssetPaths.contains(claude.path)
        })
        XCTAssertTrue(plan.recommendations.contains { recommendation in
            recommendation.action == .review
                && recommendation.primaryAssetPath == agents.path
                && recommendation.reason.localizedCaseInsensitiveContains("stale")
        })
    }

    func testRecommendationsSuggestArchiveForHiddenLowValueDuplicateOnlyAfterApproval() {
        let oldCommand = asset(
            path: "/tmp/.claude/commands/old-build.md",
            owner: .claude,
            kind: .command,
            title: "build",
            summary: "Older duplicate command",
            statusFlags: [.duplicate]
        )
        let currentCommand = asset(
            path: "/tmp/.agents/skills/build/SKILL.md",
            owner: .agents,
            kind: .skill,
            title: "build",
            summary: "Current skill"
        )

        let plan = OrganizationAnalyzer().recommendations(
            for: OrganizationAnalyzer().map(assets: [oldCommand, currentCommand], aiSummaries: [:]),
            assets: [oldCommand, currentCommand]
        )

        XCTAssertTrue(plan.recommendations.allSatisfy { !$0.isApprovedByDefault })
    }

    private func asset(
        path: String,
        owner: AgentOwner,
        kind: AssetKind,
        title: String,
        summary: String = "Test asset",
        statusFlags: [AssetStatusFlag] = []
    ) -> AgentAsset {
        AgentAsset(
            path: path,
            owner: owner,
            kind: kind,
            scope: "test",
            title: title,
            summary: summary,
            contentHash: StableHash.hash(path + title),
            preview: summary,
            statusFlags: statusFlags
        )
    }
}
