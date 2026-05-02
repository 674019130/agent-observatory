import Foundation

public final class SummaryCache: Sendable {
    private let url: URL

    public init(url: URL) {
        self.url = url
    }

    public static var defaultURL: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support")
        return base
            .appendingPathComponent("AgentObservatory", isDirectory: true)
            .appendingPathComponent("summary-cache.json")
    }

    public func loadSummaries() throws -> [String: String] {
        guard FileManager.default.fileExists(atPath: url.path) else { return [:] }
        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let entries = try decoder.decode([String: SummaryCacheEntry].self, from: data)
        return entries.mapValues(\.summary)
    }

    public func save(summary: String, forContentHash contentHash: String) throws {
        var entries = try loadEntries()
        entries[contentHash] = SummaryCacheEntry(summary: summary, updatedAt: Date())
        try write(entries)
    }

    public func save(summaries: [String: String]) throws {
        let entries = summaries.mapValues { SummaryCacheEntry(summary: $0, updatedAt: Date()) }
        try write(entries)
    }

    private func loadEntries() throws -> [String: SummaryCacheEntry] {
        guard FileManager.default.fileExists(atPath: url.path) else { return [:] }
        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode([String: SummaryCacheEntry].self, from: data)
    }

    private func write(_ entries: [String: SummaryCacheEntry]) throws {
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        try encoder.encode(entries).write(to: url, options: .atomic)
    }
}

private struct SummaryCacheEntry: Codable, Sendable {
    let summary: String
    let updatedAt: Date
}
