import Foundation

public enum SecretRedactor {
    private static let secretPatterns: [(String, String)] = [
        (#"sk-[A-Za-z0-9_\-]{20,}"#, "sk-[REDACTED]"),
        (#"(?i)(api[_-]?key\s*[:=]\s*)["']?[^"'\s,}]+["']?"#, "$1[REDACTED]"),
        (#"(?i)(authorization\s*[:=]\s*bearer\s+)[A-Za-z0-9_\-\.]+"#, "$1[REDACTED]"),
        (#"(?i)(token\s*[:=]\s*)["']?[^"'\s,}]+["']?"#, "$1[REDACTED]"),
        (#"(?i)(password\s*[:=]\s*)["']?[^"'\s,}]+["']?"#, "$1[REDACTED]")
    ]

    public static func redact(_ text: String) -> String {
        secretPatterns.reduce(text) { current, pattern in
            current.replacingOccurrences(
                of: pattern.0,
                with: pattern.1,
                options: .regularExpression
            )
        }
    }

    public static func isSensitivePath(_ path: String) -> Bool {
        let fileName = URL(fileURLWithPath: path).lastPathComponent.lowercased()
        return fileName == "auth.json"
            || fileName.contains("token")
            || fileName.contains("secret")
            || fileName.contains("credential")
            || fileName == ".env"
            || fileName.hasSuffix(".key")
            || fileName.hasSuffix(".pem")
    }
}
