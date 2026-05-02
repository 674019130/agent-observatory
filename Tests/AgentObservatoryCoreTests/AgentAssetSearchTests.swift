import XCTest
@testable import AgentObservatoryCore

final class AgentAssetSearchTests: XCTestCase {
    func testMatchesSearchAcrossPreviewDependenciesTriggerAndStatusFlags() {
        let asset = AgentAsset(
            path: "/Users/susu/.agents/skills/build-mcp-server/SKILL.md",
            owner: .agents,
            kind: .skill,
            scope: "global",
            title: "build-mcp-server",
            summary: "Build MCP servers.",
            trigger: "Auto-selected when task mentions MCP templates.",
            dependencies: ["scripts/run.sh"],
            relatedFiles: ["~/.agents/skills/build-mcp-server/scripts/run.sh"],
            contentHash: "hash-build-mcp-server",
            preview: "This skill calls uvx and validates server manifests.",
            statusFlags: [.hasScripts]
        )

        XCTAssertTrue(asset.matchesSearch(query: "uvx"))
        XCTAssertTrue(asset.matchesSearch(query: "scripts/run"))
        XCTAssertTrue(asset.matchesSearch(query: "auto-selected"))
        XCTAssertTrue(asset.matchesSearch(query: "has scripts"))
        XCTAssertFalse(asset.matchesSearch(query: "calendar"))
    }

    func testEmptySearchMatchesAllAssets() {
        let asset = AgentAsset(
            path: "/Users/susu/.codex/AGENTS.md",
            owner: .codex,
            kind: .instruction,
            scope: "global",
            title: "AGENTS",
            summary: "Global Codex instructions.",
            contentHash: "hash-agents",
            preview: ""
        )

        XCTAssertTrue(asset.matchesSearch(query: "   "))
    }
}
