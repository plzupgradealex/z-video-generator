import Foundation
import Security

/// Minimal Keychain wrapper. Stores the Z.AI API key securely instead of
/// UserDefaults plaintext — an App Store best practice.
enum KeychainStore {
    private static let service = "com.alex.ZVideoGenerator"
    private static let account = "apiKey"

    static func set(_ value: String) {
        let data = Data(value.utf8)
        let query: [String: Any] = baseQuery()
        SecItemDelete(query as CFDictionary)
        var attrs = query
        attrs[kSecValueData as String] = data
        // Require an unlocked Mac to read the key (the app only ever needs it
        // while the user is present), and never let the secret sync to iCloud
        // Keychain or travel to another Mac via backup.
        attrs[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlocked
        attrs[kSecAttrSynchronizable as String] = kCFBooleanFalse
        SecItemAdd(attrs as CFDictionary, nil)
    }

    static func get() -> String? {
        var query = baseQuery()
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static func delete() {
        SecItemDelete(baseQuery() as CFDictionary)
    }

    private static func baseQuery() -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
    }
}
