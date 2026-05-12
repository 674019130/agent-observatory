import Foundation
import XCTest
@testable import AgentObservatoryCore

final class OpenAIEnricherTests: XCTestCase {
    override func tearDown() {
        EnricherURLProtocolStub.requestHandler = nil
        super.tearDown()
    }

    func testSummarizeCanRequestEnglishOutput() async throws {
        var capturedInstructions = ""
        EnricherURLProtocolStub.requestHandler = { request in
            let body = try XCTUnwrap(Self.bodyData(from: request))
            let payload = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: Any])
            capturedInstructions = try XCTUnwrap(payload["instructions"] as? String)
            let response = HTTPURLResponse(
                url: try XCTUnwrap(request.url),
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            )!
            return (response, Data(#"{"output":[{"content":[{"text":"Purpose: test"}]}]}"#.utf8))
        }

        _ = try await enricher().summarize(
            asset: testAsset(),
            apiKey: "test-key",
            model: "test-model",
            baseURL: "https://example.com/v1",
            language: .english
        )

        XCTAssertTrue(capturedInstructions.contains("Return English prose"), capturedInstructions)
    }

    func testSummarizeCanRequestChineseOutput() async throws {
        var capturedInstructions = ""
        EnricherURLProtocolStub.requestHandler = { request in
            let body = try XCTUnwrap(Self.bodyData(from: request))
            let payload = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: Any])
            capturedInstructions = try XCTUnwrap(payload["instructions"] as? String)
            let response = HTTPURLResponse(
                url: try XCTUnwrap(request.url),
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            )!
            return (response, Data(#"{"output":[{"content":[{"text":"用途: 测试"}]}]}"#.utf8))
        }

        _ = try await enricher().summarize(
            asset: testAsset(),
            apiKey: "test-key",
            model: "test-model",
            baseURL: "https://example.com/v1",
            language: .simplifiedChinese
        )

        XCTAssertTrue(capturedInstructions.contains("Return Chinese prose"), capturedInstructions)
    }

    func testSummarizeRejectsUnsafeAssetsBeforeNetworkRequest() async throws {
        var didCallNetwork = false
        EnricherURLProtocolStub.requestHandler = { request in
            didCallNetwork = true
            let response = HTTPURLResponse(
                url: try XCTUnwrap(request.url),
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            )!
            return (response, Data(#"{"output_text":"Purpose: unsafe"}"#.utf8))
        }

        do {
            _ = try await enricher().summarize(
                asset: testAsset(
                    preview: "OPENAI_API_KEY=sk-abcdefghijklmnopqrstuvwxyz123456",
                    statusFlags: []
                ),
                apiKey: "test-key",
                model: "test-model",
                baseURL: "https://example.com/v1"
            )
            XCTFail("Expected unsafe asset rejection")
        } catch {
            XCTAssertFalse(didCallNetwork)
            XCTAssertTrue(error.localizedDescription.contains("unsafe for AI"), error.localizedDescription)
            XCTAssertFalse(error.localizedDescription.contains("abcdefghijklmnopqrstuvwxyz123456"))
        }
    }

    private func enricher() -> OpenAIEnricher {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [EnricherURLProtocolStub.self]
        return OpenAIEnricher(session: URLSession(configuration: configuration))
    }

    private func testAsset(
        preview: String = "Build helper",
        statusFlags: [AssetStatusFlag] = []
    ) -> AgentAsset {
        AgentAsset(
            path: "/tmp/.codex/skills/build/SKILL.md",
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

private final class EnricherURLProtocolStub: URLProtocol {
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
