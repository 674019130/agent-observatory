import XCTest
@testable import AgentObservatoryCore

final class SummaryCacheTests: XCTestCase {
    private var tempDirectory: URL!

    override func setUpWithError() throws {
        tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("AgentObservatorySummaryCache-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        if let tempDirectory {
            try? FileManager.default.removeItem(at: tempDirectory)
        }
        tempDirectory = nil
    }

    func testPersistsAndReloadsSummariesByContentHash() throws {
        let cacheURL = tempDirectory.appendingPathComponent("summaries.json")
        let cache = SummaryCache(url: cacheURL)

        try cache.save(summary: "Explains a local build skill.", forContentHash: "abc123")

        let reloaded = SummaryCache(url: cacheURL)
        XCTAssertEqual(try reloaded.loadSummaries(), ["abc123": "Explains a local build skill."])
    }
}
