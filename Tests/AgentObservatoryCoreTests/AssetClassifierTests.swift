import XCTest
@testable import AgentObservatoryCore

final class AssetClassifierTests: XCTestCase {
    func testSkillTitleAndSummaryComeFromFrontMatter() {
        let classifier = AssetClassifier()
        let asset = classifier.makeAsset(
            url: URL(fileURLWithPath: "/Users/susu/.agents/skills/build-mcp-server/SKILL.md"),
            owner: .agents,
            kind: .skill,
            scope: "global",
            preview: """
            ---
            name: build-mcp-server
            description: Build local MCP servers.
            ---
            # Build MCP Server
            """,
            modifiedAt: nil,
            byteCount: 128,
            relatedFiles: [],
            isSensitive: false,
            isLarge: false,
            unreadable: false
        )

        XCTAssertEqual(asset.title, "build-mcp-server")
        XCTAssertEqual(asset.summary, "Build local MCP servers.")
        XCTAssertEqual(asset.trigger, "Auto-selected when task matches: Build local MCP servers.")
    }

    func testCodexAssetWithClaudePathIsMarkedStale() {
        let classifier = AssetClassifier()
        let asset = classifier.makeAsset(
            url: URL(fileURLWithPath: "/Users/susu/.agents/skills/xf-private/SKILL.md"),
            owner: .agents,
            kind: .skill,
            scope: "global",
            preview: "Run ~/.claude/scripts/xf/ensure-fav-server.sh when needed.",
            modifiedAt: nil,
            byteCount: 64,
            relatedFiles: [],
            isSensitive: false,
            isLarge: false,
            unreadable: false
        )

        XCTAssertTrue(asset.statusFlags.contains(.stalePath))
    }
}
