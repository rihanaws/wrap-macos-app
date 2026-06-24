import Foundation

struct CopilotToken: Codable, Equatable {
    var accessToken: String
    var refreshToken: String?
    var expirationDate: Date?
    var scope: String

    var isExpired: Bool {
        guard let expirationDate else { return false }
        return expirationDate <= Date()
    }
}

final class CopilotTokenStore {
    private let keychain: KeychainManager
    private let serviceName = "com.warpclone.copilot"
    private let accountName = "copilot_oauth"

    init(keychain: KeychainManager = KeychainManager()) {
        self.keychain = keychain
    }

    func save(_ token: CopilotToken) throws {
        let data = try JSONEncoder().encode(token)
        guard let encoded = String(data: data, encoding: .utf8) else {
            throw KeychainManager.KeychainError.invalidData
        }
        try keychain.save(service: serviceName, account: accountName, secret: encoded)
    }

    func load() throws -> CopilotToken? {
        guard let encoded = try keychain.read(service: serviceName, account: accountName) else {
            return nil
        }
        guard let data = encoded.data(using: .utf8) else {
            throw KeychainManager.KeychainError.invalidData
        }
        return try JSONDecoder().decode(CopilotToken.self, from: data)
    }

    func delete() throws {
        try keychain.delete(service: serviceName, account: accountName)
    }
}
