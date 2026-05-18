import XCTest
@testable import AgentObservatoryCore

final class ContextCapabilityGrouperTests: XCTestCase {
    func testOfficialCodexPluginSkillsAreGroupedByPluginPackage() throws {
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

        let groups = ContextCapabilityGrouper().groups(items: catalog.capabilityItems)
        let group = try XCTUnwrap(groups.first)

        XCTAssertEqual(groups.count, 1)
        XCTAssertEqual(group.title, "vercel")
        XCTAssertEqual(group.rootPath, "/Users/susu/.codex/plugins/cache/openai-curated/vercel")
        XCTAssertEqual(group.groupingBasis.kind, .pluginBundle)
        XCTAssertEqual(group.groupingBasis.sourceLocation, "Codex Plugins > Overview > A plugin can contain Skills")
        XCTAssertEqual(group.origin, .officialPlugin)
        XCTAssertEqual(group.primaryKind, .skill)
        XCTAssertEqual(group.kindCounts[.skill], 2)
        XCTAssertEqual(group.items.map(\.asset.title), ["ai-sdk", "nextjs"])
    }

    func testNestedRepositorySkillsAreGroupedByRepository() throws {
        let catalog = ContextCatalogAnalyzer().catalog(assets: [
            asset(
                path: "/Users/susu/.agents/skills/acme-agent-kit/build/SKILL.md",
                owner: .agents,
                kind: .skill,
                title: "build"
            ),
            asset(
                path: "/Users/susu/.agents/skills/acme-agent-kit/review/SKILL.md",
                owner: .agents,
                kind: .skill,
                title: "review"
            )
        ])

        let group = try XCTUnwrap(ContextCapabilityGrouper().groups(items: catalog.capabilityItems).first)

        XCTAssertEqual(group.title, "acme-agent-kit")
        XCTAssertEqual(group.rootPath, "/Users/susu/.agents/skills/acme-agent-kit")
        XCTAssertEqual(group.groupingBasis.kind, .repositorySkillDirectory)
        XCTAssertEqual(group.origin, .userInstalled)
        XCTAssertEqual(group.items.count, 2)
    }

    func testClaudePluginCacheSkillsAreGroupedByPluginPackage() throws {
        let catalog = ContextCatalogAnalyzer().catalog(assets: [
            asset(
                path: "/Users/susu/.claude/plugins/cache/claude-plugins-official/discord/0.0.4/skills/access/SKILL.md",
                owner: .claude,
                kind: .skill,
                title: "access"
            ),
            asset(
                path: "/Users/susu/.claude/plugins/cache/claude-plugins-official/discord/0.0.4/skills/configure/SKILL.md",
                owner: .claude,
                kind: .skill,
                title: "configure"
            )
        ])

        let group = try XCTUnwrap(ContextCapabilityGrouper().groups(items: catalog.capabilityItems).first)

        XCTAssertEqual(group.title, "discord")
        XCTAssertEqual(group.rootPath, "/Users/susu/.claude/plugins/cache/claude-plugins-official/discord")
        XCTAssertEqual(group.items.map(\.asset.title), ["access", "configure"])
    }

    func testPluginCacheVersionsAndSurfacesAreMergedByRepositoryName() throws {
        let catalog = ContextCatalogAnalyzer().catalog(assets: [
            asset(
                path: "/Users/susu/.codex/plugins/cache/claude-plugins-official/superpowers/5.1.0/skills/using-superpowers/SKILL.md",
                owner: .codex,
                kind: .skill,
                title: "using-superpowers"
            ),
            asset(
                path: "/Users/susu/.claude/plugins/cache/claude-plugins-official/superpowers/5.0.7/skills/verification-before-completion/SKILL.md",
                owner: .claude,
                kind: .skill,
                title: "verification-before-completion"
            )
        ])

        let group = try XCTUnwrap(ContextCapabilityGrouper().groups(items: catalog.capabilityItems).first)

        XCTAssertEqual(group.title, "superpowers")
        XCTAssertEqual(group.rootPath, "/Users/susu/.claude/plugins/cache/claude-plugins-official/superpowers")
        XCTAssertEqual(group.items.count, 2)
        XCTAssertEqual(Set(group.owners), Set([.claude, .codex]))
    }

    func testClaudeExternalPluginSkillsAreGroupedByPluginPackage() throws {
        let catalog = ContextCatalogAnalyzer().catalog(assets: [
            asset(
                path: "/Users/susu/.claude/plugins/marketplaces/claude-plugins-official/external_plugins/telegram/skills/access/SKILL.md",
                owner: .claude,
                kind: .skill,
                title: "access"
            ),
            asset(
                path: "/Users/susu/.claude/plugins/marketplaces/claude-plugins-official/external_plugins/telegram/skills/configure/SKILL.md",
                owner: .claude,
                kind: .skill,
                title: "configure"
            )
        ])

        let group = try XCTUnwrap(ContextCapabilityGrouper().groups(items: catalog.capabilityItems).first)

        XCTAssertEqual(group.title, "telegram")
        XCTAssertEqual(group.rootPath, "/Users/susu/.claude/plugins/marketplaces/claude-plugins-official/external_plugins/telegram")
        XCTAssertEqual(group.items.count, 2)
    }

    func testFlatSkillsWithSharedFamilyAreGroupedAheadOfSingletons() throws {
        let catalog = ContextCatalogAnalyzer().catalog(assets: [
            asset(
                path: "/Users/susu/.claude/skills/peon-ping-use/SKILL.md",
                owner: .claude,
                kind: .skill,
                title: "peon-ping-use"
            ),
            asset(
                path: "/Users/susu/.claude/skills/peon-ping-config/SKILL.md",
                owner: .claude,
                kind: .skill,
                title: "peon-ping-config"
            ),
            asset(
                path: "/Users/susu/.codex/plugins/cache/openai-curated/github/08373044/skills/github/SKILL.md",
                owner: .codex,
                kind: .skill,
                title: "github"
            )
        ])

        let groups = ContextCapabilityGrouper().groups(items: catalog.capabilityItems)
        let familyGroup = try XCTUnwrap(groups.first)

        XCTAssertEqual(familyGroup.title, "peon-ping")
        XCTAssertEqual(familyGroup.rootPath, "/Users/susu/.claude/skills")
        XCTAssertEqual(familyGroup.items.map(\.asset.title), ["peon-ping-config", "peon-ping-use"])
        XCTAssertEqual(groups.last?.title, "github")
    }

    func testFlatInstalledSkillMergesWithMatchingLocalRepositorySkill() throws {
        let flatPath = "/Users/susu/.agents/skills/build-mcp-server/SKILL.md"
        let catalog = ContextCatalogAnalyzer().catalog(assets: [
            asset(
                path: flatPath,
                owner: .agents,
                kind: .skill,
                title: "build-mcp-server"
            ),
            asset(
                path: "/Users/susu/.claude/plugins/marketplaces/claude-plugins-official/plugins/mcp-server-dev/skills/build-mcp-server/SKILL.md",
                owner: .claude,
                kind: .skill,
                title: "build-mcp-server"
            ),
            asset(
                path: "/Users/susu/.claude/plugins/marketplaces/claude-plugins-official/plugins/mcp-server-dev/skills/build-mcp-app/SKILL.md",
                owner: .claude,
                kind: .skill,
                title: "build-mcp-app"
            )
        ])

        let group = try XCTUnwrap(ContextCapabilityGrouper().groups(items: catalog.capabilityItems).first)

        XCTAssertEqual(group.title, "mcp-server-dev")
        XCTAssertEqual(group.rootPath, "/Users/susu/.claude/plugins/marketplaces/claude-plugins-official/plugins/mcp-server-dev")
        XCTAssertEqual(group.groupingBasis.kind, .sameNameSkillCopies)
        XCTAssertFalse(group.groupingBasis.isRuntimeMerge)
        XCTAssertEqual(group.groupingBasis.sourceURL, "https://developers.openai.com/codex/skills")
        XCTAssertEqual(group.items.count, 3)
        XCTAssertTrue(group.items.map(\.asset.path).contains(flatPath))
    }

    func testSectionsSplitUserSkillsMCPAndOfficialCapabilitiesByPriority() throws {
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
                path: "/Users/susu/.claude/commands/deploy.md",
                owner: .claude,
                kind: .command,
                title: "deploy"
            ),
            asset(
                path: "/Users/susu/.codex/plugins/cache/openai-curated/figma/08373044/skills/figma-use/SKILL.md",
                owner: .codex,
                kind: .skill,
                title: "figma-use"
            )
        ])

        let sections = ContextCapabilityGrouper().sections(items: catalog.capabilityItems)

        XCTAssertEqual(
            sections.map(\.category),
            [.userSkills, .mcpTools, .localCapabilities, .officialCapabilities]
        )
        XCTAssertEqual(sections.first?.groups.first?.items.first?.asset.title, "build-mcp-server")
        XCTAssertEqual(sections.first?.groups.first?.groupingBasis.kind, .skillDirectory)
        XCTAssertEqual(sections.first { $0.category == .mcpTools }?.groups.first?.groupingBasis.kind, .mcpConfiguration)
        XCTAssertEqual(sections.last?.category, .officialCapabilities)
        XCTAssertEqual(sections.last?.groups.first?.title, "figma")
    }

    func testFlatSkillsShareAggressiveTopicFamiliesWhenMultipleItemsMatch() throws {
        let catalog = ContextCatalogAnalyzer().catalog(assets: [
            asset(
                path: "/Users/susu/.agents/skills/frontend-design/SKILL.md",
                owner: .agents,
                kind: .skill,
                title: "frontend-design"
            ),
            asset(
                path: "/Users/susu/.agents/skills/frontend-ui-engineering/SKILL.md",
                owner: .agents,
                kind: .skill,
                title: "frontend-ui-engineering"
            ),
            asset(
                path: "/Users/susu/.agents/skills/agent-development/SKILL.md",
                owner: .agents,
                kind: .skill,
                title: "agent-development"
            ),
            asset(
                path: "/Users/susu/.agents/skills/hook-development/SKILL.md",
                owner: .agents,
                kind: .skill,
                title: "hook-development"
            ),
            asset(
                path: "/Users/susu/.agents/skills/source-driven-development/SKILL.md",
                owner: .agents,
                kind: .skill,
                title: "source-driven-development"
            ),
            asset(
                path: "/Users/susu/.agents/skills/spec-driven-development/SKILL.md",
                owner: .agents,
                kind: .skill,
                title: "spec-driven-development"
            ),
            asset(
                path: "/Users/susu/.agents/skills/build-mcpb/SKILL.md",
                owner: .agents,
                kind: .skill,
                title: "build-mcpb"
            ),
            asset(
                path: "/Users/susu/.agents/skills/build-mcp-server/SKILL.md",
                owner: .agents,
                kind: .skill,
                title: "build-mcp-server"
            )
        ])

        let groups = ContextCapabilityGrouper().groups(items: catalog.capabilityItems)
        let groupedTitles = Set(groups.filter { $0.items.count > 1 }.map(\.title))

        XCTAssertTrue(groupedTitles.contains("frontend"))
        XCTAssertTrue(groupedTitles.contains("development"))
        XCTAssertTrue(groupedTitles.contains("driven-development"))
        XCTAssertTrue(groupedTitles.contains("build-mcp"))
    }

    func testFlatUserSkillsStaySeparate() {
        let catalog = ContextCatalogAnalyzer().catalog(assets: [
            asset(
                path: "/Users/susu/.agents/skills/build/SKILL.md",
                owner: .agents,
                kind: .skill,
                title: "build"
            ),
            asset(
                path: "/Users/susu/.agents/skills/review/SKILL.md",
                owner: .agents,
                kind: .skill,
                title: "review"
            )
        ])

        let groups = ContextCapabilityGrouper().groups(items: catalog.capabilityItems)

        XCTAssertEqual(groups.count, 2)
        XCTAssertEqual(Set(groups.map(\.title)), Set(["build", "review"]))
        XCTAssertEqual(Set(groups.map(\.items.count)), Set([1]))
    }

    func testFallbackGroupsNonSkillCapabilitiesByParentAndSortsStably() throws {
        let catalog = ContextCatalogAnalyzer().catalog(assets: [
            asset(
                path: "/Users/susu/.codex/config.toml",
                owner: .codex,
                kind: .config,
                title: "config"
            ),
            asset(
                path: "/Users/susu/.claude/commands/deploy.md",
                owner: .claude,
                kind: .command,
                title: "deploy"
            ),
            asset(
                path: "/Users/susu/.claude/commands/build.md",
                owner: .claude,
                kind: .command,
                title: "build"
            )
        ])

        let groups = ContextCapabilityGrouper().groups(items: catalog.capabilityItems)
        let commandGroup = try XCTUnwrap(groups.first { $0.primaryKind == .command })

        XCTAssertEqual(groups.map(\.primaryKind), [.command, .config])
        XCTAssertEqual(commandGroup.rootPath, "/Users/susu/.claude/commands")
        XCTAssertEqual(commandGroup.title, "commands")
        XCTAssertEqual(commandGroup.items.map(\.asset.title), ["build", "deploy"])
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
