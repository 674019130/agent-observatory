import XCTest
@testable import AgentObservatoryCore

final class CleanupExecutionPreviewTests: XCTestCase {
    func testPreviewCountsHideArchiveAndMergeActions() {
        let session = CleanupReviewSession(
            goal: .fullReview,
            groups: [
                CleanupReviewGroup(
                    id: "noise",
                    title: "Hide noise",
                    summary: "Hide low signal files",
                    action: .hide,
                    risk: .low,
                    confidence: 0.7,
                    assetPaths: ["/tmp/session.jsonl", "/tmp/tmp.txt"],
                    evidence: []
                ),
                CleanupReviewGroup(
                    id: "merge",
                    title: "Merge build",
                    summary: "Merge duplicate build commands",
                    action: .merge,
                    risk: .medium,
                    confidence: 0.8,
                    assetPaths: ["/tmp/primary.md", "/tmp/duplicate.md"],
                    evidence: []
                ),
                CleanupReviewGroup(
                    id: "review",
                    title: "Review auth",
                    summary: "Review sensitive file",
                    action: .review,
                    risk: .high,
                    confidence: 0.9,
                    assetPaths: ["/tmp/auth.json"],
                    evidence: []
                )
            ],
            totalAssets: 5
        )

        let preview = CleanupExecutionPreview(session: session)

        XCTAssertEqual(preview.goal, .fullReview)
        XCTAssertEqual(preview.groupCount, 3)
        XCTAssertEqual(preview.affectedAssetCount, 5)
        XCTAssertEqual(preview.executableGroupCount, 2)
        XCTAssertEqual(preview.executableAssetCount, 3)
        XCTAssertEqual(preview.hideCount, 2)
        XCTAssertEqual(preview.mergeArchiveCount, 1)
        XCTAssertEqual(preview.archiveCount, 0)
        XCTAssertEqual(preview.manualGroupCount, 1)
        XCTAssertTrue(preview.hasExecutableActions)
    }

    func testPreviewReportsManualOnlySessions() {
        let session = CleanupReviewSession(
            goal: .riskCleanup,
            groups: [
                CleanupReviewGroup(
                    id: "risk",
                    title: "Review sensitive files",
                    summary: "No automatic action",
                    action: .review,
                    risk: .high,
                    confidence: 0.9,
                    assetPaths: ["/tmp/auth.json"],
                    evidence: []
                )
            ],
            totalAssets: 1
        )

        let preview = CleanupExecutionPreview(session: session)

        XCTAssertEqual(preview.executableGroupCount, 0)
        XCTAssertEqual(preview.executableAssetCount, 0)
        XCTAssertEqual(preview.manualGroupCount, 1)
        XCTAssertFalse(preview.hasExecutableActions)
    }
}
