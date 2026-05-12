import XCTest
@testable import AgentObservatoryCore

final class OrganizerBriefExporterTests: XCTestCase {
    func testExportsReadableChineseBriefWithCountsFocusAndRoute() {
        let asset = AgentAsset(
            path: "/tmp/.codex/commands/build.md",
            owner: .codex,
            kind: .command,
            scope: "test",
            title: "build",
            summary: "Build command",
            contentHash: StableHash.hash("build"),
            preview: "Build command",
            statusFlags: [.duplicate]
        )
        let map = OrganizationAnalyzer().map(assets: [asset], aiSummaries: [:], language: .simplifiedChinese)
        let brief = OrganizerAdvisor().brief(map: map, assets: [asset], language: .simplifiedChinese)

        let markdown = OrganizerBriefExporter().markdown(
            brief: brief,
            map: map,
            language: .simplifiedChinese
        )

        XCTAssertTrue(markdown.contains("# Agent 配置简报"))
        XCTAssertTrue(markdown.contains("资产总数：1"))
        XCTAssertTrue(markdown.contains("推荐路径：合并重复项"))
        XCTAssertTrue(markdown.contains("优先关注"))
    }

    func testExportsReadableEnglishBrief() {
        let brief = OrganizerBrief(
            headline: "3 agent assets across 2 organization buckets.",
            summary: "Start with Risks.",
            landscape: ["Ownership: Codex 3."],
            focusAreas: ["Review sensitive files."],
            recommendedGoal: .riskCleanup
        )
        let map = OrganizationMap(
            totalAssets: 3,
            buckets: [],
            audienceCounts: [:],
            kindCounts: [:],
            ownerCounts: [.codex: 3],
            statusCounts: [.secretRisk: 1]
        )

        let markdown = OrganizerBriefExporter().markdown(brief: brief, map: map)

        XCTAssertTrue(markdown.contains("# Agent Configuration Brief"))
        XCTAssertTrue(markdown.contains("Total assets: 3"))
        XCTAssertTrue(markdown.contains("Recommended route: Risks"))
        XCTAssertTrue(markdown.contains("Review sensitive files."))
    }
}
