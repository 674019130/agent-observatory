import XCTest
@testable import AgentObservatoryCore

final class FinderRevealTargetTests: XCTestCase {
    private var tempDirectory: URL!

    override func setUpWithError() throws {
        tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("AgentObservatoryFinderReveal-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        if let tempDirectory {
            try? FileManager.default.removeItem(at: tempDirectory)
        }
        tempDirectory = nil
    }

    func testExistingFileSelectsTheFileItself() throws {
        let file = tempDirectory.appendingPathComponent("memory.md")
        try "content".write(to: file, atomically: true, encoding: .utf8)

        let target = FinderRevealTarget.selectingURL(for: file.path)

        XCTAssertEqual(target.path, file.standardizedFileURL.path)
    }

    func testMissingFileSelectsExistingParentDirectory() throws {
        let file = tempDirectory.appendingPathComponent("missing.md")

        let target = FinderRevealTarget.selectingURL(for: file.path)

        XCTAssertEqual(target.path, tempDirectory.standardizedFileURL.path)
    }

    func testMissingNestedPathFallsBackToNearestExistingAncestor() throws {
        let nested = tempDirectory
            .appendingPathComponent("gone", isDirectory: true)
            .appendingPathComponent("deeper", isDirectory: true)
            .appendingPathComponent("missing.md")

        let target = FinderRevealTarget.selectingURL(for: nested.path)

        XCTAssertEqual(target.path, tempDirectory.standardizedFileURL.path)
    }
}
