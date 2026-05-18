import XCTest
@testable import AgentObservatoryCore

final class ContextTreeBuilderTests: XCTestCase {
    func testCapabilityPackageGroupsAreNotDefaultExpanded() throws {
        let catalog = ContextCatalogAnalyzer().catalog(assets: [
            asset(
                path: "/Users/susu/.codex/plugins/cache/openai-curated/vercel/08373044/skills/nextjs/SKILL.md",
                owner: .codex,
                kind: .skill,
                title: "nextjs"
            ),
            asset(
                path: "/Users/susu/.codex/plugins/cache/openai-curated/vercel/08373044/skills/ai-sdk/SKILL.md",
                owner: .codex,
                kind: .skill,
                title: "ai-sdk"
            )
        ])

        let nodes = ContextTreeBuilder(
            catalog: catalog,
            visibleCapabilityItems: catalog.capabilityItems,
            searchText: "",
            language: .english
        )
        .nodes()
        let flattened = nodes.flatMap(\.flattened)
        let defaults = Set(nodes.flatMap(\.defaultExpandedIDs))
        let group = try XCTUnwrap(flattened.first { $0.title == "vercel" })

        XCTAssertTrue(defaults.contains("surface:codex"))
        XCTAssertTrue(defaults.contains("surface:codex:capability"))
        XCTAssertFalse(defaults.contains(group.id))
        XCTAssertEqual(group.children.count, 2)
    }

    func testMemoryTypeGroupsStayDefaultExpanded() {
        let catalog = ContextCatalogAnalyzer().catalog(assets: [
            asset(
                path: "/Users/susu/.codex/memories/MEMORY.md",
                owner: .codex,
                kind: .memory,
                title: "MEMORY"
            )
        ])

        let nodes = ContextTreeBuilder(
            catalog: catalog,
            visibleCapabilityItems: catalog.capabilityItems,
            searchText: "",
            language: .english
        )
        .nodes()
        let defaults = Set(nodes.flatMap(\.defaultExpandedIDs))

        XCTAssertTrue(defaults.contains("surface:codex"))
        XCTAssertTrue(defaults.contains("surface:codex:memory"))
        XCTAssertTrue(defaults.contains("surface:codex:memory:type:longTerm"))
    }

    func testCapabilityCategoriesSplitMCPAndKeepOfficialCollapsed() throws {
        let catalog = ContextCatalogAnalyzer().catalog(assets: [
            asset(
                path: "/Users/susu/.agents/skills/build-mcp-server/SKILL.md",
                owner: .agents,
                kind: .skill,
                title: "build-mcp-server"
            ),
            asset(
                path: "/Users/susu/Project/.mcp.json",
                owner: .project,
                kind: .mcp,
                title: ".mcp"
            ),
            asset(
                path: "/Users/susu/.codex/plugins/cache/openai-curated/figma/08373044/skills/figma-use/SKILL.md",
                owner: .codex,
                kind: .skill,
                title: "figma-use"
            )
        ])

        let nodes = ContextTreeBuilder(
            catalog: catalog,
            visibleCapabilityItems: catalog.capabilityItems,
            searchText: "",
            language: .simplifiedChinese
        )
        .nodes()
        let flattened = nodes.flatMap(\.flattened)
        let defaults = Set(nodes.flatMap(\.defaultExpandedIDs))
        let userSkillCategory = try XCTUnwrap(flattened.first { $0.title == "用户导入的 Skill" })
        let projectNode = try XCTUnwrap(flattened.first { $0.id == "surface:project" })
        let mcpNode = try XCTUnwrap(projectNode.children.first { $0.id == "surface:project:mcp" })
        let mcpGroup = try XCTUnwrap(flattened.first { $0.id.hasPrefix("surface:project:mcp:group:") })
        let officialCategory = try XCTUnwrap(flattened.first { $0.title == "官方 / 预置能力" })

        XCTAssertTrue(defaults.contains(userSkillCategory.id))
        XCTAssertNil(projectNode.children.first { $0.id == "surface:project:capability" })
        XCTAssertEqual(mcpNode.title, "MCP")
        XCTAssertTrue(defaults.contains(mcpNode.id))
        XCTAssertFalse(defaults.contains(mcpGroup.id))
        XCTAssertNil(flattened.first { $0.id.contains(":capability:category:mcpTools") })
        XCTAssertFalse(defaults.contains(officialCategory.id))
    }

    private func asset(
        path: String,
        owner: AgentOwner,
        kind: AssetKind,
        title: String
    ) -> AgentAsset {
        AgentAsset(
            path: path,
            owner: owner,
            kind: kind,
            scope: owner == .project ? "project" : "global",
            title: title,
            summary: "Summary for \(title)",
            byteCount: 100,
            contentHash: title,
            preview: "Preview"
        )
    }
}
