import XCTest
@testable import AgentObservatoryCore

final class OrganizerAdvancedContentStateTests: XCTestCase {
    func testAdvancedDetailsAreHiddenBeforeAnyOrganizerOutputExists() {
        let state = OrganizerAdvancedContentState(
            isBuildingCleanupReview: false,
            cleanupGroupCount: 0,
            recommendationCount: 0,
            organizationAssetCount: 0,
            hasBuiltOrganizationMap: false
        )

        XCTAssertFalse(state.isVisible)
    }

    func testAdvancedDetailsAppearForReviewPlanOrMapOutput() {
        XCTAssertTrue(OrganizerAdvancedContentState(
            isBuildingCleanupReview: true,
            cleanupGroupCount: 0,
            recommendationCount: 0,
            organizationAssetCount: 0,
            hasBuiltOrganizationMap: false
        ).isVisible)

        XCTAssertTrue(OrganizerAdvancedContentState(
            isBuildingCleanupReview: false,
            cleanupGroupCount: 1,
            recommendationCount: 0,
            organizationAssetCount: 0,
            hasBuiltOrganizationMap: false
        ).isVisible)

        XCTAssertTrue(OrganizerAdvancedContentState(
            isBuildingCleanupReview: false,
            cleanupGroupCount: 0,
            recommendationCount: 1,
            organizationAssetCount: 0,
            hasBuiltOrganizationMap: false
        ).isVisible)

        XCTAssertTrue(OrganizerAdvancedContentState(
            isBuildingCleanupReview: false,
            cleanupGroupCount: 0,
            recommendationCount: 0,
            organizationAssetCount: 1,
            hasBuiltOrganizationMap: true
        ).isVisible)
    }
}
