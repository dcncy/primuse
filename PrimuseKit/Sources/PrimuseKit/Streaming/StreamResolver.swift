import Foundation

// MARK: - 流式解析(tvOS 播放)
//
// tvOS 不能用 iOS 那套 SFBAudioEngine + primuse-stream:// 自定义流(依赖原生库 +
// 音频引擎,不可移植)。tvOS 走 AVPlayer + 纯 https URL。这里定义"按音乐源把一首
// 歌解析成可直连播放的网络 URL"的共享契约,各源 resolver 都是纯 URLSession 实现,
// 放在 PrimuseKit 里以保持依赖只有 GRDB(不牵入任何 iOS-only 库)。

/// 解析一首歌所需的源凭据。Phase 1 只用到 username/password(Subsonic 家族);
/// Phase 2 会扩展 token / refreshToken / clientID / clientSecret 等。
public struct SourceCredential: Sendable, Equatable {
    public var username: String?
    public var password: String?
    public var token: String?
    public var refreshToken: String?
    public var clientID: String?
    public var clientSecret: String?
    public var extra: [String: String]

    public init(username: String? = nil,
                password: String? = nil,
                token: String? = nil,
                refreshToken: String? = nil,
                clientID: String? = nil,
                clientSecret: String? = nil,
                extra: [String: String] = [:]) {
        self.username = username
        self.password = password
        self.token = token
        self.refreshToken = refreshToken
        self.clientID = clientID
        self.clientSecret = clientSecret
        self.extra = extra
    }
}

public enum StreamResolveError: Error, Sendable, Equatable {
    /// 该音乐源类型在 tvOS 上无法直连播放(原生库源 / 本地文件等)。
    case unsupportedSourceType(MusicSourceType)
    /// 缺少必要凭据(密码 / token 未同步到本机)。
    case missingCredential
    /// 服务端鉴权失败(会话过期 / 密码错误),协调器据此触发刷新+重试。
    case authFailed
    case badServerResponse(Int)
    case cannotBuildURL
}

/// 把一首歌解析成 AVPlayer 可直接播放的网络 URL。实现必须是 Sendable 的纯网络逻辑。
public protocol StreamResolver: Sendable {
    func streamURL(for song: Song,
                   source: MusicSource,
                   credential: SourceCredential?) async throws -> URL

    /// 会话失效时清掉缓存的会话(如 Synology `_sid`)。无状态源(Subsonic)空实现即可。
    func invalidateSession(sourceID: String) async
}

public extension StreamResolver {
    func invalidateSession(sourceID: String) async {}
}
