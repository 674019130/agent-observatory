import Foundation

public enum DependencyExtractor {
    public static func extract(from text: String) -> [String] {
        let patterns = [
            #"~/(?:\.claude|\.codex|\.agents)/[A-Za-z0-9_\-./]+"#,
            #"(?:scripts|bin|commands)/[A-Za-z0-9_\-./]+\.(?:sh|py|js|mjs|ts|swift)"#,
            #"[A-Za-z0-9_\-./]+\.(?:sh|py|js|mjs|ts|swift)"#
        ]

        var results: [String] = []
        for pattern in patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern) else { continue }
            let range = NSRange(text.startIndex..<text.endIndex, in: text)
            for match in regex.matches(in: text, range: range) {
                guard let swiftRange = Range(match.range, in: text) else { continue }
                let value = String(text[swiftRange])
                    .trimmingCharacters(in: CharacterSet(charactersIn: "`\"'()[]{}.,"))
                guard value.count > 2 else { continue }
                results.append(value)
            }
        }

        return Array(Set(results)).sorted()
    }
}
