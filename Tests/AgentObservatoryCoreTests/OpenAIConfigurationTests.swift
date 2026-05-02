import XCTest
@testable import AgentObservatoryCore

final class OpenAIConfigurationTests: XCTestCase {
    func testDefaultModelUsesLatestRecommendedFrontierModel() {
        XCTAssertEqual(OpenAIConfiguration.defaultModel, "gpt-5.5")
        XCTAssertEqual(OpenAIConfiguration.normalizedModel("  "), "gpt-5.5")
    }

    func testStoredLegacyDefaultModelsMigrateToCurrentDefault() {
        XCTAssertEqual(OpenAIConfiguration.normalizedStoredModel("gpt-4.1"), "gpt-5.5")
        XCTAssertEqual(OpenAIConfiguration.normalizedStoredModel("gpt-4.1-mini"), "gpt-5.5")
    }

    func testModelPresetsExposeFrontierMiniAndNanoChoices() {
        XCTAssertEqual(OpenAIModelPreset.allCases.map(\.modelID), [
            "gpt-5.5",
            "gpt-5.4-mini",
            "gpt-5.4-nano"
        ])
    }

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
