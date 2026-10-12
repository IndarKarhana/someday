import Foundation
import Security

/// No delete/reset API. No synchronization or portable backup of the secret.
enum KeychainAuthority {
    private static func query() throws -> [String: Any] {
        guard let group = Bundle.main.object(forInfoDictionaryKey: "SomedayKeychainGroup") as? String,
              !group.isEmpty, !group.contains("$(") else { throw JournalError.sharedContainerUnavailable }
        return [kSecClass as String: kSecClassGenericPassword,
                kSecAttrService as String: "Someday.DrawAuthority.v2",
                kSecAttrAccount as String: "owner",
                kSecAttrAccessGroup as String: group,
                kSecAttrSynchronizable as String: false,
                kSecUseDataProtectionKeychain as String: true]
    }

    static func read() throws -> DrawAuthority? {
        var request = try query()
        request[kSecReturnData as String] = true
        request[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: CFTypeRef?
        let status = SecItemCopyMatching(request as CFDictionary, &result)
        // Locked/unavailable/corrupt/misconfigured is NOT the same as absent.
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess else { throw KeychainFailure(status: status) }
        guard let data = result as? Data else { throw JournalError.invalidAuthority }
        return try DrawAuthority.fromProtectedRepresentation(data)
    }

    static func create(_ authority: DrawAuthority) throws {
        var request = try query()
        request[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        request[kSecValueData as String] = try authority.protectedRepresentation()
        let status = SecItemAdd(request as CFDictionary, nil)
        // A race/conflict is an error; never replace an existing identity.
        guard status == errSecSuccess else { throw KeychainFailure(status: status) }
    }

    static func update(_ authority: DrawAuthority) throws {
        let changes = [kSecValueData as String: try authority.protectedRepresentation()]
        let status = SecItemUpdate(try query() as CFDictionary, changes as CFDictionary)
        guard status == errSecSuccess else { throw KeychainFailure(status: status) }
    }
}

struct KeychainFailure: LocalizedError {
    let status: OSStatus
    var errorDescription: String? {
        "Protected storage is unavailable (\(status)). Unlock your device and try again. Someday will not reset your identity or grant unverified wins."
    }
}
