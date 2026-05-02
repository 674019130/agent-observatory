import XCTest
@testable import AgentObservatoryCore

final class AssetDiffAnalyzerTests: XCTestCase {
    func testPairsClaudeAndCodexAssetsAndReportsChangedFields() {
        let claude = asset(
            path: "/Users/susu/.claude/skills/build/SKILL.md",
            owner: .claude,
            title: "build",
            summary: "Build local tools.",
            trigger: "Claude trigger",
            dependencies: ["scripts/build.sh"],
            preview: """
            ---
            name: build
            description: Build local tools.
            ---
            Run scripts/build.sh
            """
        )
        let codex = asset(
            path: "/Users/susu/.agents/skills/build/SKILL.md",
            owner: .agents,
            title: "build",
            summary: "Build MCP tools.",
            trigger: "Codex trigger",
            dependencies: ["scripts/build.mjs"],
            preview: """
            ---
            name: build
            description: Build MCP tools.
            ---
            Run scripts/build.mjs
            """
        )

        let comparison = AssetDiffAnalyzer().comparison(for: claude, in: [claude, codex])

        XCTAssertEqual(comparison.counterpart?.path, codex.path)
        XCTAssertEqual(comparison.status, .changed)
        XCTAssertTrue(comparison.rows.contains { $0.field == "Summary" && $0.status == .changed })
        XCTAssertTrue(comparison.rows.contains { $0.field == "Dependencies" && $0.status == .changed })
        XCTAssertTrue(comparison.rows.contains { $0.field == "Frontmatter Description" && $0.status == .changed })
    }

    func testMissingCounterpartIsReported() {
        let codex = asset(
            path: "/Users/susu/.agents/skills/only-codex/SKILL.md",
            owner: .agents,
            title: "only-codex",
            summary: "Only exists in Codex.",
            preview: "Only exists in Codex."
        )

        let comparison = AssetDiffAnalyzer().comparison(for: codex, in: [codex])

        XCTAssertNil(comparison.counterpart)
        XCTAssertEqual(comparison.status, .missingCounterpart)
        XCTAssertTrue(comparison.rows.isEmpty)
    }

    private func asset(
        path: String,
        owner: AgentOwner,
        title: String,
        summary: String,
        trigger: String? = nil,
        dependencies: [String] = [],
        preview: String
    ) -> AgentAsset {
        AgentAsset(
            path: path,
            owner: owner,
            kind: .skill,
            scope: "global",
            title: title,
            summary: summary,
            trigger: trigger,
            dependencies: dependencies,
            contentHash: StableHash.hash(path + preview),
            preview: preview
        )
    }
}
