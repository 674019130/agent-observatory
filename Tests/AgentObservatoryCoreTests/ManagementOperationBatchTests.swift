import XCTest
@testable import AgentObservatoryCore

final class ManagementOperationBatchTests: XCTestCase {
    func testBatchCountsAppliedFailedAndUndoableOperations() {
        let archived = ArchivedAsset(
            id: "archive-1",
            originalPath: "/tmp/old.md",
            archivedPath: "/tmp/archive/old.md",
            owner: .codex,
            kind: .skill,
            title: "old",
            contentHash: "hash",
            reason: "Duplicate"
        )
        let batch = ManagementOperationBatch(
            id: "batch-1",
            title: "Recommended Cleanup",
            source: .cleanupReview,
            records: [
                ManagementOperationRecord(
                    id: "hide-1",
                    kind: .hide,
                    status: .applied,
                    originalPath: "/tmp/noise.jsonl",
                    title: "noise",
                    archivedAsset: nil,
                    message: "Hidden"
                ),
                ManagementOperationRecord(
                    id: "archive-1",
                    kind: .mergeArchive,
                    status: .applied,
                    originalPath: archived.originalPath,
                    title: archived.title,
                    archivedAsset: archived,
                    message: "Archived duplicate"
                ),
                ManagementOperationRecord(
                    id: "failed-1",
                    kind: .archive,
                    status: .failed,
                    originalPath: "/tmp/missing.md",
                    title: "missing",
                    archivedAsset: nil,
                    message: "Source missing"
                )
            ]
        )

        XCTAssertEqual(batch.appliedCount, 2)
        XCTAssertEqual(batch.failedCount, 1)
        XCTAssertEqual(batch.undoableCount, 2)
        XCTAssertFalse(batch.isFullyUndone)
    }

    func testOlderManagementStateJSONDecodesWithEmptyBatches() throws {
        let data = """
        {
          "hiddenAssetPaths": ["/tmp/hidden.md"],
          "archivedAssets": []
        }
        """.data(using: .utf8)!

        let state = try JSONDecoder().decode(AssetManagementState.self, from: data)

        XCTAssertEqual(state.hiddenAssetPaths, ["/tmp/hidden.md"])
        XCTAssertTrue(state.archivedAssets.isEmpty)
        XCTAssertTrue(state.operationBatches.isEmpty)
    }

    func testManagementStateCanReplaceUpdatedBatch() {
        let applied = ManagementOperationRecord(
            id: "hide-1",
            kind: .hide,
            status: .applied,
            originalPath: "/tmp/noise.jsonl",
            title: "noise",
            archivedAsset: nil,
            message: "Hidden"
        )
        var state = AssetManagementState()
        state.addOperationBatch(
            ManagementOperationBatch(
                id: "batch-1",
                title: "Recommended Cleanup",
                source: .cleanupReview,
                records: [applied]
            )
        )

        var updated = state.operationBatches[0]
        updated.markRecord(id: "hide-1", status: .undone, message: "Unhidden")
        state.replaceOperationBatch(updated)

        XCTAssertEqual(state.operationBatches[0].undoneCount, 1)
        XCTAssertTrue(state.operationBatches[0].isFullyUndone)
    }
}
