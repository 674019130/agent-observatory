import Foundation

public enum ScanSourceEventFilter {
    public static func relevantEventPaths(_ paths: [String], sources: [ScanSource]) -> [String] {
        let enabledSources = sources.filter(\.isEnabled)
        var seen: Set<String> = []
        var relevant: [String] = []

        for path in paths {
            let standardizedPath = standardize(path)
            guard enabledSources.contains(where: { isRelevant(path: standardizedPath, for: $0) }) else {
                continue
            }
            if seen.insert(standardizedPath).inserted {
                relevant.append(standardizedPath)
            }
        }

        return relevant
    }

    private static func isRelevant(path: String, for source: ScanSource) -> Bool {
        let sourcePath = source.url.standardizedFileURL.path
        if isFileSource(source) {
            return path == sourcePath
        }

        guard isPath(path, inside: sourcePath) else { return false }
        if path == sourcePath { return true }
        if exceedsDepth(path: path, root: sourcePath, maxDepth: source.maxDepth) { return false }
        if containsSkippedDirectory(path: path, root: sourcePath, owner: source.owner) { return false }
        return kindFor(path: path, owner: source.owner) != nil
    }

    private static func standardize(_ path: String) -> String {
        URL(fileURLWithPath: (path as NSString).expandingTildeInPath).standardizedFileURL.path
    }

    private static func isFileSource(_ source: ScanSource) -> Bool {
        source.maxDepth == 0 && kindFor(path: source.url.standardizedFileURL.path, owner: source.owner) != nil
    }

    private static func isPath(_ path: String, inside root: String) -> Bool {
        path == root || path.hasPrefix(root.hasSuffix("/") ? root : "\(root)/")
    }

    private static func exceedsDepth(path: String, root: String, maxDepth: Int) -> Bool {
        relativeComponents(path: path, root: root).count > maxDepth
    }

    private static func containsSkippedDirectory(path: String, root: String, owner: AgentOwner) -> Bool {
        let components = relativeComponents(path: path, root: root).dropLast()
        let lowerPath = path.lowercased()
        let alwaysSkip: Set<String> = [".git", ".build", "node_modules", "dist", "deriveddata", ".tmp", "tmp"]

        for component in components {
            let name = component.lowercased()
            if alwaysSkip.contains(name) { return true }

            if owner == .codex {
                if ["sessions", "archived_sessions", "shell_snapshots", "log", "logs", "sqlite", "ambient-suggestions"].contains(name) {
                    return true
                }
                if name == "cache" && !lowerPath.contains("/plugins/cache") {
                    return true
                }
            }

            if owner == .claude {
                let skippedClaudeDirectories: Set<String> = [
                    "backups",
                    "cache",
                    "debug",
                    "file-history",
                    "paste-cache",
                    "session-env",
                    "sessions",
                    "shell-snapshots",
                    "statsig",
                    "tasks",
                    "telemetry",
                    "todos",
                    "usage-data"
                ]
                if skippedClaudeDirectories.contains(name) {
                    return true
                }
            }
        }

        return false
    }

    private static func relativeComponents(path: String, root: String) -> [String] {
        let rootComponents = URL(fileURLWithPath: root).standardizedFileURL.pathComponents
        let pathComponents = URL(fileURLWithPath: path).standardizedFileURL.pathComponents
        guard pathComponents.count >= rootComponents.count else { return [] }
        return Array(pathComponents.dropFirst(rootComponents.count))
    }

    private static func kindFor(path: String, owner: AgentOwner) -> AssetKind? {
        let url = URL(fileURLWithPath: path)
        let name = url.lastPathComponent.lowercased()
        let ext = url.pathExtension.lowercased()
        let lowerPath = path.lowercased()

        if name == "skill.md" { return .skill }
        if name == "agents.md" || name == "claude.md" { return .instruction }
        if name == "memory.md" || name == "favorite_tools.md" || (lowerPath.contains("/memory/") && ext == "md") || (lowerPath.contains("/memories/") && ext == "md") {
            return .memory
        }
        if lowerPath.contains("/commands/") && ext == "md" { return .command }
        if name == ".mcp.json" || (name.contains("mcp") && ["json", "toml", "md"].contains(ext)) { return .mcp }
        if name == "config.toml" || name == "settings.json" || name == "settings.local.json" || name == "auth.json" || name == ".codex-global-state.json" {
            return .config
        }
        if lowerPath.contains("/hooks/") && ["sh", "py", "js", "mjs", "ts", "swift"].contains(ext) {
            return .script
        }
        if ext == "toml" && (lowerPath.contains("/.codex/") || lowerPath.contains("/environments/")) {
            return .config
        }
        if ext == "rules" || lowerPath.contains("/rules/") { return .rule }
        if lowerPath.contains("/scripts/") && ["sh", "py", "js", "mjs", "ts", "swift"].contains(ext) {
            return .script
        }
        if lowerPath.contains("/plugins/") && ["json", "toml", "md"].contains(ext) {
            return .plugin
        }

        return nil
    }
}
