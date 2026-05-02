import Foundation

public struct AssetImpactAnalyzer: Sendable {
    private let index: AssetReferenceIndex?

    public init(index: AssetReferenceIndex? = nil) {
        self.index = index
    }

    public func impact(for asset: AgentAsset, in assets: [AgentAsset]) -> AssetImpact {
        AssetImpactAnalyzer(index: AssetReferenceIndex(assets: assets)).impact(for: asset)
    }

    public func impact(for asset: AgentAsset) -> AssetImpact {
        guard let index else {
            return AssetImpact(assetPath: asset.path, outgoingReferences: [], incomingReferences: [])
        }
        return index.impact(for: asset)
    }
}

public struct AssetReferenceIndex: Sendable {
    private let outgoingBySourcePath: [String: [AssetDependencyLink]]
    private let incomingByTargetPath: [String: [AssetDependencyLink]]

    public init(assets: [AgentAsset]) {
        var assetsByNormalizedPath: [String: AgentAsset] = [:]
        for asset in assets {
            assetsByNormalizedPath[Self.normalizePath(asset.path)] = asset
            assetsByNormalizedPath[Self.normalizePath(asset.displayPath)] = asset
        }

        var outgoingBySourcePath: [String: [AssetDependencyLink]] = [:]
        var incomingByTargetPath: [String: [AssetDependencyLink]] = [:]

        for source in assets {
            let outgoing = Self.references(in: source).map { reference in
                let target = assetsByNormalizedPath[Self.normalizePath(reference)]
                return AssetDependencyLink(
                    sourcePath: source.path,
                    sourceTitle: source.title,
                    reference: reference,
                    targetPath: target?.path,
                    targetTitle: target?.title,
                    isMissing: target == nil,
                    isStaleReference: Self.isStaleReference(reference)
                )
            }
            outgoingBySourcePath[source.path] = outgoing

            for link in outgoing {
                guard let targetPath = link.targetPath else { continue }
                incomingByTargetPath[targetPath, default: []].append(link)
            }
        }

        self.outgoingBySourcePath = outgoingBySourcePath.mapValues(Self.sortedLinks)
        self.incomingByTargetPath = incomingByTargetPath.mapValues(Self.sortedLinks)
    }

    public func impact(for asset: AgentAsset) -> AssetImpact {
        AssetImpact(
            assetPath: asset.path,
            outgoingReferences: outgoingBySourcePath[asset.path] ?? [],
            incomingReferences: incomingByTargetPath[asset.path] ?? []
        )
    }

    private static func references(in asset: AgentAsset) -> [String] {
        let values = asset.dependencies + asset.relatedFiles
        return Array(Set(values.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }))
            .sorted()
    }

    private static func normalizePath(_ value: String) -> String {
        let expanded = (value as NSString).expandingTildeInPath
        return URL(fileURLWithPath: expanded).standardizedFileURL.path
    }

    private static func isStaleReference(_ reference: String) -> Bool {
        reference.contains("~/.claude") || reference.contains("/.claude/")
    }

    private static func sortedLinks(_ links: [AssetDependencyLink]) -> [AssetDependencyLink] {
        links.sorted { left, right in
            if left.sourcePath != right.sourcePath {
                return left.sourcePath.localizedCaseInsensitiveCompare(right.sourcePath) == .orderedAscending
            }
            return left.reference.localizedCaseInsensitiveCompare(right.reference) == .orderedAscending
        }
    }
}
