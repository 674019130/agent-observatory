import Foundation

public struct ContextLoadAnalyzer: Sendable {
    public init() {}

    public func route(for asset: AgentAsset) -> ContextLoadRoute {
        let role = role(for: asset)
        let layer = layer(for: asset)
        let memoryType = role == .memory ? memoryType(for: asset) : nil

        return ContextLoadRoute(
            role: role,
            layer: layer,
            memoryType: memoryType,
            surfaces: surfaces(for: asset),
            destination: destination(for: asset, role: role, layer: layer, memoryType: memoryType),
            trigger: trigger(for: asset, layer: layer),
            skillInstallOrigin: skillInstallOrigin(for: asset)
        )
    }

    private func role(for asset: AgentAsset) -> AgentContextRole? {
        switch asset.kind {
        case .memory, .instruction, .rule, .session:
            .memory
        case .skill, .command, .mcp, .plugin, .script, .config:
            .capability
        case .unknown:
            nil
        }
    }

    private func layer(for asset: AgentAsset) -> AgentContextLayer {
        let path = asset.path.lowercased()
        let scope = asset.scope.lowercased()

        if asset.kind == .session || path.contains("/sessions/") {
            return .session
        }

        if asset.kind == .config || path.contains("settings") || path.contains("config") {
            return .configuration
        }

        if path.contains("/plugins/") || path.contains("/plugins/cache/") || path.contains("/marketplaces/") {
            return .pluginProvided
        }

        if asset.owner == .agents || path.contains("/.agents/") {
            return .shared
        }

        if scope.contains("workspace") || path.contains("/workspaces/") || path.contains("/workspace/") {
            return .workspace
        }

        if asset.owner == .project
            || scope.contains("project")
            || path.contains("/.claude/projects/")
            || path.contains("/.codex/projects/")
        {
            return .project
        }

        return .global
    }

    private func memoryType(for asset: AgentAsset) -> AgentMemoryType {
        let path = asset.path.lowercased()
        let title = asset.title.lowercased()
        let scope = asset.scope.lowercased()

        if path.contains("/.codex/automations/") && path.hasSuffix("/memory.md") {
            return .automation
        }

        if path.contains("favorite_tools")
            || title.contains("favorite tools")
            || title.contains("preferences")
            || title.contains("preference")
        {
            return .preference
        }

        if asset.kind == .session
            || path.contains("/rollout_summaries/")
            || path.contains("/sessions/")
            || path.contains("/plans/")
        {
            return .sessionHistory
        }

        if scope.contains("workspace") || path.contains("/workspaces/") || path.contains("/workspace/") {
            return .workspace
        }

        if asset.owner == .project
            || scope.contains("project")
            || path.contains("/.claude/projects/")
            || path.contains("/.codex/projects/")
        {
            return .project
        }

        if asset.owner == .agents || path.contains("/.agents/") {
            return .shared
        }

        if asset.kind == .rule || path.contains("/rules/") {
            return .contextRules
        }

        if path.contains("/plugins/") || path.contains("/plugins/cache/") || path.contains("/marketplaces/") {
            return .pluginProvided
        }

        if asset.kind == .instruction
            || path.hasSuffix("/agents.md")
            || path.hasSuffix("/claude.md")
        {
            return .instructions
        }

        return .longTerm
    }

    private func surfaces(for asset: AgentAsset) -> [AgentOwner] {
        let path = asset.path.lowercased()
        let title = asset.title.lowercased()

        switch asset.owner {
        case .claude:
            return [.claude]
        case .codex:
            return [.codex]
        case .agents:
            return [.claude, .codex]
        case .project:
            if path.contains(".claude") || title.contains("claude") {
                return [.claude]
            }
            if path.contains(".codex") || title.contains("agents.md") || title.contains("codex") {
                return [.codex]
            }
            if path.hasSuffix("claude.md") {
                return [.claude]
            }
            if path.hasSuffix("agents.md") {
                return [.codex]
            }
            return [.claude, .codex]
        case .unknown:
            return []
        }
    }

    private func destination(
        for asset: AgentAsset,
        role: AgentContextRole?,
        layer: AgentContextLayer,
        memoryType: AgentMemoryType?
    ) -> ContextLoadDestination {
        switch asset.kind {
        case .instruction, .rule:
            if layer == .pluginProvided {
                return .pluginInstructionBlock
            }
            if layer == .project {
                return .projectContextBlock
            }
            if layer == .workspace {
                return .workspaceContextBlock
            }
            return .systemPrompt
        case .memory:
            switch memoryType {
            case .project:
                return .projectContextBlock
            case .workspace:
                return .workspaceContextBlock
            case .pluginProvided, .contextRules, .instructions:
                return .pluginInstructionBlock
            case .sessionHistory:
                return .sessionArchive
            case .longTerm, .automation, .preference, .shared, .none:
                return .memoryBlock
            }
        case .skill:
            return .skillRegistry
        case .command:
            return .commandRegistry
        case .mcp:
            return .toolRegistry
        case .plugin:
            return .pluginRegistry
        case .config:
            return .configuration
        case .script:
            return .supportFile
        case .session:
            return .sessionArchive
        case .unknown:
            return role == nil ? .indexOnly : .supportFile
        }
    }

    private func trigger(for asset: AgentAsset, layer: AgentContextLayer) -> ContextLoadTrigger {
        switch asset.kind {
        case .skill:
            return .skillDiscovery
        case .command:
            return .commandDiscovery
        case .mcp:
            return .mcpConfiguration
        case .plugin:
            return .pluginDiscovery
        case .config:
            return .settingsConfiguration
        case .script:
            return .supportFileReference
        case .session:
            return .sessionHistory
        case .memory, .instruction, .rule:
            switch layer {
            case .project:
                return .projectDiscovery
            case .workspace:
                return .workspaceSource
            case .pluginProvided:
                return .pluginDiscovery
            case .session:
                return .sessionHistory
            case .configuration:
                return .settingsConfiguration
            case .global, .shared:
                return .globalStartup
            }
        case .unknown:
            return .observatoryIndex
        }
    }

    private func skillInstallOrigin(for asset: AgentAsset) -> SkillInstallOrigin? {
        guard asset.kind == .skill else { return nil }

        let path = asset.path.lowercased()

        if asset.owner == .project {
            return .projectLocal
        }

        if path.contains("/.codex/skills/.system/")
            || path.contains("/.codex/plugins/cache/openai-bundled/")
            || path.contains("/.codex/plugins/cache/openai-primary-runtime/")
        {
            return .preset
        }

        if path.contains("/.codex/plugins/cache/openai-curated/")
            || path.contains("/.codex/plugins/cache/claude-plugins-official/")
            || path.contains("/claude-plugins-official/")
        {
            return .officialPlugin
        }

        if path.contains("/.agents/skills/")
            || path.contains("/.claude/skills/")
            || path.contains("/.claude/plugins/")
            || path.contains("/.codex/plugins/cache/")
            || (path.contains("/.codex/skills/") && !path.contains("/.codex/skills/.system/"))
        {
            return .userInstalled
        }

        return .unknown
    }
}
