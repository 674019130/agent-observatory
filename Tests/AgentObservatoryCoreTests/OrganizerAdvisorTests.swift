import XCTest
@testable import AgentObservatoryCore

final class OrganizerAdvisorTests: XCTestCase {
    func testEmptyIndexBriefPointsUserToBuildAMap() {
        let brief = OrganizerAdvisor().brief(map: .empty, assets: [])

        XCTAssertEqual(brief.recommendedGoal, .fullReview)
        XCTAssertTrue(brief.headline.localizedCaseInsensitiveContains("No agent assets"))
        XCTAssertTrue(brief.focusAreas.contains { $0.localizedCaseInsensitiveContains("Build a map") })
    }

    func testRiskSignalsTakePriorityOverOtherCleanupGoals() {
        let sensitive = asset(
            path: "/tmp/.codex/auth.json",
            owner: .codex,
            kind: .config,
            title: "auth",
            statusFlags: [.secretRisk]
        )
        let firstDuplicate = asset(
            path: "/tmp/.claude/commands/build.md",
            owner: .claude,
            kind: .command,
            title: "build",
            statusFlags: [.duplicate]
        )
        let secondDuplicate = asset(
            path: "/tmp/.codex/commands/build.md",
            owner: .codex,
            kind: .command,
            title: "build",
            statusFlags: [.duplicate]
        )
        let assets = [sensitive, firstDuplicate, secondDuplicate]
        let map = OrganizationAnalyzer().map(assets: assets, aiSummaries: [:])

        let brief = OrganizerAdvisor().brief(map: map, assets: assets)

        XCTAssertEqual(brief.recommendedGoal, .riskCleanup)
        XCTAssertTrue(brief.focusAreas.contains { $0.localizedCaseInsensitiveContains("sensitive") })
    }

    func testDuplicateSignalsRecommendDuplicateCleanupWhenThereAreNoRisks() {
        let claude = asset(
            path: "/tmp/.claude/commands/build.md",
            owner: .claude,
            kind: .command,
            title: "build",
            statusFlags: [.duplicate]
        )
        let codex = asset(
            path: "/tmp/.codex/commands/build.md",
            owner: .codex,
            kind: .command,
            title: "build",
            statusFlags: [.duplicate]
        )
        let assets = [claude, codex]
        let map = OrganizationAnalyzer().map(assets: assets, aiSummaries: [:])

        let brief = OrganizerAdvisor().brief(map: map, assets: assets)

        XCTAssertEqual(brief.recommendedGoal, .duplicateCleanup)
        XCTAssertTrue(brief.summary.localizedCaseInsensitiveContains("Duplicates"))
    }

    func testChineseBriefUsesLocalizedCopyAndGoalName() {
        let stale = asset(
            path: "/tmp/.codex/skills/migrated/SKILL.md",
            owner: .codex,
            kind: .skill,
            title: "migrated",
            statusFlags: [.stalePath]
        )
        let assets = [stale]
        let map = OrganizationAnalyzer().map(assets: assets, aiSummaries: [:], language: .simplifiedChinese)

        let brief = OrganizerAdvisor().brief(map: map, assets: assets, language: .simplifiedChinese)

        XCTAssertEqual(brief.recommendedGoal, .legacyClaudeCleanup)
        XCTAssertTrue(brief.headline.contains("当前"))
        XCTAssertTrue(brief.summary.contains("清理 Claude 旧配置"))
        XCTAssertTrue(brief.focusAreas.contains { $0.contains("Claude") && $0.contains("旧路径") })
    }

    private func asset(
        path: String,
        owner: AgentOwner,
        kind: AssetKind,
        title: String,
        statusFlags: [AssetStatusFlag] = []
    ) -> AgentAsset {
        AgentAsset(
            path: path,
            owner: owner,
            kind: kind,
            scope: "test",
            title: title,
            summary: "Test asset",
            contentHash: StableHash.hash(path + title),
            preview: "Test asset",
            statusFlags: statusFlags
        )
    }
}
