import XCTest
@testable import AgentObservatoryCore

final class SecretRedactorTests: XCTestCase {
    func testRedactsOpenAIStyleKey() {
        let text = "OPENAI_API_KEY=sk-abcdefghijklmnopqrstuvwxyz123456"
        let redacted = SecretRedactor.redact(text)

        XCTAssertFalse(redacted.contains("abcdefghijklmnopqrstuvwxyz"))
        XCTAssertTrue(redacted.contains("[REDACTED]"))
    }

    func testAuthJsonIsSensitive() {
        XCTAssertTrue(SecretRedactor.isSensitivePath("/Users/susu/.codex/auth.json"))
    }
}
