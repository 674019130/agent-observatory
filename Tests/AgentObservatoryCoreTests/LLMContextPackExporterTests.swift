import XCTest
@testable import AgentObservatoryCore

final class LLMContextPackExporterTests: XCTestCase {
    func testCurrentViewExportGroupsLargestFilesByApplication() {
        let codex = asset(
            path: "\(NSHomeDirectory())/.codex/memories/raw.md",
            owner: .codex,
            kind: .memory,
            title: "Raw Memories",
            preview: String(repeating: "codex ", count: 400)
        )
        let claude = asset(
            path: "\(NSHomeDirectory())/.claude/commands/build.md",
            owner: .claude,
            kind: .command,
            title: "Build Command",
            preview: String(repeating: "claude ", count: 250)
        )
        let markdown = LLMContextPackExporter().markdown(
            scopeTitle: "Overview",
            visibleAssets: [codex, claude],
            contextItems: [
                item(codex, role: .memory, destination: .memoryBlock),
                item(claude, role: .capability, destination: .commandRegistry)
            ],
            selectedAsset: nil,
            organizerRun: .empty,
            skillTriggerConflicts: [],
            options: LLMContextPackOptions(
                preset: .currentView,
                language: .english,
                generatedAt: Date(timeIntervalSince1970: 0)
            )
        )

        XCTAssertTrue(markdown.contains("# Agent Observatory Context Pack"))
        XCTAssertTrue(markdown.contains("## Ranked Files By Application"))
        XCTAssertTrue(markdown.contains("### Codex"))
        XCTAssertTrue(markdown.contains("### Claude Code"))
        XCTAssertTrue(markdown.contains("Raw Memories"))
        XCTAssertTrue(markdown.contains("Build Command"))
        XCTAssertTrue(markdown.contains("## Required Output Format"))
        XCTAssertTrue(markdown.contains("This export contains locally visible context only"))
    }

    func testSelectedItemExportUsesPathStyleAndLoadRoute() {
        let selected = asset(
            path: "\(NSHomeDirectory())/.agents/skills/frontend-design/SKILL.md",
            owner: .agents,
            kind: .skill,
            title: "frontend-design",
            summary: "Design rich frontends.",
            trigger: "Use when building UI.",
            preview: "Use strong layout and visual hierarchy."
        )
        let markdown = LLMContextPackExporter().markdown(
            scopeTitle: "Capabilities",
            visibleAssets: [selected],
            contextItems: [item(selected, role: .capability, destination: .skillRegistry)],
            selectedAsset: selected,
            organizerRun: .empty,
            skillTriggerConflicts: [],
            options: LLMContextPackOptions(
                preset: .selectedItem,
                target: .codex,
                language: .simplifiedChinese,
                pathStyle: .redactedUser,
                detailLevel: .snippets,
                generatedAt: Date(timeIntervalSince1970: 0)
            )
        )

        XCTAssertTrue(markdown.contains("# Agent Observatory 选中项上下文包"))
        XCTAssertTrue(markdown.contains("frontend-design"))
        XCTAssertTrue(markdown.contains("~/.agents/skills/frontend-design/SKILL.md"))
        XCTAssertTrue(markdown.contains("加载路径"))
        XCTAssertTrue(markdown.contains("目标模型是 Codex"))
        XCTAssertTrue(markdown.contains("```text"))
    }

    func testMigrationCleanupExportHighlightsOneSidedMemoriesAndNoOverwriteGuidance() {
        let codexOnly = asset(
            path: "\(NSHomeDirectory())/.codex/memories/raw.md",
            owner: .codex,
            kind: .memory,
            title: "Raw Memories",
            preview: "Only exists in Codex."
        )
        let claudeOnly = asset(
            path: "\(NSHomeDirectory())/.claude/projects/project/MEMORY.md",
            owner: .claude,
            kind: .memory,
            title: "Project Memory",
            preview: "Only exists in Claude Code."
        )
        let markdown = LLMContextPackExporter().markdown(
            scopeTitle: "Memories",
            visibleAssets: [codexOnly, claudeOnly],
            contextItems: [
                item(codexOnly, role: .memory, destination: .memoryBlock),
                item(claudeOnly, role: .memory, destination: .memoryBlock)
            ],
            selectedAsset: nil,
            organizerRun: OrganizerRun(
                status: .ready,
                title: "Diagnosis",
                summary: "Review duplicate and stale context.",
                totalAssetCount: 2,
                duplicateAssetCount: 1,
                noiseAssetCount: 0,
                sensitiveAssetCount: 0,
                stalePathAssetCount: 1,
                unclearAssetCount: 0,
                actionPacks: []
            ),
            skillTriggerConflicts: [],
            options: LLMContextPackOptions(
                preset: .migrationCleanup,
                language: .english,
                generatedAt: Date(timeIntervalSince1970: 0)
            )
        )

        XCTAssertTrue(markdown.contains("# Agent Observatory Migration and Cleanup Pack"))
        XCTAssertTrue(markdown.contains("Codex only"))
        XCTAssertTrue(markdown.contains("Claude Code only"))
        XCTAssertTrue(markdown.contains("Do not recommend overwriting files by default"))
        XCTAssertTrue(markdown.contains("Review duplicate and stale context."))
        XCTAssertTrue(markdown.contains("## One-Sided Memories"))
    }

    private func asset(
        path: String,
        owner: AgentOwner,
        kind: AssetKind,
        title: String,
        summary: String = "",
        trigger: String? = nil,
        preview: String
    ) -> AgentAsset {
        AgentAsset(
            path: path,
            owner: owner,
            kind: kind,
            scope: "test",
            title: title,
            summary: summary,
            trigger: trigger,
            contentHash: "\(title)-hash",
            preview: preview
        )
    }

    private func item(
        _ asset: AgentAsset,
        role: AgentContextRole,
        destination: ContextLoadDestination
    ) -> ContextCatalogItem {
        ContextCatalogItem(
            asset: asset,
            role: role,
            layer: asset.owner == .project ? .project : .global,
            memoryType: role == .memory ? .longTerm : nil,
            surfaces: [asset.owner],
            loadRoute: ContextLoadRoute(
                role: role,
                layer: asset.owner == .project ? .project : .global,
                memoryType: role == .memory ? .longTerm : nil,
                surfaces: [asset.owner],
                destination: destination,
                trigger: role == .memory ? .globalStartup : .skillDiscovery,
                skillInstallOrigin: role == .capability ? .userInstalled : nil
            )
        )
    }
}
