import Foundation
import Security

enum KeychainKey: String {
    case accessToken = "com.res.jobhopperAI.access-token"
    case refreshToken = "com.res.jobhopperAI.refresh-token"
    case userEmail = "com.res.jobhopperAI.user-email"
    case userId = "com.res.jobhopperAI.user-id"
    case displayName = "com.res.jobhopperAI.display-name"
    case appAccountToken = "com.res.jobhopperAI.app-account-token"
    case linkedInURL = "com.res.jobhopperAI.linkedin-url"
    case deviceId = "com.res.jobhopperAI.device-id"
    // Legacy items — purged at launch to remove any cached AI master keys.
    case legacyDeepgramAPIKey = "com.res.jobhopperAI.deepgram-api-key"
    case legacyOpenAIAPIKey = "com.res.jobhopperAI.openai-api-key"
}

struct KeychainService {
    /// Atomically writes `value` for `key`. Updates in place if the entry already exists,
    /// otherwise creates a new entry. Avoids the brief window where the prior delete-then-add
    /// sequence had nothing on disk between calls (and the lock-state edge case where the
    /// add could fail without a way to recover the deleted value).
    static func save(key: KeychainKey, value: String) -> Bool {
        guard let data = value.data(using: .utf8) else { return false }

        let lookup: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key.rawValue,
        ]
        let attributes: [String: Any] = [
            kSecValueData as String: data,
        ]

        let updateStatus = SecItemUpdate(lookup as CFDictionary, attributes as CFDictionary)
        if updateStatus == errSecSuccess {
            return true
        }
        if updateStatus != errSecItemNotFound {
            return false
        }

        var addQuery = lookup
        addQuery[kSecValueData as String] = data
        addQuery[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        return SecItemAdd(addQuery as CFDictionary, nil) == errSecSuccess
    }

    static func load(key: KeychainKey) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key.rawValue,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess,
              let data = result as? Data,
              let string = String(data: data, encoding: .utf8) else {
            return nil
        }

        return string
    }

    static func delete(key: KeychainKey) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key.rawValue
        ]
        let status = SecItemDelete(query as CFDictionary)
        return status == errSecSuccess || status == errSecItemNotFound
    }

    static func hasKey(_ key: KeychainKey) -> Bool {
        load(key: key) != nil
    }
}
