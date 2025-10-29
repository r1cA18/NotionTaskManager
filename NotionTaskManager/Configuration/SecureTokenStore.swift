import Foundation
import Security

protocol TokenStore {
    func loadToken() throws -> String?
    func saveToken(_ token: String) throws
    func clearToken() throws
}

enum TokenStoreError: LocalizedError {
    case unexpectedStatus(OSStatus)

    var errorDescription: String? {
        switch self {
        case .unexpectedStatus(let status):
            return "Keychain operation failed with status \(status)."
        }
    }
}

struct SecureTokenStore: TokenStore {
    private let service: String
    private let account: String

    init(service: String = "com.ryooooooo.NotionTaskManager", account: String = "notion.integration.token") {
        self.service = service
        self.account = account
    }

    func loadToken() throws -> String? {
        var query = baseQuery()
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        switch status {
        case errSecSuccess:
            guard let data = item as? Data, let token = String(data: data, encoding: .utf8) else {
                return nil
            }
            return token
        case errSecItemNotFound:
            return nil
        default:
            throw TokenStoreError.unexpectedStatus(status)
        }
    }

    func saveToken(_ token: String) throws {
        let tokenData = Data(token.utf8)
        var query = baseQuery()
        query[kSecValueData as String] = tokenData

        let status = SecItemAdd(query as CFDictionary, nil)
        switch status {
        case errSecSuccess:
            return
        case errSecDuplicateItem:
            try updateToken(tokenData)
        default:
            throw TokenStoreError.unexpectedStatus(status)
        }
    }

    func clearToken() throws {
        let status = SecItemDelete(baseQuery() as CFDictionary)
        switch status {
        case errSecSuccess, errSecItemNotFound:
            return
        default:
            throw TokenStoreError.unexpectedStatus(status)
        }
    }

    private func updateToken(_ data: Data) throws {
        let query = baseQuery()
        let attributes: [String: Any] = [kSecValueData as String: data]
        let status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        guard status == errSecSuccess else {
            throw TokenStoreError.unexpectedStatus(status)
        }
    }

    private func baseQuery() -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
    }
}
