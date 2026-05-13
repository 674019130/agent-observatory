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
        return kindFor(path: path, source: source) != nil
    }

    private static func standardize(_ path: String) -> String {
        URL(fileURLWithPath: (path as NSString).expandingTildeInPath).standardizedFileURL.path
    }

    private static func isFileSource(_ source: ScanSource) -> Bool {
        source.maxDepth == 0 && kindFor(path: source.url.standardizedFileURL.path, source: source) != nil
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

        for component in components {
            let name = component.lowercased()
            if AssetSourceRules.shouldSkipDirectory(name: name, path: lowerPath, owner: owner) {
                return true
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

    private static func kindFor(path: String, source: ScanSource) -> AssetKind? {
        AssetSourceRules.kind(for: path, source: source)
    }
}
