import Foundation
import Security

public enum CLIKeychainError: Error, LocalizedError {
    case invalidData
    case unexpectedStatus(OSStatus)

    public var errorDescription: String? {
        switch self {
        case .invalidData:
            "Keychain data could not be decoded."
        case .unexpectedStatus(let status):
            "Keychain returned OSStatus \(status)."
        }
    }
}

public final class CLIKeychainStore {
    public init() {}

    public func saveAPIKey(_ apiKey: String, provider: CLIProvider) throws {
        guard let data = apiKey.data(using: .utf8) else {
            throw CLIKeychainError.invalidData
        }

        let query = baseQuery(provider: provider)
        SecItemDelete(query as CFDictionary)

        var attributes = query
        attributes[kSecValueData as String] = data
        attributes[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly

        let status = SecItemAdd(attributes as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw CLIKeychainError.unexpectedStatus(status)
        }
    }

    public func loadAPIKey(provider: CLIProvider) throws -> String? {
        var query = baseQuery(provider: provider)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecItemNotFound {
            return nil
        }
        guard status == errSecSuccess else {
            throw CLIKeychainError.unexpectedStatus(status)
        }
        guard let data = result as? Data, let key = String(data: data, encoding: .utf8) else {
            throw CLIKeychainError.invalidData
        }
        return key
    }

    public func deleteAPIKey(provider: CLIProvider) throws {
        let status = SecItemDelete(baseQuery(provider: provider) as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw CLIKeychainError.unexpectedStatus(status)
        }
    }

    private func baseQuery(provider: CLIProvider) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: provider.keychainServiceName,
            kSecAttrAccount as String: "apiKey"
        ]
    }
}
