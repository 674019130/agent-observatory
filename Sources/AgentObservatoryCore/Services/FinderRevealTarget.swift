import Foundation

public enum FinderRevealTarget {
    public static func selectingURL(for path: String, fileManager: FileManager = .default) -> URL {
        let expandedPath = (path as NSString).expandingTildeInPath
        let url = URL(fileURLWithPath: expandedPath).standardizedFileURL

        if fileManager.fileExists(atPath: url.path) {
            return url
        }

        var ancestor = url.deletingLastPathComponent()
        while ancestor.path != "/" && !fileManager.fileExists(atPath: ancestor.path) {
            ancestor.deleteLastPathComponent()
        }

        if fileManager.fileExists(atPath: ancestor.path) {
            return ancestor
        }

        return url.deletingLastPathComponent()
    }
}
