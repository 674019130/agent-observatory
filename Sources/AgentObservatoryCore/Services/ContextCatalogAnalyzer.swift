import Foundation

public struct ContextCatalogAnalyzer: Sendable {
    private let loadAnalyzer: ContextLoadAnalyzer

    public init(loadAnalyzer: ContextLoadAnalyzer = ContextLoadAnalyzer()) {
        self.loadAnalyzer = loadAnalyzer
    }

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
            let route = loadAnalyzer.route(for: asset)
            guard let role = route.role else { continue }
            let item = ContextCatalogItem(
                asset: asset,
                role: role,
                layer: route.layer,
                memoryType: route.memoryType,
                surfaces: route.surfaces,
                loadRoute: route
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
