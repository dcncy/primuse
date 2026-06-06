#if os(tvOS)
import Foundation
import CryptoKit
import TVServices
import PrimuseKit

/// 把 Top Shelf 展示数据 + 封面预取到 App Group 共享容器,供 Top Shelf 扩展读取。
///
/// 扩展是独立进程,读不到主 app 私有的曲库快照,也没有源凭据。所以由主 app 侧在
/// 曲库刷新后,把「最近播放 / 资料库专辑」连同封面缩略图一次性写到共享容器,扩展
/// 直接读本地文件秒开。封面复用 `TVArtworkLoader`(本地缓存 → iTunes 在线取)。
enum TopShelfPublisher {
    struct Draft: Sendable {
        let id: String
        let title: String
        let subtitle: String
        let artist: String
        let album: String
        let playURL: String
    }

    static func publish(recent: [Draft], albums: [Draft]) async {
        // 没配 App Group(旧版 / 未签 entitlement)时 containerURL 为 nil,直接跳过。
        guard TopShelfStore.containerURL != nil else { return }

        var sections: [TopShelfSection] = []
        let recentItems = await items(from: recent)
        if !recentItems.isEmpty {
            sections.append(TopShelfSection(id: "recent", title: "最近播放", items: recentItems))
        }
        let albumItems = await items(from: albums)
        if !albumItems.isEmpty {
            sections.append(TopShelfSection(id: "albums", title: "资料库", items: albumItems))
        }
        TopShelfStore.save(TopShelfPayload(sections: sections))
        // 通知系统 Top Shelf 内容已变,促其在下次机会重新向扩展取数据(否则停留旧值/空)
        TVTopShelfContentProvider.topShelfContentDidChange()
    }

    private static func items(from drafts: [Draft]) async -> [TopShelfItem] {
        var out: [TopShelfItem] = []
        for d in drafts {
            let file = await cover(key: d.id, artist: d.artist, album: d.album)
            out.append(TopShelfItem(id: d.id, title: d.title, subtitle: d.subtitle,
                                    imageFileName: file, playURL: d.playURL))
        }
        return out
    }

    /// 取封面并复制到 App Group 封面目录,返回文件名;取不到返回 nil(扩展端回退占位)。
    private static func cover(key: String, artist: String, album: String) async -> String? {
        guard let dir = TopShelfStore.coversDirectory, !key.isEmpty else { return nil }
        let name = SHA256.hash(data: Data(key.utf8)).prefix(16)
            .map { String(format: "%02x", $0) }.joined() + ".jpg"
        let dest = dir.appendingPathComponent(name)
        if FileManager.default.fileExists(atPath: dest.path) { return name }
        guard let data = await TVArtworkLoader.shared.cover(key: key, artist: artist, album: album),
              !data.isEmpty else { return nil }
        try? data.write(to: dest, options: .atomic)
        return name
    }
}
#endif
