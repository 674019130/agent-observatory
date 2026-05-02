import XCTest
@testable import AgentObservatoryCore

final class AssetManagementStateTests: XCTestCase {
    func testVisibleAssetsExcludeHiddenAndArchivedOriginalPaths() {
        let hidden = makeAsset(path: "/tmp/hidden.md", title: "hidden")
        let archived = makeAsset(path: "/tmp/archived.md", title: "archived")
        let visible = makeAsset(path: "/tmp/visible.md", title: "visible")

        var state = AssetManagementState()
        state.hide(path: hidden.path)
        state.addArchive(
            ArchivedAsset(
                originalPath: archived.path,
                archivedPath: "/tmp/archive/archived.md",
                owner: archived.owner,
                kind: archived.kind,
                title: archived.title,
                contentHash: archived.contentHash,
                reason: "Duplicate"
            )
        )

        XCTAssertEqual(state.visibleAssets(from: [hidden, archived, visible]).map(\.path), [visible.path])
    }

    func testArchiveEntriesAreReplacedByIDAndRemovedAfterRestore() {
        let first = ArchivedAsset(
            id: "same-id",
            originalPath: "/tmp/first.md",
            archivedPath: "/tmp/archive/first.md",
            owner: .claude,
            kind: .command,
            title: "first",
            contentHash: "first",
            reason: "First"
        )
        let replacement = ArchivedAsset(
            id: "same-id",
            originalPath: "/tmp/replacement.md",
            archivedPath: "/tmp/archive/replacement.md",
            owner: .codex,
            kind: .memory,
            title: "replacement",
            contentHash: "replacement",
            reason: "Replacement"
        )

        var state = AssetManagementState()
        state.addArchive(first)
        state.addArchive(replacement)
        XCTAssertEqual(state.archivedAssets, [replacement])

        state.removeArchive(id: "same-id")
        XCTAssertTrue(state.archivedAssets.isEmpty)
    }

    func testUnhideAllClearsHiddenPaths() {
        var state = AssetManagementState(hiddenAssetPaths: ["/tmp/a.md", "/tmp/b.md"])

        state.unhideAll()

        XCTAssertTrue(state.hiddenAssetPaths.isEmpty)
    }

    func testHiddenAssetsCanBeListedWithoutClearingHiddenPaths() {
        let hidden = makeAsset(path: "/tmp/hidden.md", title: "hidden")
        let visible = makeAsset(path: "/tmp/visible.md", title: "visible")
        let state = AssetManagementState(hiddenAssetPaths: [hidden.path])

        let hiddenAssets = state.hiddenAssets(from: [hidden, visible])

        XCTAssertEqual(hiddenAssets.map(\.path), [hidden.path])
        XCTAssertEqual(state.hiddenAssetPaths, [hidden.path])
    }

    func testUnhideRemovesOnlyOneHiddenPath() {
        var state = AssetManagementState(hiddenAssetPaths: ["/tmp/a.md", "/tmp/b.md"])

        state.unhide(path: "/tmp/a.md")

        XCTAssertEqual(state.hiddenAssetPaths, ["/tmp/b.md"])
    }

    private func makeAsset(path: String, title: String) -> AgentAsset {
        AgentAsset(
            path: path,
            owner: .claude,
            kind: .command,
            scope: "test",
            title: title,
            summary: "Test asset",
            contentHash: title,
            preview: "Test asset"
        )
    }
}
