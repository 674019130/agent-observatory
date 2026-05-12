import Foundation

public struct OrganizerBrief: Codable, Equatable, Sendable {
    public let headline: String
    public let summary: String
    public let landscape: [String]
    public let focusAreas: [String]
    public let recommendedGoal: CleanupReviewGoal

    public init(
        headline: String,
        summary: String,
        landscape: [String],
        focusAreas: [String],
        recommendedGoal: CleanupReviewGoal
    ) {
        self.headline = headline
        self.summary = summary
        self.landscape = landscape
        self.focusAreas = focusAreas
        self.recommendedGoal = recommendedGoal
    }

    public static let empty = OrganizerBrief(
        headline: "",
        summary: "",
        landscape: [],
        focusAreas: [],
        recommendedGoal: .fullReview
    )
}
