import Foundation

/// 一个音乐源的凭据(按 sourceID 归档)。密码 / OAuth token / client 密钥都可能有,
/// 取决于源类型。经 CloudKit `encryptedValues` 端到端加密同步到 Apple TV。
public struct CredentialEntry: Codable, Sendable, Equatable {
    public var username: String?
    public var password: String?
    public var token: String?
    public var refreshToken: String?
    public var clientID: String?
    public var clientSecret: String?
    public var extra: [String: String]

    public init(username: String? = nil, password: String? = nil, token: String? = nil,
                refreshToken: String? = nil, clientID: String? = nil, clientSecret: String? = nil,
                extra: [String: String] = [:]) {
        self.username = username
        self.password = password
        self.token = token
        self.refreshToken = refreshToken
        self.clientID = clientID
        self.clientSecret = clientSecret
        self.extra = extra
    }

    public var isEmpty: Bool {
        (password ?? "").isEmpty && (token ?? "").isEmpty && (refreshToken ?? "").isEmpty
    }

    public func toCredential(defaultUsername: String?) -> SourceCredential {
        SourceCredential(username: username ?? defaultUsername, password: password, token: token,
                         refreshToken: refreshToken, clientID: clientID, clientSecret: clientSecret, extra: extra)
    }
}

/// 全部源的凭据集合,作为一个整体加密同步。
public struct CredentialBundle: Codable, Sendable, Equatable {
    public var version: Int
    public var entries: [String: CredentialEntry]   // sourceID → 凭据

    public init(version: Int = 1, entries: [String: CredentialEntry] = [:]) {
        self.version = version
        self.entries = entries
    }

    public func jsonData() throws -> Data { try JSONEncoder().encode(self) }

    public static func decode(_ data: Data) -> CredentialBundle? {
        try? JSONDecoder().decode(CredentialBundle.self, from: data)
    }

    public func credential(for sourceID: String, defaultUsername: String?) -> SourceCredential? {
        entries[sourceID]?.toCredential(defaultUsername: defaultUsername)
    }
}
