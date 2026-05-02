import XCTest
@testable import AgentObservatoryCore

final class OrganizationDetailSelectionTests: XCTestCase {
    func testRecommendationSelectionClearsBucketSelection() {
        var selection = OrganizationDetailSelection()

        selection.selectBucket(id: "Shared Agents-Skill")
        selection.selectRecommendation(id: "Merge-/tmp/a-Skill")

        XCTAssertEqual(selection.recommendationID, "Merge-/tmp/a-Skill")
        XCTAssertNil(selection.bucketID)
        XCTAssertEqual(selection.kind, .recommendation)
    }

    func testBucketSelectionClearsRecommendationSelection() {
        var selection = OrganizationDetailSelection()

        selection.selectRecommendation(id: "Review-/tmp/a-Path")
        selection.selectBucket(id: "Codex-Command")

        XCTAssertEqual(selection.bucketID, "Codex-Command")
        XCTAssertNil(selection.recommendationID)
        XCTAssertEqual(selection.kind, .bucket)
    }
}
