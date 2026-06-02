#if os(tvOS)
import SwiftUI

/// tvOS 搜索 — 左列查询框 + 屏幕键盘,右列实时结果(对应 TVSearchArtboard)。
struct TVSearchView: View {
    @Environment(TVStore.self) private var store
    var openPlayer: () -> Void = {}

    @State private var query: String = "周杰伦"
    @State private var caretOn = true

    private let keys: [String] = {
        var k = (0..<26).map { String(UnicodeScalar(65 + $0)!) }
        k += (0...9).map(String.init)
        k += ["邓", "丽", "君", "周", "杰", "伦", "陈", "奕", "迅", "王", "菲"]
        return k
    }()

    private var matchedSongs: [TVSong] {
        let q = query.trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty else { return [] }
        return store.songs.filter {
            $0.title.localizedCaseInsensitiveContains(q) || $0.artist.localizedCaseInsensitiveContains(q)
        }
    }
    private var topArtist: TVArtist? {
        let q = query.trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty else { return nil }
        return store.artists.first { $0.name.localizedCaseInsensitiveContains(q) }
    }
    private var suggestions: [String] {
        let q = query.trimmingCharacters(in: .whitespaces)
        let names = store.artists.map(\.name)
        let hits = q.isEmpty ? names : names.filter { $0.localizedCaseInsensitiveContains(q) }
        return Array((hits.isEmpty ? names : hits).prefix(4))
    }

    var body: some View {
        ZStack {
            TVAmbientBackdrop(tint: store.album("a08")?.tint ?? TVColor.brand,
                              tint2: store.album("a08")?.tint2 ?? .black, strength: 0.4)
            HStack(alignment: .top, spacing: 60) {
                leftColumn
                rightColumn
            }
            .tvPage()
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 0.55).repeatForever(autoreverses: true)) { caretOn = false }
        }
    }

    // MARK: 左列 — 键盘

    private var leftColumn: some View {
        VStack(alignment: .leading, spacing: 0) {
            TVEyebrow(text: "搜索")
                .padding(.bottom, 16)

            HStack(spacing: 18) {
                Image(systemName: "magnifyingglass").font(.system(size: 26, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.55))
                Text(query.isEmpty ? " " : query)
                    .font(.system(size: 36, weight: .semibold)).tracking(4).foregroundStyle(.white)
                Rectangle().fill(TVColor.brand).frame(width: 3, height: 38).opacity(caretOn ? 1 : 0)
                Spacer(minLength: 0)
                TVFocusButton(radius: 28, accent: .white, scale: 1.06, lift: 0,
                              action: { query = "" }) { _ in
                    Text("清除").font(.system(size: 16, weight: .medium)).foregroundStyle(.white)
                        .padding(.horizontal, 18).padding(.vertical, 8)
                        .background(.white.opacity(0.16), in: Capsule())
                }
            }
            .padding(.horizontal, 28).padding(.vertical, 18)
            .background(.white.opacity(0.10), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .padding(.bottom, 24)

            Text("建议").font(.system(size: 18)).foregroundStyle(TVColor.textMuted)
                .padding(.bottom, 10)
            VStack(spacing: 4) {
                ForEach(suggestions, id: \.self) { s in
                    TVFocusButton(radius: 10, accent: .white, scale: 1.02, lift: 0,
                                  action: { query = s }) { _ in
                        HStack {
                            Text(s).font(.system(size: 22)).foregroundStyle(.white)
                            Spacer()
                        }
                        .padding(.horizontal, 20).padding(.vertical, 14)
                        .frame(maxWidth: .infinity)
                        .background(.white.opacity(0.06))
                    }
                }
            }
            .padding(.bottom, 28)

            Text("键盘 — 方向键移动 · 选中追加").font(.system(size: 18)).foregroundStyle(TVColor.textMuted)
                .padding(.bottom, 10)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(Array(keys.enumerated()), id: \.offset) { _, k in
                        TVFocusButton(radius: 8, accent: .white, scale: 1.22, lift: 6,
                                      action: { query += k }) { focused in
                            Text(k)
                                .font(.system(size: 22, weight: .semibold))
                                .foregroundStyle(focused ? Color(hex: "#1f1c19") : .white)
                                .frame(width: 50, height: 50)
                                .background(focused ? AnyShapeStyle(.white)
                                                    : AnyShapeStyle(Color.white.opacity(0.10)))
                        }
                    }
                }
                .padding(.vertical, 12).padding(.horizontal, 12)
            }
            .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 14, style: .continuous))

            HStack(spacing: 14) {
                Text("按住 Siri 按钮可语音搜索")
                Text("·")
                Text("iPhone 远程键盘弹窗")
            }
            .font(.system(size: 14)).foregroundStyle(TVColor.textGhost)
            .padding(.top, 14)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: 右列 — 结果

    private var rightColumn: some View {
        VStack(alignment: .leading, spacing: 0) {
            TVEyebrow(text: "顶部匹配").padding(.bottom, 16)
            if let artist = topArtist {
                TVFocusButton(radius: 16, scale: 1.02, lift: 4, action: openPlayer) { _ in
                    HStack(spacing: 20) {
                        TVCoverArt(tint: artist.tint, tint2: artist.tint2, glyph: artist.glyph,
                                   size: 92, radius: 46)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(artist.name).font(.system(size: 32, weight: .bold)).foregroundStyle(.white)
                            Text("艺术家 · \(artist.songCount) 首")
                                .font(.system(size: 18)).foregroundStyle(TVColor.textFaint)
                        }
                        Spacer(minLength: 0)
                    }
                    .padding(20).frame(maxWidth: .infinity)
                    .background(.white.opacity(0.06))
                }
            } else {
                Text("输入以搜索曲库").font(.system(size: 22)).foregroundStyle(TVColor.textFaint)
            }

            TVEyebrow(text: "歌曲").padding(.top, 28).padding(.bottom, 16)
            VStack(spacing: 6) {
                ForEach(matchedSongs.prefix(6)) { song in
                    TVSearchSongRow(song: song, action: openPlayer)
                }
                if matchedSongs.isEmpty {
                    Text("没有匹配的歌曲").font(.system(size: 18)).foregroundStyle(TVColor.textGhost)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct TVSearchSongRow: View {
    @Environment(TVStore.self) private var store
    let song: TVSong
    var action: () -> Void = {}

    var body: some View {
        let album = store.albumOf(song)
        TVFocusButton(radius: 10, scale: 1.02, lift: 0, action: action) { _ in
            HStack(spacing: 16) {
                TVCoverArt(tint: album?.tint ?? TVColor.brand,
                           tint2: album?.tint2 ?? .black,
                           glyph: album?.glyph ?? "♪", size: 56, radius: 6)
                VStack(alignment: .leading, spacing: 2) {
                    Text(song.title).font(.system(size: 22, weight: .semibold)).foregroundStyle(.white)
                    Text("\(song.artist) · \(store.albumOf(song)?.title ?? "")")
                        .font(.system(size: 16)).foregroundStyle(TVColor.textFaint).lineLimit(1)
                }
                Spacer(minLength: 0)
                Image(systemName: "play.fill").font(.system(size: 18)).foregroundStyle(TVColor.textFaint)
            }
            .padding(14).frame(maxWidth: .infinity)
            .background(.white.opacity(0.06))
        }
    }
}
#endif
