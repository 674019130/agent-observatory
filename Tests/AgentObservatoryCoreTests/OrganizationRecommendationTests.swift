import XCTest
@testable import AgentObservatoryCore

final class OrganizationRecommendationTests: XCTestCase {
    func testArchiveHideAndMergeRecommendationsCanApplyAutomatically() {
        XCTAssertTrue(recommendation(action: .archive).canApplyAutomatically)
        XCTAssertTrue(recommendation(action: .hide).canApplyAutomatically)
        XCTAssertTrue(
            recommendation(
                action: .merge,
                relatedAssetPaths: ["/tmp/duplicate.md"]
            ).canApplyAutomatically
        )
        XCTAssertFalse(recommendation(action: .review).canApplyAutomatically)
        XCTAssertFalse(recommendation(action: .keep).canApplyAutomatically)
    }

    func testMergeRecommendationsOnlyArchiveRelatedAssets() {
        let recommendation = recommendation(
            action: .merge,
            primaryAssetPath: "/tmp/primary.md",
            relatedAssetPaths: ["/tmp/duplicate-a.md", "/tmp/duplicate-b.md"]
        )

        XCTAssertEqual(recommendation.automaticApplyAssetPaths, ["/tmp/duplicate-a.md", "/tmp/duplicate-b.md"])
    }

    private func recommendation(
        action: OrganizationAction,
        primaryAssetPath: String = "/tmp/test.md",
        relatedAssetPaths: [String] = []
    ) -> OrganizationRecommendation {
        OrganizationRecommendation(
            action: action,
            title: action.rawValue,
            reason: "Test",
            primaryAssetPath: primaryAssetPath,
            relatedAssetPaths: relatedAssetPaths,
            confidence: 0.8
        )
    }
}
