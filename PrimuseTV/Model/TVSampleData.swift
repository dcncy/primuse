#if os(tvOS)
import SwiftUI
import Observation
import PrimuseKit

// MARK: - 轻量 view-model 类型
//
// UI 层数据契约。TVStore 现在由真实 MusicLibrary + SourcesStore 驱动(读取
// 同步下来的 library-cache.json / sources.json);快照为空时回退到样例数据,
// 这样全新安装、还没同步到曲库时 UI 仍可预览。Now Playing / 歌词 / 队列暂用
// 样例(tvOS 播放后续接入)。

struct TVAlbum: Identifiable, Hashable {
    let id: String
    let title: String
    let artist: String
    let year: Int
    let tint: Color
    let tint2: Color
    let glyph: String
}

struct TVSong: Identifiable, Hashable {
    let id: String
    let albumID: String
    let title: String
    let artist: String
    let duration: Double
    let format: String
    let bitrate: Int
    let sampleRate: Double
    let sourceID: String
    let plays: Int
    let liked: Bool
}

struct TVArtist: Identifiable, Hashable {
    let id: String
    let name: String
    let tint: Color
    let tint2: Color
    let glyph: String
    let songCount: Int
}

enum TVPlaylistKind { case normal, smart, liked }

struct TVPlaylist: Identifiable, Hashable {
    let id: String
    let name: String
    let kind: TVPlaylistKind
    let count: Int
    let coverAlbumID: String
    static func == (l: TVPlaylist, r: TVPlaylist) -> Bool { l.id == r.id }
    func hash(into h: inout Hasher) { h.combine(id) }
}

enum TVSourceStatus { case connected, scanning, authFailed, disabled }

struct TVSource: Identifiable, Hashable {
    let id: String
    let name: String
    let type: String
    let host: String
    let status: TVSourceStatus
    let songs: Int
    let color: Color
    static func == (l: TVSource, r: TVSource) -> Bool { l.id == r.id }
    func hash(into h: inout Hasher) { h.combine(id) }
}

struct TVSyllable: Hashable { let w: String; let d: Double }

struct TVLyricLine: Identifiable, Hashable {
    let id = UUID()
    let time: Double
    let text: String
    let syllables: [TVSyllable]
    let translation: String
}

struct TVNowPlaying {
    var title: String
    var artist: String
    var album: String
    var albumID: String
    var tint: Color
    var tint2: Color
    var glyph: String
    var duration: Double
    var currentTime: Double
    var format: String
    var bitrate: Int
    var sampleRate: Double
    var sourcePath: String
}

// MARK: - Store

@MainActor
@Observable
final class TVStore {
    let library = MusicLibrary()
    let sourcesStore = SourcesStore()

    /// 真实快照非空时走真实数据,否则回退样例。
    var hasRealLibrary: Bool { !library.visibleAlbums.isEmpty }
    var hasRealSources: Bool { !sourcesStore.sources.isEmpty }

    // Now Playing / 歌词 / 队列 — 暂用样例(tvOS 播放后续接入)
    var lyrics: [TVLyricLine] = TVSampleData.lyrics
    var queueUpNextIDs: [String] = TVSampleData.upNextIDs
    var nowPlaying: TVNowPlaying = TVSampleData.nowPlaying
    var isPlaying: Bool = true
    private var localLiked = Set<String>()

    // MARK: 浏览数据(真实 / 样例)

    var albums: [TVAlbum] {
        hasRealLibrary ? library.visibleAlbums.map { self.map($0) } : TVSampleData.albums
    }
    var songs: [TVSong] {
        hasRealLibrary ? library.visibleSongs.map { self.map($0) } : TVSampleData.songs
    }
    var artists: [TVArtist] {
        hasRealLibrary ? library.visibleArtists.map { self.map($0) } : sampleArtists
    }
    var playlists: [TVPlaylist] {
        guard hasRealLibrary else { return TVSampleData.playlists }
        let normal = library.playlists.map {
            mapPlaylist($0, kind: $0.id == MusicLibrary.likedSongsPlaylistID ? .liked : .normal)
        }
        let liked = normal.filter { $0.kind == .liked }
        let plain = normal.filter { $0.kind != .liked }
        let smart = library.smartPlaylists.map { self.mapSmart($0) }
        return liked + plain + smart
    }
    var sources: [TVSource] {
        hasRealSources ? sourcesStore.sources.map { self.map($0) } : TVSampleData.sources
    }

    // MARK: 查询

    func album(_ id: String) -> TVAlbum? { albums.first { $0.id == id } }
    func song(_ id: String) -> TVSong? { songs.first { $0.id == id } }
    func albumOf(_ song: TVSong) -> TVAlbum? { album(song.albumID) }
    func songs(forAlbum id: String) -> [TVSong] {
        hasRealLibrary ? library.songs(forAlbum: id).map { self.map($0) }
                       : TVSampleData.songs.filter { $0.albumID == id }
    }

    var recentlyPlayed: [TVSong] {
        hasRealLibrary ? library.recentlyPlayedSongs(limit: 12).map { self.map($0) }
                       : Array(TVSampleData.songs.prefix(6))
    }
    var recentlyAddedAlbums: [TVAlbum] {
        hasRealLibrary ? library.recentlyAddedAlbums(limit: 12).map { self.map($0) }
                       : Array(TVSampleData.albums.dropFirst(1))
    }
    var recommended: [TVAlbum] {
        let a = albums
        return a.count > 6 ? Array(a.suffix(6)) : a
    }

    private var sampleArtists: [TVArtist] {
        var seen = Set<String>(); var out: [TVArtist] = []
        for a in TVSampleData.albums where !seen.contains(a.artist) {
            seen.insert(a.artist)
            let cnt = TVSampleData.songs.filter { $0.artist == a.artist }.count
            out.append(TVArtist(id: a.artist, name: a.artist, tint: a.tint, tint2: a.tint2,
                                glyph: String(a.artist.prefix(1)), songCount: max(cnt, 1)))
        }
        return out
    }

    func isLiked(_ id: String) -> Bool { localLiked.contains(id) }
    func toggleLiked(_ id: String) {
        if localLiked.contains(id) { localLiked.remove(id) } else { localLiked.insert(id) }
    }

    // MARK: 真实模型 → TV view-model 映射
    //
    // tvOS 暂未同步封面图(artwork 缓存在扫描设备本地),所以封面用「按 id 派生的
    // 渐变 + 首字」程序化绘制;标题/艺术家/年份等元数据都是真实的。

    private func map(_ a: Album) -> TVAlbum {
        let (t1, t2) = Self.tint(a.id.isEmpty ? a.title : a.id)
        return TVAlbum(id: a.id, title: a.title, artist: a.artistName ?? "未知艺术家",
                       year: a.year ?? 0, tint: t1, tint2: t2, glyph: Self.glyph(a.title))
    }
    private func map(_ s: Song) -> TVSong {
        TVSong(id: s.id, albumID: s.albumID ?? "", title: s.title,
               artist: s.artistName ?? "未知艺术家", duration: s.duration,
               format: s.fileFormat.displayName, bitrate: s.bitRate ?? 0,
               sampleRate: Double(s.sampleRate ?? 0) / 1000,
               sourceID: s.sourceID, plays: 0, liked: localLiked.contains(s.id))
    }
    private func map(_ a: Artist) -> TVArtist {
        let (t1, t2) = Self.tint(a.id.isEmpty ? a.name : a.id)
        return TVArtist(id: a.id, name: a.name, tint: t1, tint2: t2,
                        glyph: Self.glyph(a.name), songCount: a.songCount)
    }
    private func mapPlaylist(_ p: Playlist, kind: TVPlaylistKind) -> TVPlaylist {
        let s = library.songs(forPlaylist: p.id)
        return TVPlaylist(id: p.id, name: p.name, kind: kind,
                          count: s.count, coverAlbumID: s.first?.albumID ?? "")
    }
    private func mapSmart(_ sp: SmartPlaylist) -> TVPlaylist {
        TVPlaylist(id: sp.id, name: sp.name, kind: .smart, count: 0, coverAlbumID: "")
    }
    private func map(_ s: MusicSource) -> TVSource {
        let cnt = hasRealLibrary ? library.visibleSongs.filter { $0.sourceID == s.id }.count : s.songCount
        let (c, _) = Self.tint(s.id)
        return TVSource(id: s.id, name: s.name, type: s.type.rawValue,
                        host: s.host ?? s.basePath ?? s.type.displayName,
                        status: s.isEnabled ? .connected : .disabled, songs: cnt, color: c)
    }

    /// 由字符串确定性派生封面渐变两端色。
    private static func tint(_ seed: String) -> (Color, Color) {
        var h: UInt64 = 5381
        for b in seed.utf8 { h = (h &* 33) &+ UInt64(b) }
        let hue = Double(h % 360) / 360.0
        return (Color(hue: hue, saturation: 0.45, brightness: 0.55),
                Color(hue: hue, saturation: 0.62, brightness: 0.22))
    }
    private static func glyph(_ s: String) -> String {
        let t = s.trimmingCharacters(in: .whitespacesAndNewlines)
        return t.isEmpty ? "♪" : String(t.prefix(1))
    }

    // MARK: 启动引导(从 iCloud 拉取快照并重载真实曲库)

    func bootstrap() async {
        await LibrarySnapshotSync.shared.download()
        library.reloadFromDisk()
        sourcesStore.reloadFromDisk()
    }

    // MARK: 歌词

    /// 当前播放时间所在的歌词行索引。
    var currentLyricIndex: Int {
        var idx = 0
        for (i, l) in lyrics.enumerated() where l.time <= nowPlaying.currentTime { idx = i }
        return idx
    }
    /// 当前行内逐字进度 0...1。
    var currentLyricProgress: Double {
        let i = currentLyricIndex
        guard i < lyrics.count else { return 0 }
        let start = lyrics[i].time
        let end = i + 1 < lyrics.count ? lyrics[i + 1].time : start + 3
        return max(0, min(1, (nowPlaying.currentTime - start) / max(0.5, end - start)))
    }

    // MARK: 播放控制(原型 — 只动本地状态)

    func togglePlayPause() { isPlaying.toggle() }
    func tick(_ dt: Double) {
        guard isPlaying else { return }
        nowPlaying.currentTime += dt
        if nowPlaying.currentTime >= nowPlaying.duration {
            nowPlaying.currentTime = 0   // 循环，让预览持续动起来
        }
    }
}

// MARK: - 样例数据

enum TVSampleData {
    static let albums: [TVAlbum] = [
        .init(id: "a01", title: "七里香", artist: "周杰伦", year: 2004, tint: Color(hex: "#c9a37a"), tint2: Color(hex: "#5e3a22"), glyph: "七"),
        .init(id: "a02", title: "U-87", artist: "陈奕迅", year: 2005, tint: Color(hex: "#264a6e"), tint2: Color(hex: "#0e1d2c"), glyph: "U"),
        .init(id: "a03", title: "The Dark Side of the Moon", artist: "Pink Floyd", year: 1973, tint: Color(hex: "#1a1a1a"), tint2: Color(hex: "#d94f3a"), glyph: "◭"),
        .init(id: "a04", title: "Hotel California", artist: "Eagles", year: 1976, tint: Color(hex: "#b87333"), tint2: Color(hex: "#3b1d0b"), glyph: "H"),
        .init(id: "a05", title: "Le Quattro Stagioni", artist: "Antonio Vivaldi · I Musici", year: 1969, tint: Color(hex: "#3a5a3a"), tint2: Color(hex: "#1a2a18"), glyph: "𝄞"),
        .init(id: "a06", title: "后青春期的诗", artist: "五月天", year: 2008, tint: Color(hex: "#5da3d9"), tint2: Color(hex: "#1d3c5b"), glyph: "诗"),
        .init(id: "a07", title: "IV", artist: "Led Zeppelin", year: 1971, tint: Color(hex: "#8a6a3a"), tint2: Color(hex: "#2a1d0a"), glyph: "IV"),
        .init(id: "a08", title: "淡淡幽情", artist: "邓丽君", year: 1983, tint: Color(hex: "#d99fbb"), tint2: Color(hex: "#5e2a44"), glyph: "丽"),
        .init(id: "a09", title: "寓言", artist: "王菲", year: 2000, tint: Color(hex: "#7c5db8"), tint2: Color(hex: "#2e1d54"), glyph: "寓"),
        .init(id: "a10", title: "Symphony No. 9", artist: "Ludwig van Beethoven · BPO", year: 1963, tint: Color(hex: "#8a1d1d"), tint2: Color(hex: "#2a0a0a"), glyph: "IX"),
        .init(id: "a11", title: "Kind of Blue", artist: "Miles Davis", year: 1959, tint: Color(hex: "#3a6b8c"), tint2: Color(hex: "#0e1d2c"), glyph: "♭"),
        .init(id: "a12", title: "范特西", artist: "周杰伦", year: 2001, tint: Color(hex: "#a6541d"), tint2: Color(hex: "#3a1808"), glyph: "范"),
        .init(id: "a13", title: "OK Computer", artist: "Radiohead", year: 1997, tint: Color(hex: "#7d8da0"), tint2: Color(hex: "#1d2030"), glyph: "○"),
        .init(id: "a14", title: "黑色柳丁", artist: "陶喆", year: 2002, tint: Color(hex: "#3a3a3a"), tint2: Color(hex: "#c9a83a"), glyph: "柳"),
        .init(id: "a15", title: "Blue Train", artist: "John Coltrane", year: 1957, tint: Color(hex: "#1d3a6b"), tint2: Color(hex: "#0a1530"), glyph: "⊕"),
    ]

    static let songs: [TVSong] = [
        .init(id: "s01", albumID: "a02", title: "富士山下", artist: "陈奕迅", duration: 257, format: "FLAC", bitrate: 992, sampleRate: 44.1, sourceID: "nas-truenas", plays: 84, liked: true),
        .init(id: "s02", albumID: "a01", title: "七里香", artist: "周杰伦", duration: 295, format: "FLAC", bitrate: 1024, sampleRate: 44.1, sourceID: "nas-truenas", plays: 142, liked: true),
        .init(id: "s03", albumID: "a03", title: "Money", artist: "Pink Floyd", duration: 382, format: "DSD", bitrate: 5644, sampleRate: 88.2, sourceID: "nas-truenas", plays: 12, liked: false),
        .init(id: "s04", albumID: "a04", title: "Hotel California", artist: "Eagles", duration: 391, format: "FLAC", bitrate: 1018, sampleRate: 96, sourceID: "jellyfin-home", plays: 67, liked: true),
        .init(id: "s05", albumID: "a05", title: "Spring · Allegro", artist: "Antonio Vivaldi · I Musici", duration: 213, format: "FLAC", bitrate: 1411, sampleRate: 192, sourceID: "webdav-music", plays: 31, liked: false),
        .init(id: "s06", albumID: "a06", title: "突然好想你", artist: "五月天", duration: 290, format: "AAC", bitrate: 256, sampleRate: 44.1, sourceID: "aliyun-pan", plays: 96, liked: true),
        .init(id: "s07", albumID: "a07", title: "Black Dog", artist: "Led Zeppelin", duration: 296, format: "FLAC", bitrate: 1024, sampleRate: 96, sourceID: "nas-truenas", plays: 23, liked: false),
        .init(id: "s08", albumID: "a08", title: "但愿人长久", artist: "邓丽君", duration: 234, format: "FLAC", bitrate: 850, sampleRate: 44.1, sourceID: "webdav-music", plays: 178, liked: true),
        .init(id: "s09", albumID: "a09", title: "寓言", artist: "王菲", duration: 308, format: "FLAC", bitrate: 920, sampleRate: 44.1, sourceID: "aliyun-pan", plays: 54, liked: false),
        .init(id: "s10", albumID: "a10", title: "Ode to Joy", artist: "Beethoven · BPO", duration: 1432, format: "FLAC", bitrate: 1411, sampleRate: 192, sourceID: "plex-media", plays: 18, liked: false),
        .init(id: "s11", albumID: "a11", title: "So What", artist: "Miles Davis", duration: 545, format: "FLAC", bitrate: 1024, sampleRate: 96, sourceID: "nas-truenas", plays: 41, liked: false),
        .init(id: "s12", albumID: "a12", title: "简单爱", artist: "周杰伦", duration: 285, format: "FLAC", bitrate: 980, sampleRate: 44.1, sourceID: "nas-truenas", plays: 203, liked: true),
        .init(id: "s13", albumID: "a13", title: "Paranoid Android", artist: "Radiohead", duration: 386, format: "FLAC", bitrate: 1024, sampleRate: 96, sourceID: "jellyfin-home", plays: 38, liked: false),
        .init(id: "s14", albumID: "a14", title: "黑色柳丁", artist: "陶喆", duration: 274, format: "FLAC", bitrate: 960, sampleRate: 44.1, sourceID: "webdav-music", plays: 27, liked: false),
        .init(id: "s15", albumID: "a15", title: "Moment’s Notice", artist: "John Coltrane", duration: 558, format: "FLAC", bitrate: 1024, sampleRate: 96, sourceID: "nas-truenas", plays: 19, liked: false),
        .init(id: "s16", albumID: "a01", title: "蒲公英的约定", artist: "周杰伦", duration: 264, format: "FLAC", bitrate: 992, sampleRate: 44.1, sourceID: "nas-truenas", plays: 88, liked: false),
        .init(id: "s17", albumID: "a02", title: "十年", artist: "陈奕迅", duration: 205, format: "FLAC", bitrate: 990, sampleRate: 44.1, sourceID: "nas-truenas", plays: 251, liked: true),
        .init(id: "s18", albumID: "a06", title: "倔强", artist: "五月天", duration: 269, format: "AAC", bitrate: 256, sampleRate: 44.1, sourceID: "aliyun-pan", plays: 134, liked: true),
    ]

    static let playlists: [TVPlaylist] = [
        .init(id: "pl-liked", name: "我喜欢的", kind: .liked, count: 247, coverAlbumID: "a01"),
        .init(id: "pl-late", name: "深夜驾驶", kind: .normal, count: 34, coverAlbumID: "a02"),
        .init(id: "pl-study", name: "专注 · 古典", kind: .normal, count: 58, coverAlbumID: "a05"),
        .init(id: "pl-rock", name: "70s Classic Rock", kind: .normal, count: 91, coverAlbumID: "a04"),
        .init(id: "pl-jay", name: "周杰伦 · 全集", kind: .normal, count: 88, coverAlbumID: "a01"),
        .init(id: "pl-new", name: "最近新增 · 智能", kind: .smart, count: 42, coverAlbumID: "a09"),
        .init(id: "pl-high", name: "HiRes · 智能", kind: .smart, count: 318, coverAlbumID: "a10"),
        .init(id: "pl-cantopop", name: "粤语金曲", kind: .normal, count: 124, coverAlbumID: "a02"),
    ]

    static let sources: [TVSource] = [
        .init(id: "nas-truenas", name: "TrueNAS · 主库", type: "smb", host: "10.0.0.4 / Music", status: .connected, songs: 8412, color: Color(hex: "#4d7a4d")),
        .init(id: "jellyfin-home", name: "Jellyfin · 客厅", type: "jellyfin", host: "jelly.lan", status: .connected, songs: 2104, color: Color(hex: "#5d7da8")),
        .init(id: "webdav-music", name: "群晖 WebDAV", type: "webdav", host: "syno.local/music", status: .scanning, songs: 1208, color: Color(hex: "#4d6a8a")),
        .init(id: "aliyun-pan", name: "阿里云盘", type: "aliyun", host: "云盘 · /Music/Pop", status: .connected, songs: 412, color: Color(hex: "#d97757")),
        .init(id: "plex-media", name: "Plex · 工作室", type: "plex", host: "plex.lan:32400", status: .connected, songs: 1856, color: Color(hex: "#e5a00d")),
        .init(id: "sftp-archive", name: "SFTP · 归档", type: "sftp", host: "archive.home:22", status: .authFailed, songs: 0, color: Color(hex: "#a05050")),
        .init(id: "baidu-cloud", name: "百度网盘", type: "baidu", host: "云盘 · /我的音乐", status: .connected, songs: 256, color: Color(hex: "#226dde")),
        .init(id: "apple-music", name: "Apple Music", type: "apple", host: "用户库", status: .connected, songs: 532, color: Color(hex: "#fa233b")),
    ]

    static let upNextIDs = ["s01", "s12", "s09", "s06", "s16", "s14", "s04", "s11"]

    static let nowPlaying = TVNowPlaying(
        title: "水调歌头·明月几时有", artist: "邓丽君", album: "淡淡幽情", albumID: "a08",
        tint: Color(hex: "#d99fbb"), tint2: Color(hex: "#5e2a44"), glyph: "丽",
        duration: 252, currentTime: 38.4, format: "FLAC", bitrate: 988, sampleRate: 44.1,
        sourcePath: "TrueNAS · /music/Teresa Teng/淡淡幽情")

    // 苏轼《水调歌头·明月几时有》— 公有领域(1076)。逐字时间由 d(秒) 累加得到。
    static let lyrics: [TVLyricLine] = [
        line(0.0, "明月几时有", [("明",0.5),("月",0.5),("几",0.5),("时",0.5),("有",0.8)], "When will the bright moon appear?"),
        line(3.0, "把酒问青天", [("把",0.4),("酒",0.5),("问",0.5),("青",0.5),("天",0.9)], "Wine cup in hand, I ask the blue sky."),
        line(6.5, "不知天上宫阙", [("不",0.4),("知",0.4),("天",0.5),("上",0.5),("宫",0.5),("阙",0.9)], "I wonder, in the celestial palace,"),
        line(10.0, "今夕是何年", [("今",0.4),("夕",0.5),("是",0.4),("何",0.5),("年",1.0)], "What year it must be tonight."),
        line(14.0, "我欲乘风归去", [("我",0.4),("欲",0.4),("乘",0.4),("风",0.5),("归",0.5),("去",0.9)], "I long to ride the wind home,"),
        line(18.0, "又恐琼楼玉宇", [("又",0.4),("恐",0.5),("琼",0.5),("楼",0.5),("玉",0.5),("宇",0.9)], "Yet fear those crystal towers, jade halls,"),
        line(22.0, "高处不胜寒", [("高",0.4),("处",0.5),("不",0.4),("胜",0.5),("寒",1.0)], "So cold up there, beyond endurance."),
        line(26.0, "起舞弄清影", [("起",0.5),("舞",0.5),("弄",0.5),("清",0.5),("影",0.8)], "I rise to dance with my own shadow —"),
        line(30.0, "何似在人间", [("何",0.4),("似",0.5),("在",0.4),("人",0.5),("间",1.0)], "Why dwell among mortals at all?"),
        line(34.5, "转朱阁，低绮户，照无眠", [("转",0.4),("朱",0.4),("阁",0.6),("低",0.4),("绮",0.4),("户",0.6),("照",0.4),("无",0.4),("眠",1.0)], "Around vermilion pavilions, through silken windows, it shines on the sleepless."),
        line(40.0, "不应有恨", [("不",0.4),("应",0.5),("有",0.5),("恨",0.9)], "It should bear us no grudge —"),
        line(43.5, "何事长向别时圆", [("何",0.4),("事",0.4),("长",0.5),("向",0.4),("别",0.5),("时",0.4),("圆",1.0)], "Why is it always full when we are apart?"),
        line(48.0, "人有悲欢离合", [("人",0.4),("有",0.4),("悲",0.5),("欢",0.5),("离",0.5),("合",0.9)], "People have sorrow, joy, parting and reunion,"),
        line(52.5, "月有阴晴圆缺", [("月",0.4),("有",0.4),("阴",0.5),("晴",0.5),("圆",0.5),("缺",0.9)], "The moon has shadow, brightness, fullness and wane —"),
        line(57.0, "此事古难全", [("此",0.4),("事",0.4),("古",0.5),("难",0.5),("全",1.2)], "Such matters have ever been hard to perfect."),
        line(61.5, "但愿人长久", [("但",0.4),("愿",0.5),("人",0.4),("长",0.5),("久",1.0)], "So long as we live long lives,"),
        line(65.5, "千里共婵娟", [("千",0.4),("里",0.5),("共",0.4),("婵",0.5),("娟",1.4)], "A thousand miles apart, we share the same moon."),
    ]

    private static func line(_ t: Double, _ text: String, _ syll: [(String, Double)], _ tr: String) -> TVLyricLine {
        TVLyricLine(time: t, text: text, syllables: syll.map { TVSyllable(w: $0.0, d: $0.1) }, translation: tr)
    }
}
#endif
