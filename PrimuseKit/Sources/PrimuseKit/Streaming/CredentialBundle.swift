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

/// iPhone 局域网中继端点(Phase 3:本地/SMB/SFTP/NFS/WebDAV 等不可直连源经此播放)。
/// 由 iOS 中继服务启动时写入,随凭据包加密同步;TV 据此拼中继 URL。
public struct RelayEndpoint: Codable, Sendable, Equatable {
    public var host: String     // iPhone 局域网 IP
    public var port: Int
    public var token: String    // 会话令牌,中继服务校验
    public init(host: String, port: Int, token: String) {
        self.host = host
        self.port = port
        self.token = token
    }
}

/// 全部源的凭据集合,作为一个整体加密同步。
public struct CredentialBundle: Codable, Sendable, Equatable {
    public var version: Int
    public var entries: [String: CredentialEntry]   // sourceID → 凭据
    public var relay: RelayEndpoint?                 // iPhone 中继端点(可选)

    public init(version: Int = 1, entries: [String: CredentialEntry] = [:], relay: RelayEndpoint? = nil) {
        self.version = version
        self.entries = entries
        self.relay = relay
    }

    public func jsonData() throws -> Data { try JSONEncoder().encode(self) }

    public static func decode(_ data: Data) -> CredentialBundle? {
        try? JSONDecoder().decode(CredentialBundle.self, from: data)
    }

    public func credential(for sourceID: String, defaultUsername: String?) -> SourceCredential? {
        entries[sourceID]?.toCredential(defaultUsername: defaultUsername)
    }
}
