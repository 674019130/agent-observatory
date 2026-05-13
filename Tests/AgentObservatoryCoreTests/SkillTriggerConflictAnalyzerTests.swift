import XCTest
@testable import AgentObservatoryCore

final class SkillTriggerConflictAnalyzerTests: XCTestCase {
    func testDetectsUserSkillOverlappingBundledSkill() throws {
        let userSkill = asset(
            path: "/Users/susu/.agents/skills/macos-design-guidelines/SKILL.md",
            owner: .agents,
            title: "SwiftUI Patterns",
            summary: "Use when creating or refactoring native macOS SwiftUI scenes and components.",
            trigger: "Use when creating or refactoring macOS SwiftUI UI."
        )
        let bundledSkill = asset(
            path: "/Users/susu/.codex/plugins/cache/openai-curated/build-macos-apps/123/skills/swiftui-patterns/SKILL.md",
            owner: .codex,
            title: "SwiftUI Patterns",
            summary: "Best practices for building native macOS SwiftUI scenes and components.",
            trigger: "Use when creating or refactoring macOS SwiftUI UI."
        )

        let conflicts = SkillTriggerConflictAnalyzer().conflicts(assets: [userSkill, bundledSkill])

        XCTAssertEqual(conflicts.count, 1)
        let conflict = try XCTUnwrap(conflicts.first)
        XCTAssertEqual(conflict.severity, .high)
        XCTAssertTrue(conflict.signals.contains(.userSkillOverlapsBundled))
        XCTAssertTrue(conflict.signals.contains(.sharedRuntimeSurface))
    }

    func testIgnoresSkillsThatDoNotShareRuntimeSurface() {
        let claudeOnly = asset(
            path: "/Users/susu/.claude/skills/review/SKILL.md",
            owner: .claude,
            title: "Code Review",
            summary: "Use when reviewing code for correctness.",
            trigger: "Use when reviewing code."
        )
        let codexOnly = asset(
            path: "/Users/susu/.codex/skills/testing/SKILL.md",
            owner: .codex,
            title: "Code Review",
            summary: "Use when reviewing code for correctness.",
            trigger: "Use when reviewing code."
        )

        let conflicts = SkillTriggerConflictAnalyzer().conflicts(assets: [claudeOnly, codexOnly])

        XCTAssertTrue(conflicts.isEmpty)
    }

    func testIgnoresUnrelatedSkills() {
        let design = asset(
            path: "/Users/susu/.agents/skills/design/SKILL.md",
            owner: .agents,
            title: "Interface Design",
            summary: "Use when designing app layouts and navigation.",
            trigger: "Use when designing product UI."
        )
        let calendar = asset(
            path: "/Users/susu/.agents/skills/calendar/SKILL.md",
            owner: .agents,
            title: "Calendar Planning",
            summary: "Use when scheduling meetings and finding free time.",
            trigger: "Use when managing calendar events."
        )

        let conflicts = SkillTriggerConflictAnalyzer().conflicts(assets: [design, calendar])

        XCTAssertTrue(conflicts.isEmpty)
    }

    func testPromptExporterIncludesBasicConflictInfoForOtherAgents() throws {
        let userSkill = asset(
            path: "/Users/susu/.agents/skills/swiftui-patterns/SKILL.md",
            owner: .agents,
            title: "SwiftUI Patterns",
            summary: "Use when creating or refactoring native macOS SwiftUI scenes and components.",
            trigger: "Use when creating or refactoring macOS SwiftUI UI."
        )
        let bundledSkill = asset(
            path: "/Users/susu/.codex/plugins/cache/openai-curated/build-macos-apps/123/skills/swiftui-patterns/SKILL.md",
            owner: .codex,
            title: "SwiftUI Patterns",
            summary: "Best practices for building native macOS SwiftUI scenes and components.",
            trigger: "Use when creating or refactoring macOS SwiftUI UI."
        )
        let conflict = try XCTUnwrap(SkillTriggerConflictAnalyzer().conflicts(assets: [userSkill, bundledSkill]).first)

        let prompt = SkillTriggerConflictPromptExporter().prompt(for: conflict, language: .simplifiedChinese)

        XCTAssertTrue(prompt.contains("Skill 触发冲突"))
        XCTAssertTrue(prompt.contains(userSkill.path))
        XCTAssertTrue(prompt.contains(bundledSkill.path))
        XCTAssertTrue(prompt.contains("风险等级"))
        XCTAssertTrue(prompt.contains("重叠词"))
        XCTAssertTrue(prompt.contains("不要直接删除文件"))
        XCTAssertTrue(prompt.contains("处理结果输出格式"))
        XCTAssertTrue(prompt.contains("## 结论"))
        XCTAssertTrue(prompt.contains("## 文件处理明细"))
        XCTAssertTrue(prompt.contains("## 验证"))
        XCTAssertTrue(prompt.contains("## 剩余人工决策"))
        XCTAssertTrue(prompt.contains("## 风险与回滚"))
    }

    func testPromptExporterRequiresEnglishOutputFormatForOtherAgents() throws {
        let userSkill = asset(
            path: "/Users/susu/.agents/skills/swiftui-patterns/SKILL.md",
            owner: .agents,
            title: "SwiftUI Patterns",
            summary: "Use when creating or refactoring native macOS SwiftUI scenes and components.",
            trigger: "Use when creating or refactoring macOS SwiftUI UI."
        )
        let bundledSkill = asset(
            path: "/Users/susu/.codex/plugins/cache/openai-curated/build-macos-apps/123/skills/swiftui-patterns/SKILL.md",
            owner: .codex,
            title: "SwiftUI Patterns",
            summary: "Best practices for building native macOS SwiftUI scenes and components.",
            trigger: "Use when creating or refactoring macOS SwiftUI UI."
        )
        let conflict = try XCTUnwrap(SkillTriggerConflictAnalyzer().conflicts(assets: [userSkill, bundledSkill]).first)

        let prompt = SkillTriggerConflictPromptExporter().prompt(for: conflict, language: .english)

        XCTAssertTrue(prompt.contains("Required output format"))
        XCTAssertTrue(prompt.contains("## Conclusion"))
        XCTAssertTrue(prompt.contains("## File Handling Details"))
        XCTAssertTrue(prompt.contains("## Verification"))
        XCTAssertTrue(prompt.contains("## Remaining Human Decisions"))
        XCTAssertTrue(prompt.contains("## Risks and Rollback"))
    }

    func testContractComparisonSummarizesWhySkillsCompete() throws {
        let userSkill = asset(
            path: "/Users/susu/.agents/skills/macos-design-guidelines/SKILL.md",
            owner: .agents,
            title: "macOS Design Guidelines",
            summary: "Apple Human Interface Guidelines for native macOS SwiftUI UI design and review.",
            trigger: "Use when design review build native macOS SwiftUI UI."
        )
        let bundledSkill = asset(
            path: "/Users/susu/.codex/plugins/cache/openai-curated/build-macos-apps/123/skills/swiftui-patterns/SKILL.md",
            owner: .codex,
            title: "SwiftUI Patterns",
            summary: "Best practices for building native macOS SwiftUI scenes and components.",
            trigger: "Use when creating or refactoring native macOS SwiftUI UI."
        )
        let conflict = try XCTUnwrap(SkillTriggerConflictAnalyzer().conflicts(assets: [userSkill, bundledSkill]).first)

        let comparison = SkillTriggerContractComparator().comparison(
            for: conflict,
            language: .simplifiedChinese
        )

        XCTAssertTrue(comparison.headline.contains("同一类请求"))
        XCTAssertEqual(comparison.sections.map(\.kind), [.trigger, .responsibility, .loading])
        XCTAssertTrue(comparison.sections[0].sharedTerms.contains("swiftui"))
        XCTAssertTrue(comparison.sections[0].primaryText.contains("design"))
        XCTAssertTrue(comparison.sections[1].takeaway.contains("职责"))
        XCTAssertTrue(comparison.sections[2].takeaway.contains("Codex"))
        XCTAssertTrue(comparison.recommendedAction.contains("收窄"))
    }

    private func asset(
        path: String,
        owner: AgentOwner,
        title: String,
        summary: String,
        trigger: String
    ) -> AgentAsset {
        AgentAsset(
            path: path,
            owner: owner,
            kind: .skill,
            scope: "global",
            title: title,
            summary: summary,
            trigger: trigger,
            contentHash: path,
            preview: [summary, trigger].joined(separator: "\n")
        )
    }
}
