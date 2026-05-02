import Foundation

public struct ScanSummary: Equatable, Sendable {
    public let totalAssets: Int
    public let sources: [AgentOwner: Int]
    public let kinds: [AssetKind: Int]
    public let warnings: Int

    public init(assets: [AgentAsset]) {
        totalAssets = assets.count
        sources = Dictionary(grouping: assets, by: \.owner).mapValues(\.count)
        kinds = Dictionary(grouping: assets, by: \.kind).mapValues(\.count)
        warnings = assets.filter { !$0.statusFlags.isEmpty }.count
    }
}
