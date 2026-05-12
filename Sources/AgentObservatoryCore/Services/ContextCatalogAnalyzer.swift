import Foundation

public struct ContextCatalogAnalyzer: Sendable {
    public init() {}

    public func catalog(assets: [AgentAsset]) -> ContextCatalog {
        let sortedAssets = assets.sorted { left, right in
            if left.owner != right.owner {
                return left.owner.rawValue < right.owner.rawValue
            }
            if left.kind != right.kind {
                return left.kind.rawValue < right.kind.rawValue
            }
            return left.displayPath.localizedStandardCompare(right.displayPath) == .orderedAscending
        }

        var memoryItems: [ContextCatalogItem] = []
        var capabilityItems: [ContextCatalogItem] = []

        for asset in sortedAssets {
            guard let role = role(for: asset) else { continue }
            let item = ContextCatalogItem(
                asset: asset,
                role: role,
                layer: layer(for: asset),
                memoryType: role == .memory ? memoryType(for: asset) : nil,
                surfaces: surfaces(for: asset)
            )

            switch role {
            case .memory:
                memoryItems.append(item)
            case .capability:
                capabilityItems.append(item)
            }
        }

        memoryItems.sort(by: itemSort)
        capabilityItems.sort(by: itemSort)

        return ContextCatalog(
            memoryItems: memoryItems,
            capabilityItems: capabilityItems,
            assemblySteps: assemblySteps(memoryItems: memoryItems, capabilityItems: capabilityItems)
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

    private func assemblySteps(
        memoryItems: [ContextCatalogItem],
        capabilityItems: [ContextCatalogItem]
    ) -> [ContextAssemblyStep] {
        var steps: [ContextAssemblyStep] = []
        let surfaces: [AgentOwner] = [.claude, .codex]

        for surface in surfaces {
            for role in AgentContextRole.allCases {
                for layer in AgentContextLayer.allCases.sorted(by: { $0.sortIndex < $1.sortIndex }) {
                    let sourceItems = role == .memory ? memoryItems : capabilityItems
                    let scopedItems = sourceItems.filter {
                        $0.surfaces.contains(surface) && $0.layer == layer
                    }
                    guard !scopedItems.isEmpty else { continue }

                    steps.append(
                        ContextAssemblyStep(
                            surface: surface,
                            role: role,
                            layer: layer,
                            items: scopedItems.sorted(by: itemSort)
                        )
                    )
                }
            }
        }

        return steps
    }

    private func itemSort(_ left: ContextCatalogItem, _ right: ContextCatalogItem) -> Bool {
        if left.memoryType != right.memoryType {
            let leftIndex = left.memoryType?.sortIndex ?? Int.max
            let rightIndex = right.memoryType?.sortIndex ?? Int.max
            if leftIndex != rightIndex {
                return leftIndex < rightIndex
            }
        }
        if left.layer != right.layer {
            return left.layer.sortIndex < right.layer.sortIndex
        }
        if left.asset.kind != right.asset.kind {
            return left.asset.kind.rawValue < right.asset.kind.rawValue
        }
        return left.asset.displayPath.localizedStandardCompare(right.asset.displayPath) == .orderedAscending
    }
}
