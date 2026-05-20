import XCTest
@testable import AgentObservatoryCore

final class SystemPromptPreviewBuilderTests: XCTestCase {
    func testPreviewSeparatesPromptMaterialFromRegistriesAndFiltersBySurface() {
        let codexMemory = item(
            title: "Codex Memory",
            owner: .codex,
            kind: .memory,
            role: .memory,
            layer: .global,
            surfaces: [.codex],
            destination: .memoryBlock
        )
        let sharedInstruction = item(
            title: "Shared Instruction",
            owner: .agents,
            kind: .instruction,
            role: .memory,
            layer: .shared,
            surfaces: [.claude, .codex],
            destination: .systemPrompt
        )
        let sharedSkill = item(
            title: "Shared Skill",
            owner: .agents,
            kind: .skill,
            role: .capability,
            layer: .global,
            surfaces: [.claude, .codex],
            destination: .skillRegistry
        )
        let claudeOnlyTool = item(
            title: "Claude MCP",
            owner: .claude,
            kind: .mcp,
            role: .capability,
            layer: .configuration,
            surfaces: [.claude],
            destination: .toolRegistry
        )
        let catalog = ContextCatalog(
            memoryItems: [codexMemory, sharedInstruction],
            capabilityItems: [sharedSkill, claudeOnlyTool],
            assemblySteps: []
        )

        let preview = SystemPromptPreviewBuilder().preview(
            surface: .codex,
            catalog: catalog,
            visibleCapabilityItems: [sharedSkill, claudeOnlyTool]
        )

        XCTAssertEqual(preview.promptMaterialItemCount, 2)
        XCTAssertEqual(preview.registryItemCount, 1)
        XCTAssertEqual(Set(preview.sections.flatMap { $0.items.map(\.asset.title) }), Set(["Codex Memory", "Shared Instruction", "Shared Skill"]))
        XCTAssertFalse(preview.sections.flatMap(\.items).contains { $0.asset.title == "Claude MCP" })
    }

    func testSectionsAreStableAndPromptMaterialAppearsBeforeRegistries() {
        let skill = item(
            title: "Skill",
            owner: .agents,
            kind: .skill,
            role: .capability,
            layer: .global,
            surfaces: [.codex],
            destination: .skillRegistry
        )
        let projectInstruction = item(
            title: "Project AGENTS",
            owner: .project,
            kind: .instruction,
            role: .memory,
            layer: .project,
            surfaces: [.codex],
            destination: .projectContextBlock
        )
        let globalInstruction = item(
            title: "Global AGENTS",
            owner: .codex,
            kind: .instruction,
            role: .memory,
            layer: .global,
            surfaces: [.codex],
            destination: .systemPrompt
        )
        let catalog = ContextCatalog(
            memoryItems: [projectInstruction, globalInstruction],
            capabilityItems: [skill],
            assemblySteps: []
        )

        let destinations = SystemPromptPreviewBuilder()
            .preview(surface: .codex, catalog: catalog, visibleCapabilityItems: [skill])
            .sections
            .map(\.destination)

        XCTAssertEqual(destinations, [.systemPrompt, .projectContextBlock, .skillRegistry])
    }

    func testMarkdownExplainsThatPreviewIsLocalAndCanBeDisplayLimited() {
        let first = item(
            title: "First",
            owner: .codex,
            kind: .memory,
            role: .memory,
            layer: .global,
            surfaces: [.codex],
            destination: .memoryBlock,
            preview: "First preview"
        )
        let second = item(
            title: "Second",
            owner: .codex,
            kind: .memory,
            role: .memory,
            layer: .project,
            surfaces: [.codex],
            destination: .projectContextBlock,
            preview: "Second preview"
        )
        let catalog = ContextCatalog(memoryItems: [first, second], capabilityItems: [], assemblySteps: [])
        let builder = SystemPromptPreviewBuilder()
        let preview = builder.preview(surface: .codex, catalog: catalog, visibleCapabilityItems: [])

        let markdown = builder.markdown(for: preview, language: .english, itemLimit: 1)

        XCTAssertTrue(markdown.contains("does not expose the hidden vendor system prompt"))
        XCTAssertTrue(markdown.contains("First preview"))
        XCTAssertFalse(markdown.contains("Second preview"))
        XCTAssertTrue(markdown.contains("Preview truncated for display"))
    }

    private func item(
        title: String,
        owner: AgentOwner,
        kind: AssetKind,
        role: AgentContextRole,
        layer: AgentContextLayer,
        surfaces: [AgentOwner],
        destination: ContextLoadDestination,
        preview: String = "Preview"
    ) -> ContextCatalogItem {
        let asset = AgentAsset(
            path: "/Users/susu/\(title.replacingOccurrences(of: " ", with: "-")).md",
            owner: owner,
            kind: kind,
            scope: owner == .project ? "project" : "global",
            title: title,
            summary: "Summary for \(title)",
            byteCount: 100,
            contentHash: title,
            preview: preview
        )
        let route = ContextLoadRoute(
            role: role,
            layer: layer,
            memoryType: role == .memory ? .longTerm : nil,
            surfaces: surfaces,
            destination: destination,
            trigger: destination.isPromptMaterial ? .globalStartup : .skillDiscovery
        )
        return ContextCatalogItem(
            asset: asset,
            role: role,
            layer: layer,
            memoryType: role == .memory ? .longTerm : nil,
            surfaces: surfaces,
            loadRoute: route
        )
    }
}
