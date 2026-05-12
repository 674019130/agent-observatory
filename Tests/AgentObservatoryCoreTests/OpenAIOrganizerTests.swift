import Foundation
import XCTest
@testable import AgentObservatoryCore

final class OpenAIOrganizerTests: XCTestCase {
    override func tearDown() {
        URLProtocolStub.requestHandler = nil
        super.tearDown()
    }

    func testOrganizerRequestsStructuredJSONOutput() async throws {
        let asset = testAsset()
        var capturedBody: [String: Any] = [:]
        URLProtocolStub.requestHandler = { request in
            let body = try XCTUnwrap(Self.bodyData(from: request))
            capturedBody = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: Any])
            let response = HTTPURLResponse(
                url: try XCTUnwrap(request.url),
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            )!
            let data = Data(#"{"output":[{"content":[{"text":"{\"recommendations\":[]}"}]}]}"#.utf8)
            return (response, data)
        }

        _ = try await organizer().organize(
            map: OrganizationAnalyzer().map(assets: [asset], aiSummaries: [:]),
            assets: [asset],
            apiKey: "test-key",
            model: "test-model",
            baseURL: "https://example.com/v1"
        )

        let text = try XCTUnwrap(capturedBody["text"] as? [String: Any])
        let format = try XCTUnwrap(text["format"] as? [String: Any])
        XCTAssertEqual(format["type"] as? String, "json_schema")
        XCTAssertEqual(format["name"] as? String, "organization_plan")
        XCTAssertEqual(format["strict"] as? Bool, true)
        XCTAssertEqual(capturedBody["max_output_tokens"] as? Int, 6_000)
        XCTAssertTrue((capturedBody["instructions"] as? String)?.contains("Return at most 12 recommendations") ?? false)
    }

    func testOrganizerExcludesUnsafeAssetsFromOpenAIPayload() async throws {
        let safe = testAsset()
        let unsafe = testAsset(
            path: "/tmp/.codex/auth.json",
            preview: "OPENAI_API_KEY=sk-abcdefghijklmnopqrstuvwxyz123456",
            statusFlags: [.secretRisk]
        )
        var capturedInput = ""
        URLProtocolStub.requestHandler = { request in
            let body = try XCTUnwrap(Self.bodyData(from: request))
            let payload = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: Any])
            capturedInput = try XCTUnwrap(payload["input"] as? String)
            let response = HTTPURLResponse(
                url: try XCTUnwrap(request.url),
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            )!
            let data = Data(#"{"output":[{"content":[{"text":"{\"recommendations\":[]}"}]}]}"#.utf8)
            return (response, data)
        }

        _ = try await organizer().organize(
            map: OrganizationAnalyzer().map(assets: [safe, unsafe], aiSummaries: [:]),
            assets: [safe, unsafe],
            apiKey: "test-key",
            model: "test-model",
            baseURL: "https://example.com/v1"
        )

        XCTAssertTrue(capturedInput.contains(safe.path))
        XCTAssertFalse(capturedInput.contains(unsafe.path))
        XCTAssertFalse(capturedInput.contains("abcdefghijklmnopqrstuvwxyz123456"))
    }

    func testOrganizerParseErrorIncludesModelOutputExcerpt() async throws {
        let asset = testAsset()
        URLProtocolStub.requestHandler = { request in
            let response = HTTPURLResponse(
                url: try XCTUnwrap(request.url),
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            )!
            let data = Data(#"{"output":[{"content":[{"text":"I cannot safely produce JSON for this request."}]}]}"#.utf8)
            return (response, data)
        }

        do {
            _ = try await organizer().organize(
                map: OrganizationAnalyzer().map(assets: [asset], aiSummaries: [:]),
                assets: [asset],
                apiKey: "test-key",
                model: "test-model",
                baseURL: "https://example.com/v1"
            )
            XCTFail("Expected organizer parse failure")
        } catch {
            let message = error.localizedDescription
            XCTAssertTrue(message.contains("AI plan could not be parsed as JSON"), message)
            XCTAssertTrue(message.contains("I cannot safely produce JSON"), message)
        }
    }

    func testOrganizerRepairsMalformedJSONOutputOnce() async throws {
        let asset = testAsset()
        var requestCount = 0
        var repairPrompt = ""
        URLProtocolStub.requestHandler = { request in
            requestCount += 1
            let body = try XCTUnwrap(Self.bodyData(from: request))
            let payload = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: Any])
            let response = HTTPURLResponse(
                url: try XCTUnwrap(request.url),
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            )!

            if requestCount == 1 {
                let data = Data(#"{"output":[{"content":[{"text":"{\"recommendations\" [\"reason\" \"bad\" \"title\":\"Keep build\" \"primaryAssetPath\":\"/tmp/.codex/skills/build/SKILL.md\", \"relatedAssetPaths\":\"/tmp/other.md\", \"confidence\":O, \"action\":\"keep\")"}]}]}"#.utf8)
                return (response, data)
            }

            repairPrompt = try XCTUnwrap(payload["input"] as? String)
            let repaired = #"{"recommendations":[{"action":"keep","title":"Keep build","reason":"Already useful.","primaryAssetPath":"/tmp/.codex/skills/build/SKILL.md","relatedAssetPaths":[],"confidence":0.91}]}"#
            let data = Data(#"{"output":[{"content":[{"text":"\#(repaired.replacingOccurrences(of: "\"", with: "\\\""))"}]}]}"#.utf8)
            return (response, data)
        }

        let plan = try await organizer().organize(
            map: OrganizationAnalyzer().map(assets: [asset], aiSummaries: [:]),
            assets: [asset],
            apiKey: "test-key",
            model: "test-model",
            baseURL: "https://example.com/v1"
        )

        XCTAssertEqual(requestCount, 2)
        XCTAssertTrue(repairPrompt.contains("Malformed model output"))
        XCTAssertEqual(plan.recommendations.count, 1)
        XCTAssertEqual(plan.recommendations.first?.title, "Keep build")
    }

    func testOrganizerAcceptsSingleRelatedAssetPathStringFromCompatibleProviders() async throws {
        let asset = testAsset()
        let related = AgentAsset(
            path: "/tmp/.codex/skills/test/SKILL.md",
            owner: .codex,
            kind: .skill,
            scope: "test",
            title: "test",
            summary: "Test helper",
            contentHash: "related-hash",
            preview: "Test helper",
            statusFlags: []
        )
        URLProtocolStub.requestHandler = { request in
            let response = HTTPURLResponse(
                url: try XCTUnwrap(request.url),
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            )!
            let data = Data(#"{"output":[{"content":[{"text":"{\"recommendations\":[{\"action\":\"review\",\"title\":\"Review build\",\"reason\":\"Check overlap.\",\"primaryAssetPath\":\"/tmp/.codex/skills/build/SKILL.md\",\"relatedAssetPaths\":\"/tmp/.codex/skills/test/SKILL.md\",\"confidence\":0.74}]}"}]}]}"#.utf8)
            return (response, data)
        }

        let plan = try await organizer().organize(
            map: OrganizationAnalyzer().map(assets: [asset, related], aiSummaries: [:]),
            assets: [asset, related],
            apiKey: "test-key",
            model: "test-model",
            baseURL: "https://example.com/v1"
        )

        XCTAssertEqual(plan.recommendations.first?.relatedAssetPaths, [related.path])
    }

    func testOrganizerRequestFailureIncludesHTTPStatusAndBodyMessage() async throws {
        let asset = testAsset()
        URLProtocolStub.requestHandler = { request in
            let response = HTTPURLResponse(
                url: try XCTUnwrap(request.url),
                statusCode: 400,
                httpVersion: nil,
                headerFields: nil
            )!
            let data = Data(#"{"error":{"message":"Unsupported model for structured output"}}"#.utf8)
            return (response, data)
        }

        do {
            _ = try await organizer().organize(
                map: OrganizationAnalyzer().map(assets: [asset], aiSummaries: [:]),
                assets: [asset],
                apiKey: "test-key",
                model: "test-model",
                baseURL: "https://example.com/v1"
            )
            XCTFail("Expected organizer request failure")
        } catch {
            let message = error.localizedDescription
            XCTAssertTrue(message.contains("HTTP 400"), message)
            XCTAssertTrue(message.contains("Unsupported model for structured output"), message)
        }
    }

    func testOrganizerReportsIncompleteResponseBeforeParsingOutput() async throws {
        let asset = testAsset()
        URLProtocolStub.requestHandler = { request in
            let response = HTTPURLResponse(
                url: try XCTUnwrap(request.url),
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            )!
            let data = Data(#"{"status":"incomplete","incomplete_details":{"reason":"max_output_tokens"},"output":[{"content":[{"text":"{\"recommendations\":["}]}]}"#.utf8)
            return (response, data)
        }

        do {
            _ = try await organizer().organize(
                map: OrganizationAnalyzer().map(assets: [asset], aiSummaries: [:]),
                assets: [asset],
                apiKey: "test-key",
                model: "test-model",
                baseURL: "https://example.com/v1"
            )
            XCTFail("Expected incomplete response error")
        } catch {
            let message = error.localizedDescription
            XCTAssertTrue(message.contains("incomplete"), message)
            XCTAssertTrue(message.contains("max_output_tokens"), message)
        }
    }

    private func organizer() -> OpenAIOrganizer {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [URLProtocolStub.self]
        return OpenAIOrganizer(session: URLSession(configuration: configuration))
    }

    private func testAsset(
        path: String = "/tmp/.codex/skills/build/SKILL.md",
        preview: String = "Build helper",
        statusFlags: [AssetStatusFlag] = []
    ) -> AgentAsset {
        AgentAsset(
            path: path,
            owner: .codex,
            kind: .skill,
            scope: "test",
            title: "build",
            summary: "Build helper",
            contentHash: "hash",
            preview: preview,
            statusFlags: statusFlags
        )
    }

    private static func bodyData(from request: URLRequest) throws -> Data? {
        if let httpBody = request.httpBody {
            return httpBody
        }
        guard let stream = request.httpBodyStream else { return nil }

        stream.open()
        defer { stream.close() }

        var data = Data()
        var buffer = [UInt8](repeating: 0, count: 4_096)
        while stream.hasBytesAvailable {
            let readCount = stream.read(&buffer, maxLength: buffer.count)
            if readCount > 0 {
                data.append(buffer, count: readCount)
            } else if readCount < 0 {
                throw stream.streamError ?? URLError(.cannotDecodeContentData)
            } else {
                break
            }
        }
        return data
    }
}

private final class URLProtocolStub: URLProtocol {
    static var requestHandler: ((URLRequest) throws -> (HTTPURLResponse, Data))?

    override class func canInit(with request: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        guard let handler = Self.requestHandler else {
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
            return
        }

        do {
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}
