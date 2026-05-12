import Foundation

public enum OpenAIPayloadGuardError: LocalizedError, Sendable {
    case unsafeAsset(String)
    case noSafeAssets

    public var errorDescription: String? {
        switch self {
        case .unsafeAsset:
            "Asset is unsafe for AI. Sensitive, unreadable, or secret-like content is excluded from OpenAI requests."
        case .noSafeAssets:
            "No assets are safe for AI. Sensitive, unreadable, or secret-like assets were excluded from the request."
        }
    }
}

public enum OpenAIPayloadGuard {
    public static func isSafeForAI(_ asset: AgentAsset) -> Bool {
        !asset.statusFlags.contains(.secretRisk)
            && !asset.statusFlags.contains(.unreadable)
            && !SecretRedactor.isSensitivePath(asset.path)
            && !SecretRedactor.containsSecret(asset.preview)
    }

    public static func requireSafeForAI(_ asset: AgentAsset) throws {
        guard isSafeForAI(asset) else {
            throw OpenAIPayloadGuardError.unsafeAsset(asset.path)
        }
    }

    public static func safeAssets(_ assets: [AgentAsset]) -> [AgentAsset] {
        assets.filter(isSafeForAI)
    }

    public static func safePreview(_ asset: AgentAsset, limit: Int) throws -> String {
        try requireSafeForAI(asset)
        return String(SecretRedactor.redact(asset.preview).prefix(limit))
    }
}
