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

    func testDetectsCommonSecretContentBeyondOpenAIKeys() {
        let text = """
        github_pat_abcdefghijklmnopqrstuvwxyz1234567890ABCDEFG
        AKIAIOSFODNN7EXAMPLE
        -----BEGIN PRIVATE KEY-----
        abcdefghijklmnopqrstuvwxyz
        -----END PRIVATE KEY-----
        """

        XCTAssertTrue(SecretRedactor.containsSecret(text))

        let redacted = SecretRedactor.redact(text)
        XCTAssertFalse(redacted.contains("github_pat_abcdefghijklmnopqrstuvwxyz"))
        XCTAssertFalse(redacted.contains("AKIAIOSFODNN7EXAMPLE"))
        XCTAssertFalse(redacted.contains("BEGIN PRIVATE KEY"))
    }

    func testAuditMessagesDoNotPersistSecretsOrLocalPaths() {
        let message = "Failed for /Users/susu/.codex/auth.json with token=secret-value"

        let safe = SecretRedactor.auditSafe(message)

        XCTAssertFalse(safe.contains("/Users/susu"))
        XCTAssertFalse(safe.contains("secret-value"))
        XCTAssertTrue(safe.contains("[PATH]"))
        XCTAssertTrue(safe.contains("[REDACTED]"))
    }
}
