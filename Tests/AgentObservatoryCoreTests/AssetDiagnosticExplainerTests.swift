import XCTest
@testable import AgentObservatoryCore

final class AssetDiagnosticExplainerTests: XCTestCase {
    func testDuplicateExplanationListsMatchingPeerPaths() {
        let primary = asset(
            id: "11111111-1111-1111-1111-111111111111",
            path: "/Users/susu/.agents/skills/frontend-design/SKILL.md",
            owner: .agents,
            kind: .skill,
            title: "frontend-design",
            flags: [.duplicate]
        )
        let peer = asset(
            id: "22222222-2222-2222-2222-222222222222",
            path: "/Users/susu/.codex/skills/frontend-design/SKILL.md",
            owner: .codex,
            kind: .skill,
            title: "frontend-design",
            flags: [.duplicate]
        )
        let unrelated = asset(
            id: "33333333-3333-3333-3333-333333333333",
            path: "/Users/susu/.agents/skills/backend-design/SKILL.md",
            owner: .agents,
            kind: .skill,
            title: "backend-design"
        )

        let explanation = AssetDiagnosticExplainer().explanation(
            for: .duplicate,
            asset: primary,
            allAssets: [primary, peer, unrelated],
            language: .simplifiedChinese
        )

        XCTAssertTrue(explanation.summary.contains("skill::frontend-design"))
        XCTAssertTrue(explanation.detailRows.contains { $0.path == peer.path })
        XCTAssertFalse(explanation.detailRows.contains { $0.path == unrelated.path })
    }

    func testStalePathExplanationIncludesClaudePathSnippets() {
        let flagged = asset(
            id: "44444444-4444-4444-4444-444444444444",
            path: "/Users/susu/.agents/skills/xf/SKILL.md",
            owner: .agents,
            kind: .skill,
            title: "xf",
            preview: """
            This skill was migrated from ~/.claude/commands/xf.md.
            Keep references to ~/.agents/skills/xf current.
            """,
            flags: [.stalePath]
        )

        let explanation = AssetDiagnosticExplainer().explanation(
            for: .stalePath,
            asset: flagged,
            allAssets: [flagged],
            language: .english
        )

        XCTAssertTrue(explanation.summary.contains("not owned by Claude"))
        XCTAssertTrue(explanation.detailRows.contains { $0.value.contains("~/.claude/commands/xf.md") })
        XCTAssertTrue(explanation.detailRows.contains { $0.value.contains("preview contains ~/.claude") })
    }

    private func asset(
        id: String,
        path: String,
        owner: AgentOwner,
        kind: AssetKind,
        title: String,
        preview: String = "Preview",
        flags: [AssetStatusFlag] = []
    ) -> AgentAsset {
        AgentAsset(
            id: UUID(uuidString: id)!,
            path: path,
            owner: owner,
            kind: kind,
            scope: "global",
            title: title,
            summary: "Summary for \(title)",
            contentHash: id,
            preview: preview,
            statusFlags: flags
        )
    }
}
