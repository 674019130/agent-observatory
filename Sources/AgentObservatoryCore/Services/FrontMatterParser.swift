import Foundation

public struct ParsedDocument: Equatable, Sendable {
    public let frontMatter: [String: String]
    public let body: String
}

public enum FrontMatterParser {
    public static func parse(_ text: String) -> ParsedDocument {
        let normalized = text.replacingOccurrences(of: "\r\n", with: "\n")
        guard normalized.hasPrefix("---\n") else {
            return ParsedDocument(frontMatter: [:], body: text)
        }

        let lines = normalized.components(separatedBy: "\n")
        var values: [String: String] = [:]
        var endIndex: Int?

        for index in 1..<lines.count {
            let line = lines[index]
            if line.trimmingCharacters(in: .whitespacesAndNewlines) == "---" {
                endIndex = index
                break
            }

            guard let colon = line.firstIndex(of: ":") else { continue }
            let key = line[..<colon].trimmingCharacters(in: .whitespacesAndNewlines)
            let rawValue = line[line.index(after: colon)...].trimmingCharacters(in: .whitespacesAndNewlines)
            guard !key.isEmpty else { continue }
            values[key] = rawValue.trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))
        }

        guard let endIndex else {
            return ParsedDocument(frontMatter: [:], body: text)
        }

        let bodyLines = lines.dropFirst(endIndex + 1)
        return ParsedDocument(frontMatter: values, body: bodyLines.joined(separator: "\n"))
    }
}
