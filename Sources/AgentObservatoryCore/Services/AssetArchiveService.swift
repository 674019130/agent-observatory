import Foundation

public enum AssetArchiveError: LocalizedError, Equatable, Sendable {
    case sourceMissing(String)
    case archivedFileMissing(String)
    case restoreConflict(String)
    case fileOperation(String)

    public var errorDescription: String? {
        switch self {
        case .sourceMissing(let path):
            "Source file does not exist: \(path)"
        case .archivedFileMissing(let path):
            "Archived file does not exist: \(path)"
        case .restoreConflict(let path):
            "Cannot restore because a file already exists at: \(path)"
        case .fileOperation(let message):
            message
        }
    }
}

public struct AssetArchiveService {
    public let archiveRoot: URL

    private let fileManager: FileManager

    public init(
        archiveRoot: URL = AssetArchiveService.defaultArchiveRoot(),
        fileManager: FileManager = .default
    ) {
        self.archiveRoot = archiveRoot
        self.fileManager = fileManager
    }

    public static func defaultArchiveRoot(fileManager: FileManager = .default) -> URL {
        let base = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? fileManager.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support", isDirectory: true)
        return base
            .appendingPathComponent("AgentObservatory", isDirectory: true)
            .appendingPathComponent("Archive", isDirectory: true)
    }

    public func archive(asset: AgentAsset, reason: String) throws -> ArchivedAsset {
        let sourceURL = URL(fileURLWithPath: asset.path)
        guard fileManager.fileExists(atPath: sourceURL.path) else {
            throw AssetArchiveError.sourceMissing(sourceURL.path)
        }

        let ownerDirectory = archiveRoot
            .appendingPathComponent(asset.owner.shortName.lowercased(), isDirectory: true)
        do {
            try fileManager.createDirectory(at: ownerDirectory, withIntermediateDirectories: true)
        } catch {
            throw AssetArchiveError.fileOperation("Could not create archive directory: \(error.localizedDescription)")
        }

        let destinationURL = uniqueArchiveURL(for: sourceURL, in: ownerDirectory)
        do {
            try fileManager.moveItem(at: sourceURL, to: destinationURL)
        } catch {
            throw AssetArchiveError.fileOperation("Could not archive file: \(error.localizedDescription)")
        }

        return ArchivedAsset(
            originalPath: sourceURL.path,
            archivedPath: destinationURL.path,
            owner: asset.owner,
            kind: asset.kind,
            title: asset.title,
            contentHash: asset.contentHash,
            reason: reason.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "No reason provided" : reason
        )
    }

    public func restore(_ archivedAsset: ArchivedAsset) throws {
        let archivedURL = URL(fileURLWithPath: archivedAsset.archivedPath)
        let originalURL = URL(fileURLWithPath: archivedAsset.originalPath)

        guard fileManager.fileExists(atPath: archivedURL.path) else {
            throw AssetArchiveError.archivedFileMissing(archivedURL.path)
        }
        guard !fileManager.fileExists(atPath: originalURL.path) else {
            throw AssetArchiveError.restoreConflict(originalURL.path)
        }

        do {
            try fileManager.createDirectory(
                at: originalURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            try fileManager.moveItem(at: archivedURL, to: originalURL)
        } catch {
            throw AssetArchiveError.fileOperation("Could not restore file: \(error.localizedDescription)")
        }
    }

    private func uniqueArchiveURL(for sourceURL: URL, in directory: URL) -> URL {
        let safeName = sanitizedFileName(sourceURL.lastPathComponent.isEmpty ? "archived-file" : sourceURL.lastPathComponent)
        var candidate = directory.appendingPathComponent("\(UUID().uuidString)-\(safeName)")
        while fileManager.fileExists(atPath: candidate.path) {
            candidate = directory.appendingPathComponent("\(UUID().uuidString)-\(safeName)")
        }
        return candidate
    }

    private func sanitizedFileName(_ name: String) -> String {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: ".-_"))
        let scalars = name.unicodeScalars.map { scalar in
            allowed.contains(scalar) ? Character(scalar) : "-"
        }
        let value = String(scalars).trimmingCharacters(in: CharacterSet(charactersIn: ".-"))
        return value.isEmpty ? "archived-file" : value
    }
}
