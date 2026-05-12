import Foundation

public struct OrganizerAdvancedContentState: Codable, Equatable, Sendable {
    public let isBuildingCleanupReview: Bool
    public let cleanupGroupCount: Int
    public let recommendationCount: Int
    public let organizationAssetCount: Int
    public let hasBuiltOrganizationMap: Bool

    public init(
        isBuildingCleanupReview: Bool,
        cleanupGroupCount: Int,
        recommendationCount: Int,
        organizationAssetCount: Int,
        hasBuiltOrganizationMap: Bool
    ) {
        self.isBuildingCleanupReview = isBuildingCleanupReview
        self.cleanupGroupCount = cleanupGroupCount
        self.recommendationCount = recommendationCount
        self.organizationAssetCount = organizationAssetCount
        self.hasBuiltOrganizationMap = hasBuiltOrganizationMap
    }

    public var isVisible: Bool {
        isBuildingCleanupReview
            || cleanupGroupCount > 0
            || recommendationCount > 0
            || (hasBuiltOrganizationMap && organizationAssetCount > 0)
    }
}
