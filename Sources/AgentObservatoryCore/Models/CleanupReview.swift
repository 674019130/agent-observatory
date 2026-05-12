import Foundation

public enum CleanupReviewGoal: String, CaseIterable, Codable, Identifiable, Sendable {
    case fullReview = "Full Review"
    case legacyClaudeCleanup = "Claude Legacy"
    case duplicateCleanup = "Duplicates"
    case noiseCleanup = "Noise"
    case riskCleanup = "Risks"

    public var id: String { rawValue }
}

public enum CleanupReviewAction: String, CaseIterable, Codable, Sendable {
    case archive = "Archive"
    case hide = "Hide"
    case merge = "Merge"
    case review = "Review"
    case keep = "Keep"
}

public enum CleanupReviewRisk: String, CaseIterable, Codable, Sendable {
    case low = "Low"
    case medium = "Medium"
    case high = "High"
}

public struct CleanupReviewGroup: Identifiable, Codable, Equatable, Sendable {
    public let id: String
    public let title: String
    public let summary: String
    public let action: CleanupReviewAction
    public let risk: CleanupReviewRisk
    public let confidence: Double
    public let assetPaths: [String]
    public let evidence: [String]

    public init(
        id: String,
        title: String,
        summary: String,
        action: CleanupReviewAction,
        risk: CleanupReviewRisk,
        confidence: Double,
        assetPaths: [String],
        evidence: [String]
    ) {
        self.id = id
        self.title = title
        self.summary = summary
        self.action = action
        self.risk = risk
        self.confidence = confidence
        self.assetPaths = assetPaths
        self.evidence = evidence
    }

    public var canApplyAutomatically: Bool {
        switch action {
        case .archive, .hide:
            true
        case .merge:
            assetPaths.count > 1
        case .review, .keep:
            false
        }
    }

    public var automaticApplyAssetPaths: [String] {
        switch action {
        case .archive, .hide:
            assetPaths
        case .merge:
            Array(assetPaths.dropFirst())
        case .review, .keep:
            []
        }
    }
}

public struct CleanupReviewSession: Codable, Equatable, Sendable {
    public let goal: CleanupReviewGoal
    public let groups: [CleanupReviewGroup]
    public let totalAssets: Int
    public let createdAt: Date
    public let source: String

    public init(
        goal: CleanupReviewGoal,
        groups: [CleanupReviewGroup],
        totalAssets: Int,
        createdAt: Date = Date(),
        source: String = "local"
    ) {
        self.goal = goal
        self.groups = groups
        self.totalAssets = totalAssets
        self.createdAt = createdAt
        self.source = source
    }

    public static let empty = CleanupReviewSession(
        goal: .fullReview,
        groups: [],
        totalAssets: 0,
        createdAt: Date(timeIntervalSince1970: 0),
        source: "empty"
    )
}
