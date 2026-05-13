import XCTest
@testable import AgentObservatoryCore

final class ScanSourceEventFilterTests: XCTestCase {
    func testFileSourcesOnlyMarkExactSourceFileEventsAsRelevant() {
        let project = URL(fileURLWithPath: "/tmp/project")
        let source = ScanSource(
            id: "project-agents",
            owner: .project,
            label: "Project AGENTS",
            path: project.appendingPathComponent("AGENTS.md").path,
            scope: "project",
            maxDepth: 0
        )

        let relevant = ScanSourceEventFilter.relevantEventPaths(
            [
                project.appendingPathComponent("README.md").path,
                project.appendingPathComponent(".build/debug.yaml").path,
                project.appendingPathComponent("AGENTS.md").path
            ],
            sources: [source]
        )

        XCTAssertEqual(relevant, [project.appendingPathComponent("AGENTS.md").path])
    }

    func testDirectorySourcesIgnoreSkippedBuildArtifactsAndKeepIndexedCandidates() {
        let projectCodex = URL(fileURLWithPath: "/tmp/project/.codex")
        let source = ScanSource(
            id: "project-codex",
            owner: .project,
            label: "Project Codex",
            path: projectCodex.path,
            scope: "project",
            maxDepth: 4
        )

        let relevant = ScanSourceEventFilter.relevantEventPaths(
            [
                "/tmp/project/.build/debug.yaml",
                "/tmp/project/dist/AgentObservatory.app/Contents/Info.plist",
                projectCodex.appendingPathComponent("environments/environment.toml").path
            ],
            sources: [source]
        )

        XCTAssertEqual(relevant, [projectCodex.appendingPathComponent("environments/environment.toml").path])
    }

    func testWorkspaceMemorySourceMatchesMarkdownAndTextLikeScanner() {
        let workspace = URL(fileURLWithPath: "/tmp/workspace-memory")
        let source = ScanSource(
            id: "workspace-memory",
            owner: .project,
            label: "Workspace Memory",
            path: workspace.path,
            scope: "workspace-memory",
            maxDepth: 8,
            isCustom: true
        )

        let markdown = workspace.appendingPathComponent("team/context.md").path
        let text = workspace.appendingPathComponent("team/context.txt").path
        let json = workspace.appendingPathComponent("team/context.json").path

        let relevant = ScanSourceEventFilter.relevantEventPaths(
            [markdown, text, json],
            sources: [source]
        )

        XCTAssertEqual(relevant, [markdown, text])
    }
}
