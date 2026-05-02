import Foundation

public struct AssetManagementState: Codable, Equatable, Sendable {
    public var hiddenAssetPaths: Set<String>
    public var archivedAssets: [ArchivedAsset]

    public init(
        hiddenAssetPaths: Set<String> = [],
        archivedAssets: [ArchivedAsset] = []
    ) {
        self.hiddenAssetPaths = hiddenAssetPaths
        self.archivedAssets = archivedAssets
    }

    public var archivedOriginalPaths: Set<String> {
        Set(archivedAssets.map(\.originalPath))
    }

    public func visibleAssets(from assets: [AgentAsset]) -> [AgentAsset] {
        let archivedPaths = archivedOriginalPaths
        return assets.filter { asset in
            !hiddenAssetPaths.contains(asset.path) && !archivedPaths.contains(asset.path)
        }
    }

    public func hiddenAssets(from assets: [AgentAsset]) -> [AgentAsset] {
        assets.filter { asset in
            hiddenAssetPaths.contains(asset.path)
        }
    }

    public mutating func hide(path: String) {
        hiddenAssetPaths.insert(path)
    }

    public mutating func unhide(path: String) {
        hiddenAssetPaths.remove(path)
    }

    public mutating func unhideAll() {
        hiddenAssetPaths.removeAll()
    }

    public mutating func addArchive(_ archivedAsset: ArchivedAsset) {
        archivedAssets.removeAll {
            $0.id == archivedAsset.id || $0.originalPath == archivedAsset.originalPath
        }
        archivedAssets.append(archivedAsset)
        archivedAssets.sort { left, right in
            left.archivedAt > right.archivedAt
        }
    }

    public mutating func removeArchive(id: ArchivedAsset.ID) {
        archivedAssets.removeAll { $0.id == id }
    }
}
