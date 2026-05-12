import XCTest
@testable import AgentObservatoryCore

final class OrganizerRunExporterTests: XCTestCase {
    func testExportsChineseDiagnosisForCurrentRun() {
        let run = OrganizerRun(
            status: .ready,
            title: "整理诊断",
            summary: "当前索引里有重复插件和低信号会话。",
            totalAssetCount: 12,
            duplicateAssetCount: 4,
            noiseAssetCount: 2,
            sensitiveAssetCount: 1,
            stalePathAssetCount: 0,
            unclearAssetCount: 3,
            actionPacks: [
                OrganizerActionPack(
                    id: "merge",
                    kind: .mergeDuplicates,
                    title: "合并重复插件",
                    summary: "保留主入口，归档重复副本。",
                    risk: .low,
                    assetPaths: ["/tmp/a.md", "/tmp/b.md"],
                    executableAssetPaths: ["/tmp/b.md"],
                    isReversible: true,
                    requiresHumanReview: false
                )
            ]
        )

        let markdown = OrganizerRunExporter().markdown(run: run, language: .simplifiedChinese)

        XCTAssertTrue(markdown.contains("# 整理诊断"))
        XCTAssertTrue(markdown.contains("资产总数：12"))
        XCTAssertTrue(markdown.contains("重复项：4"))
        XCTAssertTrue(markdown.contains("## 建议动作"))
        XCTAssertTrue(markdown.contains("合并重复插件"))
        XCTAssertTrue(markdown.contains("低风险"))
        XCTAssertFalse(markdown.contains("/tmp/a.md"))
    }

    func testExportsEnglishEmptyRun() {
        let markdown = OrganizerRunExporter().markdown(run: .empty, language: .english)

        XCTAssertTrue(markdown.contains("# Organizer Diagnosis"))
        XCTAssertTrue(markdown.contains("No automatic action packs."))
    }
}
