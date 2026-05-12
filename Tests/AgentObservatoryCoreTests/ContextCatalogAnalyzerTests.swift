import XCTest
@testable import AgentObservatoryCore

final class ContextCatalogAnalyzerTests: XCTestCase {
    func testCatalogSeparatesMemoriesFromCapabilities() {
        let catalog = ContextCatalogAnalyzer().catalog(assets: [
            asset(path: "/Users/susu/.claude/CLAUDE.md", owner: .claude, kind: .instruction, title: "CLAUDE"),
            asset(path: "/Users/susu/.codex/memories/MEMORY.md", owner: .codex, kind: .memory, title: "MEMORY"),
            asset(path: "/Users/susu/.agents/skills/build-mcp-server/SKILL.md", owner: .agents, kind: .skill, title: "build-mcp-server"),
            asset(path: "/Users/susu/.codex/plugins/cache/github/SKILL.md", owner: .codex, kind: .plugin, title: "GitHub")
        ])

        XCTAssertEqual(Set(catalog.memoryItems.map(\.asset.title)), Set(["CLAUDE", "MEMORY"]))
        XCTAssertEqual(Set(catalog.capabilityItems.map(\.asset.title)), Set(["build-mcp-server", "GitHub"]))
    }

    func testProjectContextIsAssignedToTheMatchingSurface() {
        let catalog = ContextCatalogAnalyzer().catalog(assets: [
            asset(path: "/Users/susu/Project/CLAUDE.md", owner: .project, kind: .instruction, title: "CLAUDE"),
            asset(path: "/Users/susu/Project/AGENTS.md", owner: .project, kind: .instruction, title: "AGENTS"),
            asset(path: "/Users/susu/Project/.mcp.json", owner: .project, kind: .mcp, title: ".mcp")
        ])

        let claudeMemory = catalog.memoryItems.first { $0.asset.title == "CLAUDE" }
        let codexMemory = catalog.memoryItems.first { $0.asset.title == "AGENTS" }
        let mcp = catalog.capabilityItems.first { $0.asset.title == ".mcp" }

        XCTAssertEqual(claudeMemory?.layer, .project)
        XCTAssertEqual(claudeMemory?.surfaces, [.claude])
        XCTAssertEqual(codexMemory?.layer, .project)
        XCTAssertEqual(codexMemory?.surfaces, [.codex])
        XCTAssertEqual(mcp?.surfaces, [.claude, .codex])
    }

    func testAssemblyContainsClaudeAndCodexPipelines() {
        let catalog = ContextCatalogAnalyzer().catalog(assets: [
            asset(path: "/Users/susu/.claude/CLAUDE.md", owner: .claude, kind: .instruction, title: "Claude global"),
            asset(path: "/Users/susu/.codex/AGENTS.md", owner: .codex, kind: .instruction, title: "Codex global"),
            asset(path: "/Users/susu/.agents/skills/build-mcp-server/SKILL.md", owner: .agents, kind: .skill, title: "Shared skill")
        ])

        XCTAssertFalse(catalog.assemblySteps(for: .claude).isEmpty)
        XCTAssertFalse(catalog.assemblySteps(for: .codex).isEmpty)
        XCTAssertEqual(catalog.memoryCount(for: .claude), 1)
        XCTAssertEqual(catalog.memoryCount(for: .codex), 1)
        XCTAssertEqual(catalog.capabilityCount(for: .claude), 1)
        XCTAssertEqual(catalog.capabilityCount(for: .codex), 1)
    }

    func testCatalogClassifiesMemoryTypesExplicitly() {
        let catalog = ContextCatalogAnalyzer().catalog(assets: [
            asset(path: "/Users/susu/.codex/memories/MEMORY.md", owner: .codex, kind: .memory, title: "MEMORY"),
            asset(path: "/Users/susu/.claude/projects/-Users-susu/memory", owner: .claude, kind: .memory, title: "Claude project memory"),
            asset(path: "/Users/susu/Workspace/memory/note.md", owner: .project, kind: .memory, scope: "workspace-memory", title: "Workspace note"),
            asset(path: "/Users/susu/.codex/automations/yage-rss/memory.md", owner: .codex, kind: .memory, title: "Automation"),
            asset(path: "/Users/susu/.codex/projects/-Users-susu/memory/favorite_tools.md", owner: .codex, kind: .memory, title: "Favorite tools"),
            asset(path: "/Users/susu/.codex/memories/rollout_summaries/session.md", owner: .codex, kind: .memory, title: "Rollout"),
            asset(path: "/Users/susu/.agents/skills/design/AGENTS.md", owner: .agents, kind: .instruction, title: "Shared instructions"),
            asset(path: "/Users/susu/.codex/AGENTS.md", owner: .codex, kind: .instruction, title: "Codex instructions"),
            asset(path: "/Users/susu/.codex/plugins/cache/react/rules/use-effect.md", owner: .codex, kind: .rule, title: "Rule"),
            asset(path: "/Users/susu/.codex/plugins/cache/github/AGENTS.md", owner: .codex, kind: .instruction, title: "Plugin instruction")
        ])

        let typesByTitle = Dictionary(uniqueKeysWithValues: catalog.memoryItems.compactMap { item in
            item.memoryType.map { (item.asset.title, $0) }
        })

        XCTAssertEqual(typesByTitle["MEMORY"], .longTerm)
        XCTAssertEqual(typesByTitle["Claude project memory"], .project)
        XCTAssertEqual(typesByTitle["Workspace note"], .workspace)
        XCTAssertEqual(typesByTitle["Automation"], .automation)
        XCTAssertEqual(typesByTitle["Favorite tools"], .preference)
        XCTAssertEqual(typesByTitle["Rollout"], .sessionHistory)
        XCTAssertEqual(typesByTitle["Shared instructions"], .shared)
        XCTAssertEqual(typesByTitle["Codex instructions"], .instructions)
        XCTAssertEqual(typesByTitle["Rule"], .contextRules)
        XCTAssertEqual(typesByTitle["Plugin instruction"], .pluginProvided)
    }

    private func asset(
        path: String,
        owner: AgentOwner,
        kind: AssetKind,
        scope: String? = nil,
        title: String
    ) -> AgentAsset {
        AgentAsset(
            path: path,
            owner: owner,
            kind: kind,
            scope: scope ?? (owner == .project ? "project" : "global"),
            title: title,
            summary: "Summary for \(title)",
            byteCount: 100,
            contentHash: title,
            preview: "Preview"
        )
    }
}
