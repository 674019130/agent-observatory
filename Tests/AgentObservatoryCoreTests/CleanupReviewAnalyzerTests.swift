import XCTest
@testable import AgentObservatoryCore

final class CleanupReviewAnalyzerTests: XCTestCase {
    func testFullReviewGroupsDuplicateAssetsAsOneMergeDecision() {
        let claude = asset(path: "/tmp/.claude/commands/build.md", owner: .claude, kind: .command, title: "build")
        let codex = asset(path: "/tmp/.codex/commands/build.md", owner: .codex, kind: .command, title: "build")

        let session = CleanupReviewAnalyzer().session(goal: .fullReview, assets: [claude, codex])

        XCTAssertEqual(session.groups.count, 1)
        XCTAssertEqual(session.groups.first?.action, .merge)
        XCTAssertEqual(session.groups.first?.assetPaths.sorted(), [claude.path, codex.path].sorted())
        XCTAssertTrue(session.groups.first?.canApplyAutomatically ?? false)
        XCTAssertEqual(session.groups.first?.automaticApplyAssetPaths, [claude.path])
    }

    func testLegacyCleanupFocusesOnStaleClaudeReferences() {
        let stale = asset(
            path: "/tmp/.codex/skills/migrated/SKILL.md",
            owner: .codex,
            kind: .skill,
            title: "migrated",
            statusFlags: [.stalePath]
        )
        let clean = asset(path: "/tmp/.agents/skills/current/SKILL.md", owner: .agents, kind: .skill, title: "current")

        let session = CleanupReviewAnalyzer().session(goal: .legacyClaudeCleanup, assets: [stale, clean])

        XCTAssertEqual(session.groups.count, 1)
        XCTAssertEqual(session.groups.first?.action, .review)
        XCTAssertEqual(session.groups.first?.assetPaths, [stale.path])
        XCTAssertTrue(session.groups.first?.evidence.contains { $0.localizedCaseInsensitiveContains("claude") } ?? false)
    }

    func testNoiseCleanupSuggestsHidingSessionAndUnknownAssets() {
        let sessionAsset = asset(path: "/tmp/.codex/sessions/old.jsonl", owner: .codex, kind: .session, title: "old")
        let unknown = asset(path: "/tmp/project/tmp.txt", owner: .project, kind: .unknown, title: "tmp")
        let skill = asset(path: "/tmp/.agents/skills/useful/SKILL.md", owner: .agents, kind: .skill, title: "useful")

        let session = CleanupReviewAnalyzer().session(goal: .noiseCleanup, assets: [sessionAsset, unknown, skill])

        XCTAssertEqual(session.groups.count, 1)
        XCTAssertEqual(session.groups.first?.action, .hide)
        XCTAssertEqual(Set(session.groups.first?.assetPaths ?? []), Set([sessionAsset.path, unknown.path]))
        XCTAssertTrue(session.groups.first?.canApplyAutomatically ?? false)
    }

    func testCleanupReviewCanRenderChineseGroupCopy() {
        let sessionAsset = asset(path: "/tmp/.codex/sessions/old.jsonl", owner: .codex, kind: .session, title: "old")
        let unknown = asset(path: "/tmp/project/tmp.txt", owner: .project, kind: .unknown, title: "tmp")

        let session = CleanupReviewAnalyzer().session(
            goal: .noiseCleanup,
            assets: [sessionAsset, unknown],
            language: .simplifiedChinese
        )

        let group = session.groups.first
        XCTAssertTrue(group?.title.contains("隐藏") ?? false)
        XCTAssertTrue(group?.summary.contains("可恢复") ?? false)
        XCTAssertTrue(group?.evidence.contains { $0.contains("隐藏") } ?? false)
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
