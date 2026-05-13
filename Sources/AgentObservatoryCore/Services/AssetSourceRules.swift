import Foundation

public enum AssetSourceRules {
    public static func kind(for url: URL, root: ScanRoot) -> AssetKind? {
        kind(forPath: url.path, scope: root.scope)
    }

    public static func kind(for path: String, source: ScanSource) -> AssetKind? {
        kind(forPath: path, scope: source.scope)
    }

    public static func shouldSkipDirectory(name: String, path: String, owner: AgentOwner) -> Bool {
        let lowerName = name.lowercased()
        let lowerPath = path.lowercased()
        let alwaysSkip: Set<String> = [".git", ".build", "node_modules", "dist", "deriveddata", ".tmp", "tmp"]
        if alwaysSkip.contains(lowerName) { return true }

        if owner == .codex {
            if ["sessions", "archived_sessions", "shell_snapshots", "log", "logs", "sqlite", "ambient-suggestions"].contains(lowerName) {
                return true
            }
            if lowerName == "cache" && !lowerPath.contains("/plugins/cache") {
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
            if skippedClaudeDirectories.contains(lowerName) {
                return true
            }
        }

        return false
    }

    private static func kind(forPath path: String, scope: String) -> AssetKind? {
        let url = URL(fileURLWithPath: path)
        let name = url.lastPathComponent.lowercased()
        let ext = url.pathExtension.lowercased()
        let lowerPath = path.lowercased()
        let lowerScope = scope.lowercased()

        if name == "skill.md" { return .skill }
        if name == "agents.md" || name == "claude.md" { return .instruction }
        if name == "memory.md" || name == "favorite_tools.md" || (lowerPath.contains("/memory/") && ext == "md") || (lowerPath.contains("/memories/") && ext == "md") {
            return .memory
        }
        if lowerScope.contains("workspace") && ["md", "markdown", "txt"].contains(ext) {
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
