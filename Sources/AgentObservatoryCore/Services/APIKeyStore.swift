import Foundation
import Security

public final class APIKeyStore: Sendable {
    public static let shared = APIKeyStore()

    private let service = "com.susu.AgentObservatory"
    private let account = "openai-api-key"

    public init() {}

    public func loadOpenAIKey() -> String {
        var query = baseQuery()
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess,
              let data = item as? Data,
              let key = String(data: data, encoding: .utf8) else {
            return ProcessInfo.processInfo.environment["OPENAI_API_KEY"] ?? ""
        }
        return key
    }

    public func saveOpenAIKey(_ key: String) throws {
        let data = Data(key.utf8)
        SecItemDelete(baseQuery() as CFDictionary)

        var query = baseQuery()
        query[kSecValueData as String] = data
        let status = SecItemAdd(query as CFDictionary, nil)
        if status != errSecSuccess {
            throw NSError(domain: NSOSStatusErrorDomain, code: Int(status))
        }
    }

    public func clearOpenAIKey() {
        SecItemDelete(baseQuery() as CFDictionary)
    }

    private func baseQuery() -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
    }
}
