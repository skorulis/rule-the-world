import Foundation
import Security

protocol AuthTokenStoring {
    func load() -> String?
    func save(_ token: String)
    func clear()
}

final class KeychainAuthTokenStore: AuthTokenStoring {
    private let service: String
    private let account: String

    init(service: String = "com.skorulis.RuleTheWorld.auth", account: String = "session-token") {
        self.service = service
        self.account = account
    }

    private var baseQuery: [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
    }

    func load() -> String? {
        var query = baseQuery
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data else {
            return nil
        }
        return String(data: data, encoding: .utf8)
    }

    func save(_ token: String) {
        guard let data = token.data(using: .utf8) else { return }
        let attributes: [String: Any] = [kSecValueData as String: data]
        if SecItemUpdate(baseQuery as CFDictionary, attributes as CFDictionary) == errSecItemNotFound {
            var query = baseQuery
            query[kSecValueData as String] = data
            SecItemAdd(query as CFDictionary, nil)
        }
    }

    func clear() {
        SecItemDelete(baseQuery as CFDictionary)
    }
}

final class InMemoryAuthTokenStore: AuthTokenStoring {
    private(set) var token: String?

    init(token: String? = nil) {
        self.token = token
    }

    func load() -> String? { token }

    func save(_ token: String) { self.token = token }

    func clear() { token = nil }
}
