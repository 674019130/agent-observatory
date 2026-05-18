import XCTest
@testable import AgentObservatoryCore

final class MemoryMigrationPlannerTests: XCTestCase {
    private var tempDirectory: URL!

    override func setUpWithError() throws {
        tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("AgentObservatoryMemoryMigrationTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        if let tempDirectory {
            try? FileManager.default.removeItem(at: tempDirectory)
        }
        tempDirectory = nil
    }

    func testGroupsExposeClaudeCodexPresence() {
        let items = [
            item(
                title: "Favorite Tools",
                owner: .claude,
                path: "/Users/susu/.claude/projects/-Users-susu/memory/favorite_tools.md"
            ),
            item(
                title: "Favorite Tools",
                owner: .codex,
                path: "/Users/susu/.codex/memories/extensions/agent_observatory/claude/-Users-susu/favorite_tools.md"
            ),
            item(
                title: "Codex Only",
                owner: .codex,
                path: "/Users/susu/.codex/memories/raw_memories.md"
            )
        ]

        let groups = MemoryMigrationPlanner().groups(items: items)

        XCTAssertEqual(groups.first { $0.title == "Favorite Tools" }?.status, .bothSides)
        XCTAssertEqual(groups.first { $0.title == "Codex Only" }?.status, .codexOnly)
        XCTAssertNotNil(groups.first { $0.title == "Codex Only" }?.migratableCodexItem)
    }

    func testMigratesClaudeMemoryIntoCodexExtensionFolder() throws {
        let source = tempDirectory
            .appendingPathComponent(".claude/projects/-Users-susu/memory/favorite_tools.md")
        try write("# Favorite Tools\nUseful tools.", to: source)
        let asset = memoryAsset(
            title: "Favorite Tools",
            owner: .claude,
            path: source.path
        )

        let result = try MemoryMigrationPlanner(fileManager: .default).migrate(
            asset: asset,
            target: .codex,
            projectDirectory: tempDirectory.appendingPathComponent("Project"),
            homeDirectory: tempDirectory
        )

        XCTAssertEqual(
            result.plan.destinationPath,
            tempDirectory
                .appendingPathComponent(".codex/memories/extensions/agent_observatory/claude/-Users-susu/favorite_tools.md")
                .path
        )
        XCTAssertEqual(try String(contentsOfFile: result.plan.destinationPath), "# Favorite Tools\nUseful tools.")
    }

    func testMigratesCodexMemoryIntoCurrentClaudeProjectMemoryFolder() throws {
        let source = tempDirectory.appendingPathComponent(".codex/memories/raw_memories.md")
        try write("# Raw Memories\nCompiled memory.", to: source)
        let asset = memoryAsset(
            title: "Raw Memories",
            owner: .codex,
            path: source.path
        )

        let result = try MemoryMigrationPlanner(fileManager: .default).migrate(
            asset: asset,
            target: .claude,
            projectDirectory: URL(fileURLWithPath: "/Users/susu/Documents/New project"),
            homeDirectory: tempDirectory
        )

        XCTAssertEqual(
            result.plan.destinationPath,
            tempDirectory
                .appendingPathComponent(".claude/projects/-Users-susu-Documents-New-project/memory/codex/raw_memories.md")
                .path
        )
        XCTAssertEqual(try String(contentsOfFile: result.plan.destinationPath), "# Raw Memories\nCompiled memory.")
    }

    func testMigrationDoesNotOverwriteExistingDestination() throws {
        let source = tempDirectory.appendingPathComponent(".codex/memories/raw_memories.md")
        try write("# Raw Memories\nCompiled memory.", to: source)
        let destination = tempDirectory
            .appendingPathComponent(".claude/projects/-Users-susu-Documents-New-project/memory/codex/raw_memories.md")
        try write("existing", to: destination)
        let asset = memoryAsset(
            title: "Raw Memories",
            owner: .codex,
            path: source.path
        )

        XCTAssertThrowsError(
            try MemoryMigrationPlanner(fileManager: .default).migrate(
                asset: asset,
                target: .claude,
                projectDirectory: URL(fileURLWithPath: "/Users/susu/Documents/New project"),
                homeDirectory: tempDirectory
            )
        ) { error in
            XCTAssertEqual(error as? MemoryMigrationError, .destinationExists(destination.path))
        }
    }

    func testPlanMarksExistingDestinationBeforeCopy() throws {
        let source = tempDirectory.appendingPathComponent(".codex/memories/raw_memories.md")
        try write("# Raw Memories\nCompiled memory.", to: source)
        let destination = tempDirectory
            .appendingPathComponent(".claude/projects/-Users-susu-Documents-New-project/memory/codex/raw_memories.md")
        try write("existing", to: destination)
        let asset = memoryAsset(
            title: "Raw Memories",
            owner: .codex,
            path: source.path
        )

        let plan = try MemoryMigrationPlanner(fileManager: .default).plan(
            for: asset,
            target: .claude,
            projectDirectory: URL(fileURLWithPath: "/Users/susu/Documents/New project"),
            homeDirectory: tempDirectory
        )

        XCTAssertEqual(plan.destinationPath, destination.path)
        XCTAssertTrue(plan.destinationExists)
    }

    func testFindsOriginalClaudeMemoryForImportedCodexCopy() {
        let imported = memoryAsset(
            title: "Imported Summary",
            owner: .codex,
            path: "/Users/susu/.codex/memories/extensions/agent_observatory/claude/-Users-susu/memory_summary.md"
        )
        let original = item(
            title: "Original Summary",
            owner: .claude,
            path: "/Users/susu/.claude/projects/-Users-susu/memory/memory_summary.md"
        )
        let unrelated = item(
            title: "Memory Summary",
            owner: .claude,
            path: "/Users/susu/.claude/projects/-Other/memory/memory_summary.md"
        )

        let match = MemoryMigrationPlanner().existingTargetMemory(
            for: imported,
            target: .claude,
            in: [unrelated, original],
            plannedDestinationPath: nil
        )

        XCTAssertEqual(match?.asset.path, original.asset.path)
    }

    private func item(
        title: String,
        owner: AgentOwner,
        path: String
    ) -> ContextCatalogItem {
        let asset = memoryAsset(title: title, owner: owner, path: path)
        let route = ContextLoadAnalyzer().route(for: asset)
        return ContextCatalogItem(
            asset: asset,
            role: .memory,
            layer: route.layer,
            memoryType: route.memoryType,
            surfaces: route.surfaces,
            loadRoute: route
        )
    }

    private func memoryAsset(
        title: String,
        owner: AgentOwner,
        path: String
    ) -> AgentAsset {
        AgentAsset(
            path: path,
            owner: owner,
            kind: .memory,
            scope: "global",
            title: title,
            summary: "Memory for \(title).",
            contentHash: StableHash.hash(path),
            preview: "# \(title)"
        )
    }

    private func write(_ text: String, to url: URL) throws {
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try Data(text.utf8).write(to: url)
    }
}
