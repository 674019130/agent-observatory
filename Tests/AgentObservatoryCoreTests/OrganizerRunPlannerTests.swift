import XCTest
@testable import AgentObservatoryCore

final class OrganizerRunPlannerTests: XCTestCase {
    func testPlannerBuildsDiagnosisAndConservativeActionPacks() {
        let assets = [
            asset(path: "/tmp/.codex/plugins/figma/README.md", owner: .codex, kind: .plugin, title: "Figma"),
            asset(path: "/tmp/.claude/plugins/figma/README.md", owner: .claude, kind: .plugin, title: "Figma"),
            asset(path: "/tmp/.codex/sessions/last.jsonl", owner: .codex, kind: .session, title: "last session"),
            asset(path: "/tmp/.codex/auth.json", owner: .codex, kind: .config, title: "auth", flags: [.secretRisk]),
            asset(path: "/tmp/.agents/skills/build/SKILL.md", owner: .agents, kind: .skill, title: "build", flags: [.needsSummary])
        ]
        let map = OrganizationAnalyzer().map(assets: assets, aiSummaries: [:], language: .simplifiedChinese)

        let run = OrganizerRunPlanner().plan(map: map, assets: assets, language: .simplifiedChinese)

        XCTAssertEqual(run.status, .ready)
        XCTAssertEqual(run.totalAssetCount, 5)
        XCTAssertEqual(run.duplicateAssetCount, 2)
        XCTAssertEqual(run.noiseAssetCount, 1)
        XCTAssertEqual(run.sensitiveAssetCount, 1)
        XCTAssertEqual(run.actionPacks.map(\.kind), [.mergeDuplicates, .hideNoise, .reviewSensitive, .clarifyUnknown])
        XCTAssertEqual(run.executablePacks.map(\.kind), [.mergeDuplicates, .hideNoise])
        XCTAssertTrue(run.summary.contains("5"))
        XCTAssertTrue(run.actionPacks.first?.isReversible == true)
    }

    func testEmptyPlannerRunPointsToScanning() {
        let run = OrganizerRunPlanner().plan(map: .empty, assets: [], language: .english)

        XCTAssertEqual(run.status, .empty)
        XCTAssertEqual(run.actionPacks, [])
        XCTAssertFalse(run.hasExecutablePacks)
        XCTAssertTrue(run.summary.contains("Build"))
    }

    func testPlannerSeparatesSensitiveAndUnreadableReviewQueues() {
        let assets = [
            asset(path: "/tmp/.codex/auth.json", owner: .codex, kind: .config, title: "auth", flags: [.secretRisk]),
            asset(path: "/tmp/.codex/missing.md", owner: .codex, kind: .config, title: "missing", flags: [.unreadable])
        ]
        let map = OrganizationAnalyzer().map(assets: assets, aiSummaries: [:], language: .english)

        let run = OrganizerRunPlanner().plan(map: map, assets: assets, language: .english)

        XCTAssertEqual(run.actionPacks.map(\.kind), [.reviewSensitive, .reviewUnreadable])
        XCTAssertFalse(run.hasExecutablePacks)
    }

    private func asset(
        path: String,
        owner: AgentOwner,
        kind: AssetKind,
        title: String,
        flags: [AssetStatusFlag] = []
    ) -> AgentAsset {
        AgentAsset(
            path: path,
            owner: owner,
            kind: kind,
            scope: "test",
            title: title,
            summary: "Test \(title)",
            contentHash: path,
            preview: "Test \(title)",
            statusFlags: flags
        )
    }
}
