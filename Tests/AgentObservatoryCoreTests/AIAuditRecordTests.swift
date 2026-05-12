import XCTest
@testable import AgentObservatoryCore

final class AIAuditRecordTests: XCTestCase {
    func testAuditLogKeepsNewestRecordsFirstAndCapsHistory() {
        var log = AIAuditLog()

        for index in 0..<65 {
            log.add(
                AIAuditRecord(
                    operation: .organizationPlan,
                    status: .succeeded,
                    model: "gpt-test",
                    baseURL: "https://example.com/v1",
                    assetCount: index,
                    message: "ok-\(index)"
                )
            )
        }

        XCTAssertEqual(log.records.count, 50)
        XCTAssertEqual(log.records.first?.assetCount, 64)
        XCTAssertEqual(log.records.last?.assetCount, 15)
    }

    func testAuditRecordDoesNotStoreSensitivePayloadText() {
        let record = AIAuditRecord(
            operation: .assetExplanation,
            status: .failed,
            model: "gpt-test",
            baseURL: "https://example.com/v1",
            assetCount: 1,
            message: "HTTP 400"
        )

        XCTAssertEqual(record.operation, .assetExplanation)
        XCTAssertEqual(record.status, .failed)
        XCTAssertEqual(record.message, "HTTP 400")
    }
}
