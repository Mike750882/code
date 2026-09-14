import Foundation
import Security

/// Stores the parent PIN in the Keychain (not in SwiftData/CloudKit) so it
/// never travels as plaintext through app data, while still syncing across
/// the parent's own devices via iCloud Keychain.
enum KeychainService {
    private static let service = "com.yourcompany.SpellWell.parentPIN"

    static func savePIN(_ pin: String) {
        let data = Data(pin.utf8)
        let baseQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrSynchronizable as String: true
        ]
        SecItemDelete(baseQuery as CFDictionary)

        var addQuery = baseQuery
        addQuery[kSecValueData as String] = data
        addQuery[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
        SecItemAdd(addQuery as CFDictionary, nil)
    }

    static func loadPIN() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrSynchronizable as String: true,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static func hasPIN() -> Bool {
        loadPIN() != nil
    }

    static func clearPIN() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrSynchronizable as String: true
        ]
        SecItemDelete(query as CFDictionary)
    }
}
