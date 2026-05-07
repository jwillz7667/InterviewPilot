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
    static func save(key: KeychainKey, value: String) -> Bool {
        guard let data = value.data(using: .utf8) else { return false }

        // Delete existing item first
        let deleteQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key.rawValue
        ]
        SecItemDelete(deleteQuery as CFDictionary)

        // Add new item
        let addQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key.rawValue,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]

        let status = SecItemAdd(addQuery as CFDictionary, nil)
        return status == errSecSuccess
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
