import Foundation

public struct RawContentReader: Sendable {
    private let maxAutomaticReadBytes: Int64
    private let maxExplicitReadBytes: Int64
    private let maxSensitivePreviewBytes: Int64

    public init(
        maxAutomaticReadBytes: Int64 = 2_000_000,
        maxExplicitReadBytes: Int64 = 8_000_000,
        maxSensitivePreviewBytes: Int64 = 64_000
    ) {
        self.maxAutomaticReadBytes = maxAutomaticReadBytes
        self.maxExplicitReadBytes = maxExplicitReadBytes
        self.maxSensitivePreviewBytes = maxSensitivePreviewBytes
    }

    public func read(
        path: String,
        allowLargeFile: Bool = false,
        allowSensitivePreview: Bool = false,
        forceSensitive: Bool = false,
        language: AppLanguage = .english
    ) -> RawContentResult {
        if forceSensitive || SecretRedactor.isSensitivePath(path) {
            if allowSensitivePreview {
                return readSensitivePreview(path: path, language: language)
            }
            return RawContentResult(
                text: L10n.text(.rawSensitiveFileHidden, language: language),
                isSensitive: true,
                isUnreadable: false,
                isTooLarge: false,
                isRedactedPreview: false
            )
        }

        let url = URL(fileURLWithPath: path)
        let fileSize = (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize).map(Int64.init)
        if let fileSize, fileSize > maxAutomaticReadBytes, !allowLargeFile {
            return RawContentResult(
                text: String(
                    format: L10n.text(.rawLargeFileRequiresExplicitLoad, language: language),
                    ByteCountFormatter.string(fromByteCount: fileSize, countStyle: .file)
                ),
                isSensitive: false,
                isUnreadable: false,
                isTooLarge: true,
                isRedactedPreview: false,
                byteCount: fileSize
            )
        }
        if let fileSize, fileSize > maxExplicitReadBytes {
            return RawContentResult(
                text: String(
                    format: L10n.text(.rawFileTooLargeForInline, language: language),
                    ByteCountFormatter.string(fromByteCount: fileSize, countStyle: .file)
                ),
                isSensitive: false,
                isUnreadable: false,
                isTooLarge: true,
                isRedactedPreview: false,
                byteCount: fileSize
            )
        }

        do {
            let data = try Data(contentsOf: url)
            let text = String(decoding: data, as: UTF8.self)
            let redactedText = SecretRedactor.redact(text)
            let containsSecret = SecretRedactor.containsSecret(text)
            return RawContentResult(
                text: redactedText,
                isSensitive: containsSecret,
                isUnreadable: false,
                isTooLarge: false,
                isRedactedPreview: containsSecret,
                byteCount: Int64(data.count)
            )
        } catch {
            return RawContentResult(
                text: String(format: L10n.text(.rawUnableToReadFile, language: language), error.localizedDescription),
                isSensitive: false,
                isUnreadable: true,
                isTooLarge: false,
                isRedactedPreview: false,
                byteCount: fileSize
            )
        }
    }

    private func readSensitivePreview(path: String, language: AppLanguage) -> RawContentResult {
        let url = URL(fileURLWithPath: path)
        let fileSize = (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize).map(Int64.init)

        do {
            let handle = try FileHandle(forReadingFrom: url)
            defer { try? handle.close() }
            let data = try handle.read(upToCount: Int(maxSensitivePreviewBytes)) ?? Data()
            var text = SecretRedactor.redact(String(decoding: data, as: UTF8.self))
            if let fileSize, fileSize > maxSensitivePreviewBytes {
                text += "\n\n[Redacted local preview capped at \(ByteCountFormatter.string(fromByteCount: maxSensitivePreviewBytes, countStyle: .file))]"
            }
            return RawContentResult(
                text: text,
                isSensitive: true,
                isUnreadable: false,
                isTooLarge: false,
                isRedactedPreview: true,
                byteCount: fileSize
            )
        } catch {
            return RawContentResult(
                text: String(format: L10n.text(.rawUnableToReadFile, language: language), error.localizedDescription),
                isSensitive: true,
                isUnreadable: true,
                isTooLarge: false,
                isRedactedPreview: false,
                byteCount: fileSize
            )
        }
    }
}

public struct RawContentResult: Equatable, Sendable {
    public let text: String
    public let isSensitive: Bool
    public let isUnreadable: Bool
    public let isTooLarge: Bool
    public let isRedactedPreview: Bool
    public let byteCount: Int64?

    public init(
        text: String,
        isSensitive: Bool,
        isUnreadable: Bool,
        isTooLarge: Bool = false,
        isRedactedPreview: Bool = false,
        byteCount: Int64? = nil
    ) {
        self.text = text
        self.isSensitive = isSensitive
        self.isUnreadable = isUnreadable
        self.isTooLarge = isTooLarge
        self.isRedactedPreview = isRedactedPreview
        self.byteCount = byteCount
    }
}
