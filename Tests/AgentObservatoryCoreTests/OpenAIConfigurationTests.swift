import XCTest
@testable import AgentObservatoryCore

final class OpenAIConfigurationTests: XCTestCase {
    func testResponsesEndpointUsesDefaultBaseURLWhenBlank() throws {
        let endpoint = try OpenAIConfiguration.responsesEndpoint(baseURL: "  ")

        XCTAssertEqual(endpoint.absoluteString, "https://api.openai.com/v1/responses")
    }

    func testResponsesEndpointNormalizesTrailingSlash() throws {
        let endpoint = try OpenAIConfiguration.responsesEndpoint(baseURL: "https://api.openai.com/v1/")

        XCTAssertEqual(endpoint.absoluteString, "https://api.openai.com/v1/responses")
    }

    func testResponsesEndpointAcceptsAlreadySpecificEndpoint() throws {
        let endpoint = try OpenAIConfiguration.responsesEndpoint(baseURL: "https://api.openai.com/v1/responses")

        XCTAssertEqual(endpoint.absoluteString, "https://api.openai.com/v1/responses")
    }

    func testResponsesEndpointAddsVersionForOpenAIHostOnly() throws {
        let endpoint = try OpenAIConfiguration.responsesEndpoint(baseURL: "https://api.openai.com")

        XCTAssertEqual(endpoint.absoluteString, "https://api.openai.com/v1/responses")
    }
}
