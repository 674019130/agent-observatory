import Foundation

public enum MemoryMigrationSide: String, CaseIterable, Codable, Identifiable, Sendable {
    case claude
    case codex

    public var id: String { rawValue }

    public init?(owner: AgentOwner) {
        switch owner {
        case .claude:
            self = .claude
        case .codex:
            self = .codex
        case .agents, .project, .unknown:
            return nil
        }
    }

    public var owner: AgentOwner {
        switch self {
        case .claude:
            return .claude
        case .codex:
            return .codex
        }
    }
}

public enum MemoryPresenceStatus: String, CaseIterable, Codable, Sendable {
    case claudeOnly
    case codexOnly
    case bothSides
    case sharedOnly
    case unknown

    public var sortIndex: Int {
        switch self {
        case .claudeOnly: 0
        case .codexOnly: 1
        case .bothSides: 2
        case .sharedOnly: 3
        case .unknown: 4
        }
    }
}

public struct MemoryPresenceGroup: Identifiable, Codable, Hashable, Sendable {
    public let id: String
    public let title: String
    public let memoryType: AgentMemoryType?
    public let status: MemoryPresenceStatus
    public let items: [ContextCatalogItem]
    public let claudeItems: [ContextCatalogItem]
    public let codexItems: [ContextCatalogItem]
    public let sharedItems: [ContextCatalogItem]

    public init(
        id: String,
        title: String,
        memoryType: AgentMemoryType?,
        status: MemoryPresenceStatus,
        items: [ContextCatalogItem],
        claudeItems: [ContextCatalogItem],
        codexItems: [ContextCatalogItem],
        sharedItems: [ContextCatalogItem]
    ) {
        self.id = id
        self.title = title
        self.memoryType = memoryType
        self.status = status
        self.items = items
        self.claudeItems = claudeItems
        self.codexItems = codexItems
        self.sharedItems = sharedItems
    }

    public var primaryItem: ContextCatalogItem? {
        claudeItems.first ?? codexItems.first ?? sharedItems.first ?? items.first
    }

    public var migratableClaudeItem: ContextCatalogItem? {
        guard !hasCodexSurface else { return nil }
        return claudeItems.first { $0.asset.kind == .memory }
    }

    public var migratableCodexItem: ContextCatalogItem? {
        guard !hasClaudeSurface else { return nil }
        return codexItems.first { $0.asset.kind == .memory }
    }

    public var hasClaudeSurface: Bool {
        items.contains { $0.surfaces.contains(.claude) }
    }

    public var hasCodexSurface: Bool {
        items.contains { $0.surfaces.contains(.codex) }
    }
}

public struct MemoryMigrationPlan: Codable, Hashable, Sendable {
    public let sourcePath: String
    public let destinationPath: String
    public let sourceSide: MemoryMigrationSide
    public let targetSide: MemoryMigrationSide
    public let title: String
    public let destinationExists: Bool

    public init(
        sourcePath: String,
        destinationPath: String,
        sourceSide: MemoryMigrationSide,
        targetSide: MemoryMigrationSide,
        title: String,
        destinationExists: Bool = false
    ) {
        self.sourcePath = sourcePath
        self.destinationPath = destinationPath
        self.sourceSide = sourceSide
        self.targetSide = targetSide
        self.title = title
        self.destinationExists = destinationExists
    }
}

public struct MemoryMigrationResult: Codable, Hashable, Sendable {
    public let plan: MemoryMigrationPlan
    public let copiedAt: Date

    public init(plan: MemoryMigrationPlan, copiedAt: Date = Date()) {
        self.plan = plan
        self.copiedAt = copiedAt
    }
}

public enum MemoryMigrationError: LocalizedError, Equatable, Sendable {
    case unsupportedSource(String)
    case unsupportedTarget(String)
    case unsupportedKind(String)
    case sourceMissing(String)
    case destinationExists(String)
    case fileOperation(String)

    public var errorDescription: String? {
        switch self {
        case .unsupportedSource(let owner):
            return "Memory migration only supports Claude Code and Codex sources. Source was \(owner)."
        case .unsupportedTarget(let owner):
            return "Memory migration only supports Claude Code and Codex targets. Target was \(owner)."
        case .unsupportedKind(let kind):
            return "Only memory files can be migrated automatically. Asset kind was \(kind)."
        case .sourceMissing(let path):
            return "Source file does not exist: \(path)"
        case .destinationExists(let path):
            return "Destination already exists, so the migration was not applied: \(path)"
        case .fileOperation(let message):
            return message
        }
    }
}

public struct MemoryMigrationPlanner {
    private let fileManager: FileManager

    public init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    public func groups(items: [ContextCatalogItem]) -> [MemoryPresenceGroup] {
        let eligibleItems = items.filter { $0.role == .memory }
        let grouped = Dictionary(grouping: eligibleItems, by: groupKey)

        return grouped.values.map(makeGroup)
            .sorted { left, right in
                if left.status.sortIndex != right.status.sortIndex {
                    return left.status.sortIndex < right.status.sortIndex
                }
                if left.memoryType?.sortIndex != right.memoryType?.sortIndex {
                    return (left.memoryType?.sortIndex ?? Int.max) < (right.memoryType?.sortIndex ?? Int.max)
                }
                return left.title.localizedStandardCompare(right.title) == .orderedAscending
            }
    }

    public func plan(
        for asset: AgentAsset,
        target: MemoryMigrationSide,
        projectDirectory: URL,
        homeDirectory: URL = FileManager.default.homeDirectoryForCurrentUser
    ) throws -> MemoryMigrationPlan {
        guard asset.kind == .memory else {
            throw MemoryMigrationError.unsupportedKind(asset.kind.rawValue)
        }
        guard let sourceSide = MemoryMigrationSide(owner: asset.owner) else {
            throw MemoryMigrationError.unsupportedSource(asset.owner.rawValue)
        }
        guard sourceSide != target else {
            throw MemoryMigrationError.unsupportedTarget(target.owner.rawValue)
        }

        let sourceURL = URL(fileURLWithPath: asset.path)
        guard fileManager.fileExists(atPath: sourceURL.path) else {
            throw MemoryMigrationError.sourceMissing(sourceURL.path)
        }

        let destinationURL = destinationURL(
            for: sourceURL,
            sourceSide: sourceSide,
            target: target,
            projectDirectory: projectDirectory,
            homeDirectory: homeDirectory
        )

        return MemoryMigrationPlan(
            sourcePath: sourceURL.path,
            destinationPath: destinationURL.path,
            sourceSide: sourceSide,
            targetSide: target,
            title: asset.title,
            destinationExists: fileManager.fileExists(atPath: destinationURL.path)
        )
    }

    public func existingTargetMemory(
        for asset: AgentAsset,
        target: MemoryMigrationSide,
        in items: [ContextCatalogItem],
        plannedDestinationPath: String? = nil
    ) -> ContextCatalogItem? {
        guard asset.kind == .memory else { return nil }

        return items.compactMap { item -> (item: ContextCatalogItem, rank: Int)? in
            guard item.asset.id != asset.id,
                  item.asset.kind == .memory,
                  item.asset.owner == target.owner || item.surfaces.contains(target.owner),
                  let rank = targetMatchRank(
                    source: asset,
                    candidate: item.asset,
                    target: target,
                    plannedDestinationPath: plannedDestinationPath
                  ) else {
                return nil
            }

            return (item, rank)
        }
        .sorted { left, right in
            if left.rank != right.rank {
                return left.rank < right.rank
            }
            return left.item.asset.displayPath.localizedStandardCompare(right.item.asset.displayPath) == .orderedAscending
        }
        .first?.item
    }

    public func migrate(
        asset: AgentAsset,
        target: MemoryMigrationSide,
        projectDirectory: URL,
        homeDirectory: URL = FileManager.default.homeDirectoryForCurrentUser
    ) throws -> MemoryMigrationResult {
        let plan = try plan(
            for: asset,
            target: target,
            projectDirectory: projectDirectory,
            homeDirectory: homeDirectory
        )
        let sourceURL = URL(fileURLWithPath: plan.sourcePath)
        let destinationURL = URL(fileURLWithPath: plan.destinationPath)

        guard !fileManager.fileExists(atPath: destinationURL.path) else {
            throw MemoryMigrationError.destinationExists(destinationURL.path)
        }

        do {
            try fileManager.createDirectory(
                at: destinationURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            try fileManager.copyItem(at: sourceURL, to: destinationURL)
        } catch let error as MemoryMigrationError {
            throw error
        } catch {
            throw MemoryMigrationError.fileOperation("Could not copy memory file: \(error.localizedDescription)")
        }

        return MemoryMigrationResult(plan: plan)
    }

    private func groupKey(for item: ContextCatalogItem) -> String {
        let type = item.memoryType?.rawValue ?? "unknown"
        let title = normalized(item.asset.title)
        if !title.isEmpty {
            return "\(type)::title::\(title)"
        }

        let filename = normalized(URL(fileURLWithPath: item.asset.path).deletingPathExtension().lastPathComponent)
        return "\(type)::filename::\(filename)"
    }

    private func makeGroup(items: [ContextCatalogItem]) -> MemoryPresenceGroup {
        let sortedItems = items.sorted { left, right in
            if left.asset.owner.rawValue != right.asset.owner.rawValue {
                return left.asset.owner.rawValue < right.asset.owner.rawValue
            }
            return left.asset.displayPath.localizedStandardCompare(right.asset.displayPath) == .orderedAscending
        }
        let claudeItems = sortedItems.filter { $0.asset.owner == .claude }
        let codexItems = sortedItems.filter { $0.asset.owner == .codex }
        let sharedItems = sortedItems.filter { item in
            item.asset.owner == .agents
                || item.asset.owner == .project
                || (item.surfaces.contains(.claude) && item.surfaces.contains(.codex))
        }
        let hasClaudeSurface = sortedItems.contains { $0.surfaces.contains(.claude) }
        let hasCodexSurface = sortedItems.contains { $0.surfaces.contains(.codex) }
        let status: MemoryPresenceStatus
        if hasClaudeSurface && hasCodexSurface {
            status = .bothSides
        } else if hasClaudeSurface {
            status = .claudeOnly
        } else if hasCodexSurface {
            status = .codexOnly
        } else if !sharedItems.isEmpty {
            status = .sharedOnly
        } else {
            status = .unknown
        }

        let primary = claudeItems.first ?? codexItems.first ?? sharedItems.first ?? sortedItems.first
        let title = primary?.asset.title ?? "Untitled memory"
        let memoryType = primary?.memoryType
        let key = "\(memoryType?.rawValue ?? "unknown")::\(normalized(title))"

        return MemoryPresenceGroup(
            id: StableHash.hash(key),
            title: title,
            memoryType: memoryType,
            status: status,
            items: sortedItems,
            claudeItems: claudeItems,
            codexItems: codexItems,
            sharedItems: sharedItems,
        )
    }

    private func destinationURL(
        for sourceURL: URL,
        sourceSide: MemoryMigrationSide,
        target: MemoryMigrationSide,
        projectDirectory: URL,
        homeDirectory: URL
    ) -> URL {
        let filename = sanitizedFileName(sourceURL.lastPathComponent.isEmpty ? "memory.md" : sourceURL.lastPathComponent)
        switch (sourceSide, target) {
        case (.claude, .codex):
            let sourceProjectSlug = claudeProjectSlug(from: sourceURL.path) ?? "global"
            return homeDirectory
                .appendingPathComponent(".codex/memories/extensions/agent_observatory/claude", isDirectory: true)
                .appendingPathComponent(sourceProjectSlug, isDirectory: true)
                .appendingPathComponent(filename)
        case (.codex, .claude):
            let projectSlug = Self.claudeProjectSlug(forProjectPath: projectDirectory.standardizedFileURL.path)
            return homeDirectory
                .appendingPathComponent(".claude/projects", isDirectory: true)
                .appendingPathComponent(projectSlug, isDirectory: true)
                .appendingPathComponent("memory/codex", isDirectory: true)
                .appendingPathComponent(filename)
        case (.claude, .claude), (.codex, .codex):
            return sourceURL
        }
    }

    private func claudeProjectSlug(from path: String) -> String? {
        let marker = "/.claude/projects/"
        guard let markerRange = path.range(of: marker) else { return nil }
        let remainder = path[markerRange.upperBound...]
        guard let slug = remainder.split(separator: "/").first, !slug.isEmpty else { return nil }
        return String(slug)
    }

    public static func claudeProjectSlug(forProjectPath path: String) -> String {
        let pathSlug = path
            .split(separator: "/", omittingEmptySubsequences: true)
            .joined(separator: "-")
        let collapsed = pathSlug.replacingOccurrences(
            of: #"[\s_]+"#,
            with: "-",
            options: .regularExpression
        )
        return collapsed.isEmpty ? "project" : "-\(collapsed)"
    }

    private func sanitizedFileName(_ name: String) -> String {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: ".-_"))
        let scalars = name.unicodeScalars.map { scalar in
            allowed.contains(scalar) ? Character(scalar) : "-"
        }
        let value = String(scalars).trimmingCharacters(in: CharacterSet(charactersIn: ".-"))
        return value.isEmpty ? "memory.md" : value
    }

    private func normalized(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .replacingOccurrences(of: #"[\s_\-]+"#, with: "-", options: .regularExpression)
    }

    private func targetMatchRank(
        source: AgentAsset,
        candidate: AgentAsset,
        target: MemoryMigrationSide,
        plannedDestinationPath: String?
    ) -> Int? {
        if let plannedDestinationPath, candidate.path == plannedDestinationPath {
            return 0
        }

        if matchesImportedCounterpart(sourcePath: source.path, candidatePath: candidate.path, target: target) {
            return 1
        }

        if candidate.normalizedKey == source.normalizedKey {
            return 2
        }

        let sourceTitle = normalized(source.title)
        if !sourceTitle.isEmpty, normalized(candidate.title) == sourceTitle {
            return 3
        }

        return nil
    }

    private func matchesImportedCounterpart(
        sourcePath: String,
        candidatePath: String,
        target: MemoryMigrationSide
    ) -> Bool {
        let sourceFileName = URL(fileURLWithPath: sourcePath).lastPathComponent
        guard !sourceFileName.isEmpty,
              sourceFileName == URL(fileURLWithPath: candidatePath).lastPathComponent else {
            return false
        }

        if target == .claude,
           let sourceProjectSlug = codexImportedClaudeProjectSlug(from: sourcePath) {
            return candidatePath.contains("/.claude/projects/\(sourceProjectSlug)/")
        }

        if target == .codex, isClaudeImportedCodexMemory(sourcePath) {
            return candidatePath.contains("/.codex/memories/")
        }

        return false
    }

    private func codexImportedClaudeProjectSlug(from path: String) -> String? {
        let marker = "/.codex/memories/extensions/agent_observatory/claude/"
        guard let markerRange = path.range(of: marker) else { return nil }
        let remainder = path[markerRange.upperBound...]
        guard let slug = remainder.split(separator: "/").first, !slug.isEmpty else { return nil }
        return String(slug)
    }

    private func isClaudeImportedCodexMemory(_ path: String) -> Bool {
        path.contains("/.claude/projects/") && path.contains("/memory/codex/")
    }

}
