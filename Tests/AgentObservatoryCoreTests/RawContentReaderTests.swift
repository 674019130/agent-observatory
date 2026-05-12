import XCTest
@testable import AgentObservatoryCore

final class RawContentReaderTests: XCTestCase {
    private var tempDirectory: URL!

    override func setUpWithError() throws {
        tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("AgentObservatoryRawContent-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        if let tempDirectory {
            try? FileManager.default.removeItem(at: tempDirectory)
        }
        tempDirectory = nil
    }

    func testReadsFullFileWithoutPreviewTruncation() throws {
        let url = tempDirectory.appendingPathComponent("long-memory.md")
        let body = String(repeating: "0123456789abcdef\n", count: 20_000)
        try Data(body.utf8).write(to: url)

        let result = RawContentReader().read(path: url.path)

        XCTAssertEqual(result.text, body)
        XCTAssertFalse(result.isSensitive)
        XCTAssertFalse(result.isUnreadable)
    }

    func testSensitivePathIsNotRead() throws {
        let url = tempDirectory.appendingPathComponent("auth.json")
        try Data("{\"token\":\"secret\"}".utf8).write(to: url)

        let result = RawContentReader().read(path: url.path)

        XCTAssertTrue(result.isSensitive)
        XCTAssertFalse(result.isRedactedPreview)
        XCTAssertFalse(result.text.contains("secret"))
    }

    func testSensitivePathCanOnlyShowExplicitCappedRedactedLocalPreview() throws {
        let url = tempDirectory.appendingPathComponent("auth.json")
        try Data("{\"token\":\"secret-value\",\"public\":\"visible\"}".utf8).write(to: url)

        let result = RawContentReader(maxSensitivePreviewBytes: 64).read(
            path: url.path,
            allowSensitivePreview: true
        )

        XCTAssertTrue(result.isSensitive)
        XCTAssertTrue(result.isRedactedPreview)
        XCTAssertTrue(result.text.contains("visible"))
        XCTAssertFalse(result.text.contains("secret-value"))
        XCTAssertTrue(result.text.contains("[REDACTED]"))
    }

    func testRedactsSecretsInFullContent() throws {
        let url = tempDirectory.appendingPathComponent("settings.json")
        try Data("{\"api_key\":\"sk-abcdefghijklmnopqrstuvwxyz123456\"}".utf8).write(to: url)

        let result = RawContentReader().read(path: url.path)

        XCTAssertFalse(result.text.contains("abcdefghijklmnopqrstuvwxyz123456"))
        XCTAssertTrue(result.text.contains("[REDACTED]"))
    }

    func testLargeFileRequiresExplicitFullLoad() throws {
        let url = tempDirectory.appendingPathComponent("large.md")
        try Data(String(repeating: "x", count: 64).utf8).write(to: url)

        let result = RawContentReader(maxAutomaticReadBytes: 16).read(path: url.path)

        XCTAssertTrue(result.isTooLarge)
        XCTAssertFalse(result.isUnreadable)
        XCTAssertFalse(result.text.contains(String(repeating: "x", count: 64)))

        let explicitResult = RawContentReader(maxAutomaticReadBytes: 16).read(path: url.path, allowLargeFile: true)
        XCTAssertFalse(explicitResult.isTooLarge)
        XCTAssertEqual(explicitResult.text, String(repeating: "x", count: 64))
    }

    func testExplicitLargeLoadStillHasInlineRenderingCap() throws {
        let url = tempDirectory.appendingPathComponent("huge.md")
        let body = String(repeating: "x", count: 64)
        try Data(body.utf8).write(to: url)

        let result = RawContentReader(
            maxAutomaticReadBytes: 16,
            maxExplicitReadBytes: 32
        )
        .read(path: url.path, allowLargeFile: true)

        XCTAssertTrue(result.isTooLarge)
        XCTAssertFalse(result.isUnreadable)
        XCTAssertFalse(result.text.contains(body))
        XCTAssertTrue(result.text.contains("too large to render safely"))
    }

    func testReaderMessagesCanRenderInChinese() throws {
        let sensitiveURL = tempDirectory.appendingPathComponent("auth.json")
        try Data("{\"token\":\"secret\"}".utf8).write(to: sensitiveURL)

        let sensitiveResult = RawContentReader().read(path: sensitiveURL.path, language: .simplifiedChinese)

        XCTAssertTrue(sensitiveResult.text.contains("敏感文件"))

        let largeURL = tempDirectory.appendingPathComponent("large.md")
        try Data(String(repeating: "x", count: 64).utf8).write(to: largeURL)

        let largeResult = RawContentReader(maxAutomaticReadBytes: 16).read(path: largeURL.path, language: .simplifiedChinese)

        XCTAssertTrue(largeResult.text.contains("文件大小"))
        XCTAssertTrue(largeResult.text.contains("加载全文"))
    }
}
