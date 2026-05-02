import Foundation

public enum OrganizationDetailSelectionKind: Equatable, Sendable {
    case recommendation
    case bucket
    case none
}

public struct OrganizationDetailSelection: Equatable, Sendable {
    public private(set) var recommendationID: String?
    public private(set) var bucketID: String?

    public init(recommendationID: String? = nil, bucketID: String? = nil) {
        self.recommendationID = recommendationID
        self.bucketID = recommendationID == nil ? bucketID : nil
    }

    public var kind: OrganizationDetailSelectionKind {
        if recommendationID != nil { return .recommendation }
        if bucketID != nil { return .bucket }
        return .none
    }

    public mutating func selectRecommendation(id: String) {
        recommendationID = id
        bucketID = nil
    }

    public mutating func selectBucket(id: String) {
        bucketID = id
        recommendationID = nil
    }

    public mutating func clear() {
        recommendationID = nil
        bucketID = nil
    }
}
