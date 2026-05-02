import XCTest
@testable import AgentObservatoryCore

final class AssetImpactAnalyzerTests: XCTestCase {
    func testFindsOutgoingTargetsMissingReferencesAndIncomingReferences() {
        let command = AgentAsset(
            path: "/Users/susu/.claude/commands/build.md",
            owner: .claude,
            kind: .command,
            scope: "global",
            title: "build",
            summary: "Runs build skill.",
            dependencies: [
                "~/.agents/skills/build/SKILL.md",
                "~/.claude/scripts/missing.sh"
            ],
            contentHash: "command",
            preview: "Run ~/.agents/skills/build/SKILL.md and ~/.claude/scripts/missing.sh"
        )
        let skill = AgentAsset(
            path: "/Users/susu/.agents/skills/build/SKILL.md",
            owner: .agents,
            kind: .skill,
            scope: "global",
            title: "build",
            summary: "Builds tools.",
            contentHash: "skill",
            preview: "Builds tools."
        )

        let impact = AssetImpactAnalyzer().impact(for: skill, in: [command, skill])

        XCTAssertEqual(impact.incomingReferences.map(\.sourcePath), [command.path])
        XCTAssertTrue(impact.outgoingReferences.isEmpty)

        let commandImpact = AssetImpactAnalyzer().impact(for: command, in: [command, skill])
        XCTAssertEqual(commandImpact.outgoingReferences.count, 2)
        XCTAssertTrue(commandImpact.outgoingReferences.contains { $0.targetPath == skill.path && !$0.isMissing })
        XCTAssertTrue(commandImpact.outgoingReferences.contains { $0.reference == "~/.claude/scripts/missing.sh" && $0.isMissing && $0.isStaleReference })
    }

    func testReferenceIndexResolvesOutgoingAndIncomingLinksWithoutRescanningAssets() {
        let command = AgentAsset(
            path: "/Users/susu/.claude/commands/build.md",
            owner: .claude,
            kind: .command,
            scope: "global",
            title: "build",
            summary: "Runs build skill.",
            dependencies: ["~/.agents/skills/build/SKILL.md"],
            contentHash: "command",
            preview: "Run ~/.agents/skills/build/SKILL.md"
        )
        let skill = AgentAsset(
            path: "/Users/susu/.agents/skills/build/SKILL.md",
            owner: .agents,
            kind: .skill,
            scope: "global",
            title: "build",
            summary: "Builds tools.",
            contentHash: "skill",
            preview: "Builds tools."
        )
        let index = AssetReferenceIndex(assets: [command, skill])

        let skillImpact = AssetImpactAnalyzer(index: index).impact(for: skill)
        let commandImpact = AssetImpactAnalyzer(index: index).impact(for: command)

        XCTAssertEqual(skillImpact.incomingReferences.map(\.sourcePath), [command.path])
        XCTAssertEqual(commandImpact.outgoingReferences.first?.targetPath, skill.path)
    }
}
