#if os(tvOS)
import Foundation
import PrimuseKit
import Security

/// tvOS 凭据读取。
///
/// Phase 1:用户名取自同步过来的 `MusicSource.username`,密码从**可同步 iCloud 钥匙串**
/// 按 sourceID 读取(与 iOS `KeychainService` 同一 service + account 约定;同一 Apple ID
/// 且开启 iCloud 钥匙串时,手机写入的密码会同步到 TV)。
///
/// 链式设计:钥匙串 →(Phase 2)CloudKit 加密凭据包 →(Phase 2)设备配对缓存。
/// Phase 1 只接第一环;后续环加入时本方法签名不变。
enum TVCredentialStore {
    /// 凭据来源链:① 经 CloudKit 加密同步下来的凭据包(主路径)② 可同步 iCloud 钥匙串(兜底)。
    /// 中继类型还会附上 iPhone 中继端点(放 extra,供 RelayStreamResolver 拼 URL)。
    static func credential(for source: MusicSource, bundle: CredentialBundle?) -> SourceCredential {
        var cred: SourceCredential
        if let entry = bundle?.entries[source.id], !entry.isEmpty {
            cred = entry.toCredential(defaultUsername: source.username)
        } else {
            cred = SourceCredential(username: source.username, password: keychainPassword(account: source.id))
        }
        if let relay = bundle?.relay, RelayStreamResolver.relayTypes.contains(source.type) {
            cred.extra["relay_host"] = relay.host
            cred.extra["relay_port"] = String(relay.port)
            cred.extra["relay_token"] = relay.token
        }
        return cred
    }

    /// service = `PrimuseConstants.keychainServiceName`,account = sourceID。
    /// `kSecAttrSynchronizableAny` 同时匹配本地项与 iCloud 钥匙串项。
    private static func keychainPassword(account: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: PrimuseConstants.keychainServiceName,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
            kSecAttrSynchronizable as String: kSecAttrSynchronizableAny,
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess,
              let data = result as? Data,
              let value = String(data: data, encoding: .utf8),
              !value.isEmpty else {
            return nil
        }
        return value
    }
}
#endif
