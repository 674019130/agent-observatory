import XCTest
@testable import AgentObservatoryCore

final class FileSystemAssetScannerTests: XCTestCase {
    private var tempDirectory: URL!

    override func setUpWithError() throws {
        tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("AgentObservatoryTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        if let tempDirectory {
            try? FileManager.default.removeItem(at: tempDirectory)
        }
        tempDirectory = nil
    }

    func testScansCommandsSkillsScriptsAndSensitiveConfig() throws {
        let claudeCommand = tempDirectory
            .appendingPathComponent(".claude/commands/build-mcp-server.md")
        let agentSkill = tempDirectory
            .appendingPathComponent(".agents/skills/build-mcp-server/SKILL.md")
        let agentScript = tempDirectory
            .appendingPathComponent(".agents/skills/build-mcp-server/scripts/run.sh")
        let codexAuth = tempDirectory
            .appendingPathComponent(".codex/auth.json")

        try write("Builds an MCP server command.", to: claudeCommand)
        try write("""
        ---
        name: build-mcp-server
        description: Build MCP servers from local templates.
        ---
        Run scripts/run.sh
        """, to: agentSkill)
        try write("#!/usr/bin/env bash\necho ok\n", to: agentScript)
        try write("{\"token\":\"secret-value\"}", to: codexAuth)

        let scanner = FileSystemAssetScanner()
        let assets = scanner.scan(roots: [
            ScanRoot(owner: .claude, label: "Claude", url: tempDirectory.appendingPathComponent(".claude"), scope: "test"),
            ScanRoot(owner: .agents, label: "Agents", url: tempDirectory.appendingPathComponent(".agents"), scope: "test"),
            ScanRoot(owner: .codex, label: "Codex", url: tempDirectory.appendingPathComponent(".codex"), scope: "test")
        ])

        let command = try XCTUnwrap(assets.first { $0.kind == .command })
        let skill = try XCTUnwrap(assets.first { $0.kind == .skill })
        let auth = try XCTUnwrap(assets.first { $0.path.hasSuffix("auth.json") })

        XCTAssertEqual(command.trigger, "/build-mcp-server")
        XCTAssertTrue(skill.statusFlags.contains(.duplicate))
        XCTAssertTrue(command.statusFlags.contains(.duplicate))
        XCTAssertTrue(skill.statusFlags.contains(.hasScripts))
        XCTAssertTrue(auth.statusFlags.contains(.secretRisk))
        XCTAssertFalse(auth.preview.contains("secret-value"))
    }

    func testDefaultRootsUseSpecificWhitelistedLocations() {
        let scanner = FileSystemAssetScanner()
        let home = URL(fileURLWithPath: "/Users/susu")
        let project = URL(fileURLWithPath: "/Users/susu/Documents/New project")

        let roots = scanner.defaultRoots(homeDirectory: home, projectDirectory: project)
        let paths = Set(roots.map(\.url.path))

        XCTAssertFalse(paths.contains("/Users/susu/.claude"))
        XCTAssertFalse(paths.contains("/Users/susu/.codex"))
        XCTAssertFalse(paths.contains("/Users/susu/.agents"))
        XCTAssertTrue(paths.contains("/Users/susu/.claude/commands"))
        XCTAssertTrue(paths.contains("/Users/susu/.codex/memories"))
        XCTAssertTrue(paths.contains("/Users/susu/.agents/skills"))
        XCTAssertTrue(paths.contains("/Users/susu/Documents/New project/AGENTS.md"))
    }

    func testReportsScanProgress() throws {
        let claudeCommand = tempDirectory
            .appendingPathComponent(".claude/commands/progress.md")
        try write("Progress command", to: claudeCommand)

        var progressEvents: [ScanProgress] = []
        let scanner = FileSystemAssetScanner()
        let assets = scanner.scan(
            roots: [
                ScanRoot(owner: .claude, label: "Claude Commands", url: tempDirectory.appendingPathComponent(".claude/commands"), scope: "test")
            ],
            progress: { progressEvents.append($0) }
        )

        XCTAssertEqual(assets.count, 1)
        XCTAssertTrue(progressEvents.contains { $0.phase == .collecting })
        XCTAssertTrue(progressEvents.contains { $0.phase == .processing })
        XCTAssertEqual(progressEvents.last?.phase, .completed)
        XCTAssertEqual(progressEvents.last?.assetsFound, 1)
    }

    func testScansOnlyEnabledSources() throws {
        let enabledCommand = tempDirectory
            .appendingPathComponent(".claude/commands/enabled.md")
        let disabledCommand = tempDirectory
            .appendingPathComponent(".codex/commands/disabled.md")

        try write("Enabled command", to: enabledCommand)
        try write("Disabled command", to: disabledCommand)

        let scanner = FileSystemAssetScanner()
        let assets = scanner.scan(sources: [
            ScanSource(
                id: "enabled",
                owner: .claude,
                label: "Enabled",
                path: tempDirectory.appendingPathComponent(".claude/commands").path,
                scope: "test",
                maxDepth: 2,
                isEnabled: true
            ),
            ScanSource(
                id: "disabled",
                owner: .codex,
                label: "Disabled",
                path: tempDirectory.appendingPathComponent(".codex/commands").path,
                scope: "test",
                maxDepth: 2,
                isEnabled: false
            )
        ])

        XCTAssertEqual(assets.map(\.title), ["enabled"])
    }

    func testScannerBeginsProcessingBeforeCollectingEveryCandidate() throws {
        let commandsDirectory = tempDirectory.appendingPathComponent(".claude/commands")
        for index in 0..<40 {
            let url = commandsDirectory.appendingPathComponent("command-\(index).md")
            try write("Command \(index)", to: url)
        }

        var firstProcessingFilesVisited: Int?
        _ = FileSystemAssetScanner().scan(
            roots: [
                ScanRoot(owner: .claude, label: "Claude Commands", url: commandsDirectory, scope: "test")
            ],
            progress: { progress in
                if progress.phase == .processing && firstProcessingFilesVisited == nil {
                    firstProcessingFilesVisited = progress.filesVisited
                }
            }
        )

        XCTAssertNotNil(firstProcessingFilesVisited)
        XCTAssertLessThan(firstProcessingFilesVisited ?? 40, 40)
    }

    private func write(_ text: String, to url: URL) throws {
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try Data(text.utf8).write(to: url)
    }
}
