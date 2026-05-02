import Foundation

public struct OrganizationAssetDigest: Identifiable, Codable, Equatable, Sendable {
    public var id: String { path }
    public let path: String
    public let title: String
    public let owner: AgentOwner
    public let kind: AssetKind
    public let summary: String
    public let statusFlags: [AssetStatusFlag]
    public let aiSummary: String?

    public init(asset: AgentAsset, aiSummary: String? = nil) {
        self.path = asset.path
        self.title = asset.title
        self.owner = asset.owner
        self.kind = asset.kind
        self.summary = asset.summary
        self.statusFlags = asset.statusFlags
        self.aiSummary = aiSummary
    }
}

public struct OrganizationBucket: Identifiable, Codable, Equatable, Sendable {
    public var id: String { "\(audience)-\(kind.rawValue)" }
    public let audience: String
    public let kind: AssetKind
    public let title: String
    public let summary: String
    public let assets: [OrganizationAssetDigest]

    public init(
        audience: String,
        kind: AssetKind,
        title: String,
        summary: String,
        assets: [OrganizationAssetDigest]
    ) {
        self.audience = audience
        self.kind = kind
        self.title = title
        self.summary = summary
        self.assets = assets
    }
}

public struct OrganizationMap: Codable, Equatable, Sendable {
    public let totalAssets: Int
    public let buckets: [OrganizationBucket]
    public let audienceCounts: [String: Int]
    public let kindCounts: [AssetKind: Int]
    public let ownerCounts: [AgentOwner: Int]
    public let statusCounts: [AssetStatusFlag: Int]

    public init(
        totalAssets: Int,
        buckets: [OrganizationBucket],
        audienceCounts: [String: Int],
        kindCounts: [AssetKind: Int],
        ownerCounts: [AgentOwner: Int],
        statusCounts: [AssetStatusFlag: Int]
    ) {
        self.totalAssets = totalAssets
        self.buckets = buckets
        self.audienceCounts = audienceCounts
        self.kindCounts = kindCounts
        self.ownerCounts = ownerCounts
        self.statusCounts = statusCounts
    }

    public static let empty = OrganizationMap(
        totalAssets: 0,
        buckets: [],
        audienceCounts: [:],
        kindCounts: [:],
        ownerCounts: [:],
        statusCounts: [:]
    )
}

public enum OrganizationAction: String, CaseIterable, Codable, Sendable {
    case keep = "Keep"
    case merge = "Merge"
    case archive = "Archive"
    case hide = "Hide"
    case review = "Review"
}

public struct OrganizationRecommendation: Identifiable, Codable, Equatable, Sendable {
    public var id: String { "\(action.rawValue)-\(primaryAssetPath)-\(title)" }
    public let action: OrganizationAction
    public let title: String
    public let reason: String
    public let primaryAssetPath: String
    public let relatedAssetPaths: [String]
    public let confidence: Double
    public let isApprovedByDefault: Bool

    public init(
        action: OrganizationAction,
        title: String,
        reason: String,
        primaryAssetPath: String,
        relatedAssetPaths: [String] = [],
        confidence: Double,
        isApprovedByDefault: Bool = false
    ) {
        self.action = action
        self.title = title
        self.reason = reason
        self.primaryAssetPath = primaryAssetPath
        self.relatedAssetPaths = relatedAssetPaths
        self.confidence = confidence
        self.isApprovedByDefault = isApprovedByDefault
    }
}

public struct OrganizationPlan: Codable, Equatable, Sendable {
    public let map: OrganizationMap
    public let recommendations: [OrganizationRecommendation]
    public let source: String
    public let requiresHumanApproval: Bool

    public init(
        map: OrganizationMap,
        recommendations: [OrganizationRecommendation],
        source: String,
        requiresHumanApproval: Bool = true
    ) {
        self.map = map
        self.recommendations = recommendations
        self.source = source
        self.requiresHumanApproval = requiresHumanApproval
    }

    public static let empty = OrganizationPlan(
        map: .empty,
        recommendations: [],
        source: "empty"
    )
}
