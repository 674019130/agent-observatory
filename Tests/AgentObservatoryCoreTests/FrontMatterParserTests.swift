import XCTest
@testable import AgentObservatoryCore

final class FrontMatterParserTests: XCTestCase {
    func testParsesOnlyTopLevelYamlFrontMatter() {
        let document = """
        ---
        name: build-mcp-server
        description: Build an MCP server.
        ---
        # Body
        name: example-inside-body
        """

        let parsed = FrontMatterParser.parse(document)

        XCTAssertEqual(parsed.frontMatter["name"], "build-mcp-server")
        XCTAssertEqual(parsed.frontMatter["description"], "Build an MCP server.")
        XCTAssertTrue(parsed.body.contains("name: example-inside-body"))
    }

    func testReturnsPlainBodyWhenNoFrontMatterExists() {
        let parsed = FrontMatterParser.parse("# Plain Markdown")

        XCTAssertTrue(parsed.frontMatter.isEmpty)
        XCTAssertEqual(parsed.body, "# Plain Markdown")
    }
}
