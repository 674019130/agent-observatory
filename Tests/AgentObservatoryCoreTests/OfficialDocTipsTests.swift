import XCTest
@testable import AgentObservatoryCore

final class OfficialDocTipsTests: XCTestCase {
    func testContextOverviewTipsExposeOfficialSourcesAndLocations() {
        let tips = OfficialDocTips.tips(for: .contextOverview, language: .simplifiedChinese)

        XCTAssertTrue(tips.contains { $0.id == "codex-agents-md" })
        XCTAssertTrue(tips.contains { $0.id == "claude-memory" })
        XCTAssertTrue(tips.allSatisfy { $0.sourceURL.hasPrefix("https://") })
        XCTAssertTrue(tips.allSatisfy { !$0.sourceLocation.isEmpty })
        XCTAssertTrue(tips.contains { $0.sourceURL == "https://developers.openai.com/codex/guides/agents-md" })
        XCTAssertTrue(tips.contains { $0.sourceURL == "https://code.claude.com/docs/en/memory" })
    }

    func testTriggerRadarTipsReferenceBothOfficialSkillDocs() {
        let tips = OfficialDocTips.tips(for: .triggerRadar, language: .english)

        XCTAssertEqual(tips.map(\.id), ["codex-skills", "claude-skills"])
        XCTAssertTrue(tips.contains { $0.sourceURL == "https://developers.openai.com/codex/skills" })
        XCTAssertTrue(tips.contains { $0.sourceURL == "https://code.claude.com/docs/en/skills" })
        XCTAssertTrue(tips.allSatisfy { $0.sourceLocation.contains(">") })
    }

    func testCapabilityAndMCPTipsStaySeparated() {
        let capabilityTips = OfficialDocTips.tips(for: .capabilities, language: .english)
        let mcpTips = OfficialDocTips.tips(for: .mcpTools, language: .english)

        XCTAssertEqual(capabilityTips.map(\.id), ["codex-skills", "claude-skills"])
        XCTAssertEqual(mcpTips.map(\.id), ["codex-mcp", "claude-mcp"])
        XCTAssertTrue(mcpTips.contains { $0.sourceURL == "https://developers.openai.com/codex/mcp" })
        XCTAssertTrue(mcpTips.contains { $0.sourceURL == "https://code.claude.com/docs/en/mcp" })
    }

    func testAssetTipsExplainMCPConfigForTheMatchingSurface() {
        let asset = AgentAsset(
            path: "/Users/susu/.codex/config.toml",
            owner: .codex,
            kind: .mcp,
            scope: "global",
            title: "Codex MCP",
            summary: "MCP server configuration",
            contentHash: "hash",
            preview: ""
        )
        let route = ContextLoadRoute(
            role: .capability,
            layer: .configuration,
            surfaces: [.codex],
            destination: .toolRegistry,
            trigger: .mcpConfiguration
        )

        let tips = OfficialDocTips.tips(for: asset, route: route, language: .simplifiedChinese)

        XCTAssertEqual(tips.map(\.id), ["codex-mcp"])
        XCTAssertEqual(tips.first?.sourceURL, "https://developers.openai.com/codex/mcp")
        XCTAssertTrue(tips.first?.title.contains("MCP") == true)
    }

    func testAssetTipsPreferInstructionDocsForAGENTSAndCLAUDEFiles() {
        let codexAsset = instructionAsset(path: "/repo/AGENTS.md", owner: .project)
        let claudeAsset = instructionAsset(path: "/repo/.claude/CLAUDE.md", owner: .claude)
        let codexRoute = ContextLoadRoute(
            role: .memory,
            layer: .project,
            surfaces: [.codex],
            destination: .projectContextBlock,
            trigger: .projectDiscovery
        )
        let claudeRoute = ContextLoadRoute(
            role: .memory,
            layer: .project,
            surfaces: [.claude],
            destination: .projectContextBlock,
            trigger: .projectDiscovery
        )

        XCTAssertEqual(
            OfficialDocTips.tips(for: codexAsset, route: codexRoute, language: .english).map(\.id),
            ["codex-agents-md"]
        )
        XCTAssertEqual(
            OfficialDocTips.tips(for: claudeAsset, route: claudeRoute, language: .english).map(\.id),
            ["claude-memory"]
        )
    }

    private func instructionAsset(path: String, owner: AgentOwner) -> AgentAsset {
        AgentAsset(
            path: path,
            owner: owner,
            kind: .instruction,
            scope: "project",
            title: "Instructions",
            summary: "Project instructions",
            contentHash: path,
            preview: ""
        )
    }
}
