import Foundation
import Security

/// The guest identity: the profile (nickname, gender, avatar) plus the
/// server-issued token that resumes the same player.
@MainActor
protocol IdentityStoring: AnyObject {
    var profile: Profile? { get set }
    var token: String? { get set }
}

/// Token in the Keychain (it's a credential), profile in UserDefaults.
@MainActor
final class IdentityStore: IdentityStoring {
    private let defaults: UserDefaults
    private let service = "mafia.identity"
    private let account = "token"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var profile: Profile? {
        get {
            guard let nickname = defaults.string(forKey: "nickname"), !nickname.isEmpty,
                  let gender = defaults.string(forKey: "gender").flatMap(Gender.init(rawValue:)),
                  let avatar = defaults.string(forKey: "avatar") else { return nil }
            return Profile(nickname: nickname, gender: gender, avatar: avatar)
        }
        set {
            defaults.set(newValue?.nickname, forKey: "nickname")
            defaults.set(newValue?.gender.rawValue, forKey: "gender")
            defaults.set(newValue?.avatar, forKey: "avatar")
        }
    }

    var token: String? {
        get {
            var query = baseQuery
            query[kSecReturnData as String] = true
            query[kSecMatchLimit as String] = kSecMatchLimitOne
            var item: CFTypeRef?
            guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess, let data = item as? Data else { return nil }
            return String(data: data, encoding: .utf8)
        }
        set {
            SecItemDelete(baseQuery as CFDictionary)
            guard let newValue, let data = newValue.data(using: .utf8) else { return }
            var query = baseQuery
            query[kSecValueData as String] = data
            query[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
            SecItemAdd(query as CFDictionary, nil)
        }
    }

    private var baseQuery: [String: Any] {
        [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service, kSecAttrAccount as String: account]
    }
}

@MainActor
final class InMemoryIdentityStore: IdentityStoring {
    var profile: Profile?
    var token: String?

    init(profile: Profile? = nil, token: String? = nil) {
        self.profile = profile
        self.token = token
    }
}
