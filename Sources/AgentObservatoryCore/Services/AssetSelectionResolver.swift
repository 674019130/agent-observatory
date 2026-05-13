import Foundation

public enum AssetSelectionSurface: Sendable {
    case assetTable
    case contextBrowser
}

public struct AssetSelectionResolver: Sendable {
    public init() {}

    public func selectedAsset(
        selectedAssetID: AgentAsset.ID?,
        visibleAssets: [AgentAsset],
        filteredAssets: [AgentAsset],
        surface: AssetSelectionSurface
    ) -> AgentAsset? {
        guard let selectedAssetID else { return filteredAssets.first }

        let selectionPool: [AgentAsset] = switch surface {
        case .assetTable:
            filteredAssets
        case .contextBrowser:
            visibleAssets
        }

        return selectionPool.first { $0.id == selectedAssetID } ?? filteredAssets.first
    }
}
