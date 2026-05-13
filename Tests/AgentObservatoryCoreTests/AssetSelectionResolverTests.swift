import XCTest
@testable import AgentObservatoryCore

final class AssetSelectionResolverTests: XCTestCase {
    func testContextBrowserSelectionCanResolveOutsideAssetTableFilters() {
        let tableFallback = asset(title: "Dashboard", path: "/Users/susu/.codex/AGENTS.md")
        let selectedMemory = asset(title: "Memory", path: "/Users/susu/.codex/memories/MEMORY.md")

        let resolved = AssetSelectionResolver().selectedAsset(
            selectedAssetID: selectedMemory.id,
            visibleAssets: [tableFallback, selectedMemory],
            filteredAssets: [tableFallback],
            surface: .contextBrowser
        )

        XCTAssertEqual(resolved, selectedMemory)
    }

    func testAssetTableSelectionStaysConstrainedToFilteredRows() {
        let tableFallback = asset(title: "Dashboard", path: "/Users/susu/.codex/AGENTS.md")
        let hiddenByTableFilters = asset(title: "Memory", path: "/Users/susu/.codex/memories/MEMORY.md")

        let resolved = AssetSelectionResolver().selectedAsset(
            selectedAssetID: hiddenByTableFilters.id,
            visibleAssets: [tableFallback, hiddenByTableFilters],
            filteredAssets: [tableFallback],
            surface: .assetTable
        )

        XCTAssertEqual(resolved, tableFallback)
    }

    func testContextBrowserSelectionWorksWhenAssetTableFiltersAreEmpty() {
        let selectedMemory = asset(title: "Memory", path: "/Users/susu/.codex/memories/MEMORY.md")

        let resolved = AssetSelectionResolver().selectedAsset(
            selectedAssetID: selectedMemory.id,
            visibleAssets: [selectedMemory],
            filteredAssets: [],
            surface: .contextBrowser
        )

        XCTAssertEqual(resolved, selectedMemory)
    }

    func testMissingSelectionFallsBackToFirstFilteredAsset() {
        let tableFallback = asset(title: "Dashboard", path: "/Users/susu/.codex/AGENTS.md")

        let resolved = AssetSelectionResolver().selectedAsset(
            selectedAssetID: UUID(),
            visibleAssets: [tableFallback],
            filteredAssets: [tableFallback],
            surface: .contextBrowser
        )

        XCTAssertEqual(resolved, tableFallback)
    }

    private func asset(title: String, path: String) -> AgentAsset {
        AgentAsset(
            path: path,
            owner: .codex,
            kind: .memory,
            scope: "global",
            title: title,
            summary: "Summary for \(title)",
            contentHash: title,
            preview: ""
        )
    }
}
