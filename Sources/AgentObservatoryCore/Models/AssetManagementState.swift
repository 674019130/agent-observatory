import Foundation

public struct AssetManagementState: Codable, Equatable, Sendable {
    public var hiddenAssetPaths: Set<String>
    public var archivedAssets: [ArchivedAsset]
    public var operationBatches: [ManagementOperationBatch]

    public init(
        hiddenAssetPaths: Set<String> = [],
        archivedAssets: [ArchivedAsset] = [],
        operationBatches: [ManagementOperationBatch] = []
    ) {
        self.hiddenAssetPaths = hiddenAssetPaths
        self.archivedAssets = archivedAssets
        self.operationBatches = operationBatches
    }

    private enum CodingKeys: String, CodingKey {
        case hiddenAssetPaths
        case archivedAssets
        case operationBatches
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.hiddenAssetPaths = try container.decodeIfPresent(Set<String>.self, forKey: .hiddenAssetPaths) ?? []
        self.archivedAssets = try container.decodeIfPresent([ArchivedAsset].self, forKey: .archivedAssets) ?? []
        self.operationBatches = try container.decodeIfPresent([ManagementOperationBatch].self, forKey: .operationBatches) ?? []
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

    public mutating func addOperationBatch(_ batch: ManagementOperationBatch) {
        guard !batch.records.isEmpty else { return }
        operationBatches.removeAll { $0.id == batch.id }
        operationBatches.insert(batch, at: 0)
        operationBatches = Array(operationBatches.prefix(50))
    }

    public mutating func replaceOperationBatch(_ batch: ManagementOperationBatch) {
        guard let index = operationBatches.firstIndex(where: { $0.id == batch.id }) else { return }
        operationBatches[index] = batch
    }
}
