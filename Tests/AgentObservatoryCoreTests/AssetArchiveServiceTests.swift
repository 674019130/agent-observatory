import XCTest
@testable import AgentObservatoryCore

final class AssetArchiveServiceTests: XCTestCase {
    private var tempDirectory: URL!

    override func setUpWithError() throws {
        tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("AgentObservatoryArchiveTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        if let tempDirectory {
            try? FileManager.default.removeItem(at: tempDirectory)
        }
        tempDirectory = nil
    }

    func testArchiveMovesFileOutOfOriginalLocationAndReturnsManifestEntry() throws {
        let source = tempDirectory.appendingPathComponent(".claude/commands/build.md")
        try write("Build command", to: source)
        let archiveRoot = tempDirectory.appendingPathComponent("archive", isDirectory: true)
        let asset = makeAsset(path: source.path, title: "build", contentHash: "hash-build")

        let archived = try AssetArchiveService(archiveRoot: archiveRoot)
            .archive(asset: asset, reason: "Old command")

        XCTAssertFalse(FileManager.default.fileExists(atPath: source.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: archived.archivedPath))
        XCTAssertEqual(archived.originalPath, source.path)
        XCTAssertEqual(archived.owner, .claude)
        XCTAssertEqual(archived.kind, .command)
        XCTAssertEqual(archived.title, "build")
        XCTAssertEqual(archived.contentHash, "hash-build")
        XCTAssertEqual(archived.reason, "Old command")
        XCTAssertTrue(archived.archivedPath.hasPrefix(archiveRoot.path))
    }

    func testRestoreMovesArchivedFileBackToOriginalLocation() throws {
        let source = tempDirectory.appendingPathComponent(".codex/memories/MEMORY.md")
        try write("Memory", to: source)
        let archiveRoot = tempDirectory.appendingPathComponent("archive", isDirectory: true)
        let asset = makeAsset(path: source.path, owner: .codex, kind: .memory, title: "MEMORY", contentHash: "hash-memory")
        let service = AssetArchiveService(archiveRoot: archiveRoot)
        let archived = try service.archive(asset: asset, reason: "Consolidated")

        try service.restore(archived)

        XCTAssertTrue(FileManager.default.fileExists(atPath: source.path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: archived.archivedPath))
        XCTAssertEqual(try String(contentsOf: source), "Memory")
    }

    func testRestoreDoesNotOverwriteExistingOriginalPath() throws {
        let source = tempDirectory.appendingPathComponent(".agents/skills/demo/SKILL.md")
        try write("Skill v1", to: source)
        let archiveRoot = tempDirectory.appendingPathComponent("archive", isDirectory: true)
        let asset = makeAsset(path: source.path, owner: .agents, kind: .skill, title: "demo", contentHash: "hash-skill")
        let service = AssetArchiveService(archiveRoot: archiveRoot)
        let archived = try service.archive(asset: asset, reason: "Duplicate")
        try write("Skill v2", to: source)

        XCTAssertThrowsError(try service.restore(archived)) { error in
            guard case AssetArchiveError.restoreConflict(let path) = error else {
                return XCTFail("Expected restore conflict, got \(error)")
            }
            XCTAssertEqual(path, source.path)
        }
        XCTAssertTrue(FileManager.default.fileExists(atPath: archived.archivedPath))
        XCTAssertEqual(try String(contentsOf: source), "Skill v2")
    }

    private func makeAsset(
        path: String,
        owner: AgentOwner = .claude,
        kind: AssetKind = .command,
        title: String,
        contentHash: String
    ) -> AgentAsset {
        AgentAsset(
            path: path,
            owner: owner,
            kind: kind,
            scope: "test",
            title: title,
            summary: "Test asset",
            contentHash: contentHash,
            preview: "Test asset"
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
