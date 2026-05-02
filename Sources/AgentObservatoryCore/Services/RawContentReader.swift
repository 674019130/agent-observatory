import Foundation

public struct RawContentReader: Sendable {
    private let maxAutomaticReadBytes: Int64

    public init(maxAutomaticReadBytes: Int64 = 2_000_000) {
        self.maxAutomaticReadBytes = maxAutomaticReadBytes
    }

    public func read(path: String, allowLargeFile: Bool = false) -> RawContentResult {
        if SecretRedactor.isSensitivePath(path) {
            return RawContentResult(
                text: "Sensitive file intentionally not displayed.",
                isSensitive: true,
                isUnreadable: false,
                isTooLarge: false
            )
        }

        let url = URL(fileURLWithPath: path)
        let fileSize = (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize).map(Int64.init)
        if let fileSize, fileSize > maxAutomaticReadBytes, !allowLargeFile {
            return RawContentResult(
                text: "File is \(ByteCountFormatter.string(fromByteCount: fileSize, countStyle: .file)). Load explicitly to display the full raw content.",
                isSensitive: false,
                isUnreadable: false,
                isTooLarge: true,
                byteCount: fileSize
            )
        }

        do {
            let data = try Data(contentsOf: url)
            let text = String(decoding: data, as: UTF8.self)
            return RawContentResult(
                text: SecretRedactor.redact(text),
                isSensitive: false,
                isUnreadable: false,
                isTooLarge: false,
                byteCount: Int64(data.count)
            )
        } catch {
            return RawContentResult(
                text: "Unable to read full file: \(error.localizedDescription)",
                isSensitive: false,
                isUnreadable: true,
                isTooLarge: false,
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
    public let byteCount: Int64?

    public init(
        text: String,
        isSensitive: Bool,
        isUnreadable: Bool,
        isTooLarge: Bool = false,
        byteCount: Int64? = nil
    ) {
        self.text = text
        self.isSensitive = isSensitive
        self.isUnreadable = isUnreadable
        self.isTooLarge = isTooLarge
        self.byteCount = byteCount
    }
}
