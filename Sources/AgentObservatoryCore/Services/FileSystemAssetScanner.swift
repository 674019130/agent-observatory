import Foundation

public struct ScanRoot: Identifiable, Sendable {
    public let id = UUID()
    public let owner: AgentOwner
    public let label: String
    public let url: URL
    public let scope: String
    public let maxDepth: Int

    public init(owner: AgentOwner, label: String, url: URL, scope: String, maxDepth: Int = 8) {
        self.owner = owner
        self.label = label
        self.url = url
        self.scope = scope
        self.maxDepth = maxDepth
    }
}

public final class FileSystemAssetScanner {
    public typealias ScanProgressHandler = (ScanProgress) -> Void

    private let fileManager: FileManager
    private let classifier: AssetClassifier
    private let maxPreviewBytes = 220_000
    private let maxReadableBytes: Int64 = 1_200_000

    public init(fileManager: FileManager = .default, classifier: AssetClassifier = AssetClassifier()) {
        self.fileManager = fileManager
        self.classifier = classifier
    }

    public func defaultRoots(
        homeDirectory: URL = FileManager.default.homeDirectoryForCurrentUser,
        projectDirectory: URL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    ) -> [ScanRoot] {
        defaultSources(homeDirectory: homeDirectory, projectDirectory: projectDirectory).map(\.scanRoot)
    }

    public func defaultSources(
        homeDirectory: URL = FileManager.default.homeDirectoryForCurrentUser,
        projectDirectory: URL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    ) -> [ScanSource] {
        let claude = homeDirectory.appendingPathComponent(".claude")
        let codex = homeDirectory.appendingPathComponent(".codex")
        let agents = homeDirectory.appendingPathComponent(".agents")

        return [
            source(.claude, "Claude Instructions", claude.appendingPathComponent("CLAUDE.md"), "global", 0),
            source(.claude, "Claude Settings", claude.appendingPathComponent("settings.json"), "global", 0),
            source(.claude, "Claude Local Settings", claude.appendingPathComponent("settings.local.json"), "global", 0),
            source(.claude, "Claude Commands", claude.appendingPathComponent("commands"), "global", 4),
            source(.claude, "Claude Skills", claude.appendingPathComponent("skills"), "global", 8),
            source(.claude, "Claude Plugins", claude.appendingPathComponent("plugins"), "global", 10),
            source(.claude, "Claude Scripts", claude.appendingPathComponent("scripts"), "global", 5),
            source(.claude, "Claude Hooks", claude.appendingPathComponent("hooks"), "global", 5),
            source(.claude, "Claude Project Memories", claude.appendingPathComponent("projects"), "project-memory", 6),
            source(.claude, "Claude Plans", claude.appendingPathComponent("plans"), "session-history", 3),

            source(.codex, "Codex Instructions", codex.appendingPathComponent("AGENTS.md"), "global", 0),
            source(.codex, "Codex Config", codex.appendingPathComponent("config.toml"), "global", 0),
            source(.codex, "Codex Commands", codex.appendingPathComponent("commands"), "global", 4),
            source(.codex, "Codex Rules", codex.appendingPathComponent("rules"), "global", 4),
            source(.codex, "Codex Skills", codex.appendingPathComponent("skills"), "global", 8),
            source(.codex, "Codex Plugins", codex.appendingPathComponent("plugins/cache"), "plugin", 10),
            source(.codex, "Codex Memories", codex.appendingPathComponent("memories"), "global", 5),
            source(.codex, "Codex Automations", codex.appendingPathComponent("automations"), "automation-memory", 4),

            source(.agents, "Agent Skills", agents.appendingPathComponent("skills"), "global", 8),

            source(.project, "Project AGENTS", projectDirectory.appendingPathComponent("AGENTS.md"), "project", 0),
            source(.project, "Project CLAUDE", projectDirectory.appendingPathComponent("CLAUDE.md"), "project", 0),
            source(.project, "Project MCP", projectDirectory.appendingPathComponent(".mcp.json"), "project", 0),
            source(.project, "Project Codex", projectDirectory.appendingPathComponent(".codex"), "project", 4),
            source(.project, "Project Claude", projectDirectory.appendingPathComponent(".claude"), "project", 4)
        ]
    }

    public func scan(
        sources: [ScanSource],
        progress: ScanProgressHandler? = nil,
        cancellationToken: ScanCancellationToken? = nil
    ) -> [AgentAsset] {
        let roots = sources.filter(\.isEnabled).map(\.scanRoot)
        return scan(roots: roots, progress: progress, cancellationToken: cancellationToken)
    }

    public func scan(
        roots: [ScanRoot]? = nil,
        progress: ScanProgressHandler? = nil,
        cancellationToken: ScanCancellationToken? = nil
    ) -> [AgentAsset] {
        let scanRoots = (roots ?? defaultRoots()).filter { pathExists($0.url) }
        var assets: [AgentAsset] = []
        var seenPaths: Set<String> = []
        var totalFilesVisited = 0
        var totalFilesDiscovered = 0
        var totalFilesProcessed = 0
        var totalDirectoriesSkipped = 0
        var totalReadErrors = 0

        func isCancelled() -> Bool {
            cancellationToken?.isCancelled == true
        }

        func cancelProgress(currentRoot: ScanRoot?, rootIndex: Int) {
            progress?(
                ScanProgress(
                    phase: .cancelled,
                    sourceLabel: currentRoot?.label ?? "All Sources",
                    currentPath: currentRoot.map { displayPath($0.url.path) } ?? "",
                    rootsCompleted: rootIndex,
                    rootCount: scanRoots.count,
                    filesVisited: totalFilesVisited,
                    filesDiscovered: totalFilesDiscovered,
                    filesProcessed: totalFilesProcessed,
                    assetsFound: assets.count,
                    directoriesSkipped: totalDirectoriesSkipped,
                    readErrors: totalReadErrors,
                    message: "Scan cancelled"
                )
            )
        }

        progress?(
            ScanProgress(
                phase: .preparing,
                sourceLabel: "All Sources",
                rootsCompleted: 0,
                rootCount: scanRoots.count,
                message: "Preparing scan roots"
            )
        )

        func recordCollectionUpdate(_ update: CollectionProgress, root: ScanRoot, rootIndex: Int) {
            totalFilesVisited += update.visitedDelta
            totalFilesDiscovered += update.discoveredDelta
            totalDirectoriesSkipped += update.skippedDelta
            progress?(
                ScanProgress(
                    phase: .collecting,
                    sourceLabel: root.label,
                    currentPath: update.currentPath,
                    rootsCompleted: rootIndex,
                    rootCount: scanRoots.count,
                    filesVisited: totalFilesVisited,
                    filesDiscovered: totalFilesDiscovered,
                    filesProcessed: totalFilesProcessed,
                    assetsFound: assets.count,
                    directoriesSkipped: totalDirectoriesSkipped,
                    readErrors: totalReadErrors,
                    message: "Collecting candidate files"
                )
            )
        }

        @discardableResult
        func processCandidate(_ url: URL, root: ScanRoot, rootIndex: Int, rootProgress: Double?) -> Bool {
            guard !isCancelled() else {
                cancelProgress(currentRoot: root, rootIndex: rootIndex)
                return false
            }

            let standardized = url.standardizedFileURL.path
            guard seenPaths.insert(standardized).inserted else { return true }
            guard let kind = kindFor(url: url, root: root) else { return true }
            totalFilesProcessed += 1

            progress?(
                ScanProgress(
                    phase: .processing,
                    sourceLabel: root.label,
                    currentPath: displayPath(url.path),
                    rootsCompleted: rootIndex,
                    rootCount: scanRoots.count,
                    filesVisited: totalFilesVisited,
                    filesDiscovered: totalFilesDiscovered,
                    filesProcessed: totalFilesProcessed,
                    assetsFound: assets.count,
                    directoriesSkipped: totalDirectoriesSkipped,
                    readErrors: totalReadErrors,
                    rootProgress: rootProgress,
                    message: "Processing candidate file"
                )
            )

            let resourceValues = try? url.resourceValues(forKeys: [.contentModificationDateKey, .fileSizeKey])
            let byteCount = Int64(resourceValues?.fileSize ?? 0)
            let isSensitive = SecretRedactor.isSensitivePath(url.path)
            let isLarge = byteCount > maxReadableBytes
            let previewResult = readPreview(url: url, isSensitive: isSensitive, isLarge: isLarge)
            if previewResult.unreadable {
                totalReadErrors += 1
            }
            let relatedFiles = relatedFiles(for: url, kind: kind)

            let asset = classifier.makeAsset(
                url: url,
                owner: root.owner,
                kind: kind,
                scope: root.scope,
                preview: previewResult.preview,
                modifiedAt: resourceValues?.contentModificationDate,
                byteCount: byteCount,
                relatedFiles: relatedFiles,
                isSensitive: isSensitive,
                isLarge: isLarge,
                unreadable: previewResult.unreadable
            )
            assets.append(asset)
            return true
        }

        for (rootIndex, root) in scanRoots.enumerated() {
            guard !isCancelled() else {
                cancelProgress(currentRoot: root, rootIndex: rootIndex)
                return sortedAndMarkedAssets(assets)
            }

            progress?(
                ScanProgress(
                    phase: .collecting,
                    sourceLabel: root.label,
                    currentPath: displayPath(root.url.path),
                    rootsCompleted: rootIndex,
                    rootCount: scanRoots.count,
                    filesVisited: totalFilesVisited,
                    filesDiscovered: totalFilesDiscovered,
                    filesProcessed: totalFilesProcessed,
                    assetsFound: assets.count,
                    directoriesSkipped: totalDirectoriesSkipped,
                    readErrors: totalReadErrors,
                    message: "Collecting candidate files"
                )
            )

            if regularFileExists(root.url) {
                totalFilesVisited += 1
                if kindFor(url: root.url, root: root) != nil {
                    totalFilesDiscovered += 1
                    guard processCandidate(root.url, root: root, rootIndex: rootIndex, rootProgress: 1) else {
                        return sortedAndMarkedAssets(assets)
                    }
                }
            } else {
                collectCandidateFiles(
                    root: root,
                    shouldCancel: isCancelled,
                    progress: { recordCollectionUpdate($0, root: root, rootIndex: rootIndex) },
                    candidate: { url in
                        _ = processCandidate(url, root: root, rootIndex: rootIndex, rootProgress: nil)
                    }
                )
                guard !isCancelled() else {
                    cancelProgress(currentRoot: root, rootIndex: rootIndex)
                    return sortedAndMarkedAssets(assets)
                }
            }

            progress?(
                ScanProgress(
                    phase: .processing,
                    sourceLabel: root.label,
                    rootsCompleted: rootIndex + 1,
                    rootCount: scanRoots.count,
                    filesVisited: totalFilesVisited,
                    filesDiscovered: totalFilesDiscovered,
                    filesProcessed: totalFilesProcessed,
                    assetsFound: assets.count,
                    directoriesSkipped: totalDirectoriesSkipped,
                    readErrors: totalReadErrors,
                    rootProgress: 1,
                    message: "Finished \(root.label)"
                )
            )
        }

        progress?(
            ScanProgress(
                phase: .finalizing,
                sourceLabel: "All Sources",
                rootsCompleted: scanRoots.count,
                rootCount: scanRoots.count,
                filesVisited: totalFilesVisited,
                filesDiscovered: totalFilesDiscovered,
                filesProcessed: totalFilesProcessed,
                assetsFound: assets.count,
                directoriesSkipped: totalDirectoriesSkipped,
                readErrors: totalReadErrors,
                rootProgress: 1,
                message: "Checking duplicates and sorting"
            )
        )

        let sortedAssets = sortedAndMarkedAssets(assets)

        progress?(
            ScanProgress(
                phase: .completed,
                sourceLabel: "All Sources",
                rootsCompleted: scanRoots.count,
                rootCount: scanRoots.count,
                filesVisited: totalFilesVisited,
                filesDiscovered: totalFilesDiscovered,
                filesProcessed: totalFilesProcessed,
                assetsFound: sortedAssets.count,
                directoriesSkipped: totalDirectoriesSkipped,
                readErrors: totalReadErrors,
                rootProgress: 1,
                message: "Scan completed"
            )
        )

        return sortedAssets
    }

    private func source(
        _ owner: AgentOwner,
        _ label: String,
        _ url: URL,
        _ scope: String,
        _ maxDepth: Int
    ) -> ScanSource {
        ScanSource(
            id: "\(owner.shortName.lowercased())-\(scope)-\(label.lowercased().replacingOccurrences(of: " ", with: "-"))",
            owner: owner,
            label: label,
            path: url.path,
            scope: scope,
            maxDepth: maxDepth
        )
    }

    private func directoryExists(_ url: URL) -> Bool {
        var isDirectory: ObjCBool = false
        return fileManager.fileExists(atPath: url.path, isDirectory: &isDirectory) && isDirectory.boolValue
    }

    private func regularFileExists(_ url: URL) -> Bool {
        var isDirectory: ObjCBool = false
        return fileManager.fileExists(atPath: url.path, isDirectory: &isDirectory) && !isDirectory.boolValue
    }

    private func pathExists(_ url: URL) -> Bool {
        fileManager.fileExists(atPath: url.path)
    }

    private struct CollectionProgress {
        let currentPath: String
        let visitedDelta: Int
        let discoveredDelta: Int
        let skippedDelta: Int
    }

    private func collectCandidateFiles(
        root: ScanRoot,
        shouldCancel: () -> Bool,
        progress: ((CollectionProgress) -> Void)? = nil,
        candidate: (URL) -> Void
    ) {
        guard let enumerator = fileManager.enumerator(
            at: root.url,
            includingPropertiesForKeys: [.isDirectoryKey, .isRegularFileKey],
            options: [.skipsPackageDescendants]
        ) else {
            return
        }

        var visitedSinceUpdate = 0
        var discoveredSinceUpdate = 0
        var skippedSinceUpdate = 0
        for case let url as URL in enumerator {
            if shouldCancel() {
                break
            }
            visitedSinceUpdate += 1
            let depth = relativeDepth(of: url, from: root.url)
            if depth > root.maxDepth {
                enumerator.skipDescendants()
                skippedSinceUpdate += 1
                continue
            }

            let values = try? url.resourceValues(forKeys: [.isDirectoryKey, .isRegularFileKey])
            if values?.isDirectory == true {
                if shouldSkipDirectory(url, root: root) {
                    enumerator.skipDescendants()
                    skippedSinceUpdate += 1
                }
                continue
            }

            guard values?.isRegularFile == true else { continue }
            if kindFor(url: url, root: root) != nil {
                discoveredSinceUpdate += 1
                progress?(
                    CollectionProgress(
                        currentPath: displayPath(url.path),
                        visitedDelta: visitedSinceUpdate,
                        discoveredDelta: discoveredSinceUpdate,
                        skippedDelta: skippedSinceUpdate
                    )
                )
                visitedSinceUpdate = 0
                discoveredSinceUpdate = 0
                skippedSinceUpdate = 0
                candidate(url)
                continue
            }

            if visitedSinceUpdate >= 25 {
                progress?(
                    CollectionProgress(
                        currentPath: displayPath(url.path),
                        visitedDelta: visitedSinceUpdate,
                        discoveredDelta: discoveredSinceUpdate,
                        skippedDelta: skippedSinceUpdate
                    )
                )
                visitedSinceUpdate = 0
                discoveredSinceUpdate = 0
                skippedSinceUpdate = 0
            }
        }

        if visitedSinceUpdate > 0 || discoveredSinceUpdate > 0 || skippedSinceUpdate > 0 {
            progress?(
                CollectionProgress(
                    currentPath: displayPath(root.url.path),
                    visitedDelta: visitedSinceUpdate,
                    discoveredDelta: discoveredSinceUpdate,
                    skippedDelta: skippedSinceUpdate
                )
            )
        }
    }

    private func shouldSkipDirectory(_ url: URL, root: ScanRoot) -> Bool {
        AssetSourceRules.shouldSkipDirectory(name: url.lastPathComponent, path: url.path, owner: root.owner)
    }

    private func kindFor(url: URL, root: ScanRoot) -> AssetKind? {
        AssetSourceRules.kind(for: url, root: root)
    }

    private func readPreview(url: URL, isSensitive: Bool, isLarge: Bool) -> (preview: String, unreadable: Bool) {
        if isSensitive {
            return ("Sensitive file intentionally not previewed.", false)
        }
        if isLarge {
            return ("Large file skipped. Size is above the local preview limit.", false)
        }

        do {
            let data = try Data(contentsOf: url)
            let slice = data.prefix(maxPreviewBytes)
            let text = String(decoding: slice, as: UTF8.self)
            if data.count > maxPreviewBytes {
                return (text + "\n\n[Preview truncated]", false)
            }
            return (text, false)
        } catch {
            return ("Unable to read file: \(error.localizedDescription)", true)
        }
    }

    private func relatedFiles(for url: URL, kind: AssetKind) -> [String] {
        guard kind == .skill || kind == .command else { return [] }
        let baseDirectory = kind == .skill ? url.deletingLastPathComponent() : url.deletingLastPathComponent()
        let scriptsDirectory = baseDirectory.appendingPathComponent("scripts")
        guard directoryExists(scriptsDirectory),
              let enumerator = fileManager.enumerator(at: scriptsDirectory, includingPropertiesForKeys: [.isRegularFileKey]) else {
            return []
        }

        var files: [String] = []
        for case let scriptURL as URL in enumerator {
            let values = try? scriptURL.resourceValues(forKeys: [.isRegularFileKey])
            if values?.isRegularFile == true {
                files.append(scriptURL.path.replacingOccurrences(of: NSHomeDirectory(), with: "~"))
            }
        }
        return files.sorted()
    }

    private func relativeDepth(of url: URL, from root: URL) -> Int {
        let rootComponents = root.standardizedFileURL.pathComponents
        let urlComponents = url.standardizedFileURL.pathComponents
        return max(0, urlComponents.count - rootComponents.count)
    }

    private func displayPath(_ path: String) -> String {
        path.replacingOccurrences(of: NSHomeDirectory(), with: "~")
    }

    private func markDuplicates(in assets: [AgentAsset]) -> [AgentAsset] {
        let typedCounts = Dictionary(grouping: assets, by: \.normalizedKey).mapValues(\.count)
        let titleCounts = Dictionary(grouping: assets, by: \.normalizedTitleKey).mapValues(\.count)
        return assets.map { asset in
            guard (typedCounts[asset.normalizedKey] ?? 0) > 1 || (titleCounts[asset.normalizedTitleKey] ?? 0) > 1 else {
                return asset
            }
            var copy = asset
            if !copy.statusFlags.contains(.duplicate) {
                copy.statusFlags.append(.duplicate)
                copy.statusFlags.sort { $0.rawValue < $1.rawValue }
            }
            return copy
        }
    }

    private func sortedAndMarkedAssets(_ assets: [AgentAsset]) -> [AgentAsset] {
        markDuplicates(in: assets)
            .sorted { left, right in
                if left.owner.rawValue != right.owner.rawValue {
                    return left.owner.rawValue < right.owner.rawValue
                }
                if left.kind.rawValue != right.kind.rawValue {
                    return left.kind.rawValue < right.kind.rawValue
                }
                return left.title.localizedCaseInsensitiveCompare(right.title) == .orderedAscending
            }
    }
}
