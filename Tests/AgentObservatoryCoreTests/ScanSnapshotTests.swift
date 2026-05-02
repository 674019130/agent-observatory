import XCTest
@testable import AgentObservatoryCore

final class ScanSnapshotTests: XCTestCase {
    func testDiffReportsAddedRemovedAndChangedAssets() {
        let previous = ScanSnapshot(assets: [
            asset(path: "/old.md", title: "old", hash: "old-hash"),
            asset(path: "/changed.md", title: "changed", hash: "before")
        ])
        let current = ScanSnapshot(assets: [
            asset(path: "/changed.md", title: "changed", hash: "after"),
            asset(path: "/new.md", title: "new", hash: "new-hash")
        ])

        let diff = ScanSnapshot.diff(from: previous, to: current)

        XCTAssertEqual(diff.added.map(\.path), ["/new.md"])
        XCTAssertEqual(diff.removed.map(\.path), ["/old.md"])
        XCTAssertEqual(diff.changed.map(\.path), ["/changed.md"])
        XCTAssertFalse(diff.isEmpty)
    }

    private func asset(path: String, title: String, hash: String) -> AgentAsset {
        AgentAsset(
            path: path,
            owner: .codex,
            kind: .memory,
            scope: "global",
            title: title,
            summary: title,
            contentHash: hash,
            preview: title
        )
    }
}
