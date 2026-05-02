import XCTest
@testable import AgentObservatoryCore

final class OrganizationMapBuildPlannerTests: XCTestCase {
    func testBuildMapScansWhenIndexIsEmpty() {
        let decision = OrganizationMapBuildPlanner().decision(
            assetCount: 0,
            isIndexStale: false,
            isScanning: false
        )

        XCTAssertEqual(decision, .scanThenBuild)
    }

    func testBuildMapScansWhenIndexIsStale() {
        let decision = OrganizationMapBuildPlanner().decision(
            assetCount: 12,
            isIndexStale: true,
            isScanning: false
        )

        XCTAssertEqual(decision, .scanThenBuild)
    }

    func testBuildMapWaitsForActiveScan() {
        let decision = OrganizationMapBuildPlanner().decision(
            assetCount: 12,
            isIndexStale: false,
            isScanning: true
        )

        XCTAssertEqual(decision, .waitForScan)
    }

    func testBuildMapUsesCurrentIndexWhenFresh() {
        let decision = OrganizationMapBuildPlanner().decision(
            assetCount: 12,
            isIndexStale: false,
            isScanning: false
        )

        XCTAssertEqual(decision, .buildCurrentIndex)
    }
}
