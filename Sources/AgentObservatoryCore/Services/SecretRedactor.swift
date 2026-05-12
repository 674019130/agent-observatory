import Foundation

public enum SecretRedactor {
    private static let secretPatterns: [(String, String)] = [
        (#"(?s)-----BEGIN [A-Z ]*PRIVATE KEY-----.*?-----END [A-Z ]*PRIVATE KEY-----"#, "[REDACTED_PRIVATE_KEY]"),
        (#"github_pat_[A-Za-z0-9_]{20,}"#, "github_pat_[REDACTED]"),
        (#"gh[pousr]_[A-Za-z0-9_]{20,}"#, "gh_[REDACTED]"),
        (#"AKIA[0-9A-Z]{16}"#, "AKIA[REDACTED]"),
        (#"sk-ant-[A-Za-z0-9_\-]{20,}"#, "sk-ant-[REDACTED]"),
        (#"sk-[A-Za-z0-9_\-]{20,}"#, "sk-[REDACTED]"),
        (#"xox[baprs]-[A-Za-z0-9\-]{20,}"#, "xox-[REDACTED]"),
        (#"eyJ[A-Za-z0-9_\-]{20,}\.[A-Za-z0-9_\-]{20,}\.[A-Za-z0-9_\-]{10,}"#, "jwt-[REDACTED]"),
        (#"(?i)(["']?(?:api[_-]?key|token|password|_authToken)["']?\s*[:=]\s*)["'][^"',}]+["']"#, "$1\"[REDACTED]\""),
        (#"(?i)(api[_-]?key\s*[:=]\s*)["']?[^"'\s,}]+["']?"#, "$1[REDACTED]"),
        (#"(?i)(authorization\s*[:=]\s*bearer\s+)[A-Za-z0-9_\-\.]+"#, "$1[REDACTED]"),
        (#"(?i)(_authToken\s*[:=]\s*)["']?[^"'\s,}]+["']?"#, "$1[REDACTED]"),
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

    public static func containsSecret(_ text: String) -> Bool {
        secretPatterns.contains { pattern, _ in
            text.range(of: pattern, options: .regularExpression) != nil
        }
    }

    public static func auditSafe(_ text: String) -> String {
        redact(text)
            .replacingOccurrences(
                of: #"/Users/[^\s,;:)\]\}"]+"#,
                with: "[PATH]",
                options: .regularExpression
            )
            .replacingOccurrences(
                of: #"~(/[^\s,;:)\]\}"]+)+"#,
                with: "[PATH]",
                options: .regularExpression
            )
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
