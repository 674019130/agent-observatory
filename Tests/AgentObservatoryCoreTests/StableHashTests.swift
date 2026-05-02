import XCTest
@testable import AgentObservatoryCore

final class StableHashTests: XCTestCase {
    func testHashIsStableForSameInput() {
        XCTAssertEqual(StableHash.hash("build-mcp-server"), StableHash.hash("build-mcp-server"))
    }

    func testHashChangesForDifferentInput() {
        XCTAssertNotEqual(StableHash.hash("claude"), StableHash.hash("codex"))
    }
}
