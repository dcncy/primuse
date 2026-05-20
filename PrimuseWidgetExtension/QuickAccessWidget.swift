import SwiftUI
import WidgetKit
import PrimuseKit

struct QuickAccessProvider: TimelineProvider {
    func placeholder(in context: Context) -> QuickAccessEntry {
        QuickAccessEntry(date: Date(), recentAlbums: Self.demoAlbums)
    }

    func getSnapshot(in context: Context, completion: @escaping (QuickAccessEntry) -> Void) {
        // 画廊预览喂 demo 数据,真实使用走 App Group。同 NowPlayingProvider。
        if context.isPreview {
            completion(QuickAccessEntry(date: Date(), recentAlbums: Self.demoAlbums))
        } else {
            completion(QuickAccessEntry(date: Date(), recentAlbums: RecentAlbumsStore.load()))
        }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<QuickAccessEntry>) -> Void) {
        let entry = QuickAccessEntry(date: Date(), recentAlbums: RecentAlbumsStore.load())
        let nextUpdate = Calendar.current.date(byAdding: .hour, value: 1, to: Date())!
        completion(Timeline(entries: [entry], policy: .after(nextUpdate)))
    }

    /// 画廊预览用的假专辑列表 —— 5 张,覆盖 medium (头图 + 3 缩略) 和
    /// large (头图 + 4 缩略) 两种 size 的需要。封面留 nil,WidgetCoverImageView
    /// 会落回 placeholderGradient 渐变占位。
    private static let demoAlbums: [RecentAlbumEntry] = [
        RecentAlbumEntry(id: "demo-1", title: "Double Fantasy", artistName: "John Lennon", coverImageName: nil),
        RecentAlbumEntry(id: "demo-2", title: "OK Computer", artistName: "Radiohead", coverImageName: nil),
        RecentAlbumEntry(id: "demo-3", title: "Kind of Blue", artistName: "Miles Davis", coverImageName: nil),
        RecentAlbumEntry(id: "demo-4", title: "Nevermind", artistName: "Nirvana", coverImageName: nil),
        RecentAlbumEntry(id: "demo-5", title: "Rumours", artistName: "Fleetwood Mac", coverImageName: nil),
    ]
}

struct QuickAccessEntry: TimelineEntry {
    let date: Date
    let recentAlbums: [RecentAlbumEntry]
}

struct QuickAccessWidget: Widget {
    let kind = "QuickAccessWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: QuickAccessProvider()) { entry in
            QuickAccessWidgetView(entry: entry)
                .containerBackground(for: .widget) { Color.clear }
        }
        .contentMarginsDisabled()
        .configurationDisplayName("最近播放")
        .description("把最近播放的专辑直接放到桌面上")
        .supportedFamilies([.systemMedium, .systemLarge])
    }
}

struct QuickAccessWidgetView: View {
    let entry: QuickAccessEntry

    @Environment(\.widgetFamily) private var family

    var body: some View {
        if entry.recentAlbums.isEmpty {
            switch family {
            case .systemLarge: LargeQuickAccessEmptyState()
            default: MediumQuickAccessEmptyState()
            }
        } else {
            switch family {
            case .systemLarge: LargeQuickAccessView(albums: entry.recentAlbums)
            default: MediumQuickAccessView(albums: entry.recentAlbums)
            }
        }
    }
}

// MARK: - Medium / Large
//
// 设计目标:
// - 主专辑封面占左侧主导地位, 不再加 pill / eyebrow / "继续上次的氛围" 这类
//   装饰文字
// - 副专辑用最朴素的小方格 + 单行字, 而不是套 panel 边框
// - 背景用第一张专辑的封面模糊扩散, 占位图改为多色唱片感渐变

private struct MediumQuickAccessView: View {
    let albums: [RecentAlbumEntry]

    private var featured: RecentAlbumEntry { albums[0] }
    private var others: [RecentAlbumEntry] { Array(albums.dropFirst().prefix(3)) }

    var body: some View {
        GeometryReader { geometry in
            let coverSide = min(112, max(88, geometry.size.height - 32))

            ZStack {
                RecentAlbumCoverView(entry: featured, cornerRadius: 0, placeholderIndex: 0)
                    .scaleEffect(1.18)
                    .blur(radius: 30)
                    .overlay(Color.black.opacity(0.42))

                HStack(spacing: 14) {
                    RecentAlbumCoverView(entry: featured, cornerRadius: 12, placeholderIndex: 0)
                        .frame(width: coverSide, height: coverSide)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("最近播放")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.55))
                            .textCase(.uppercase)
                            .tracking(0.6)
                        Text(featured.title)
                            .font(.system(size: 17, weight: .bold))
                            .foregroundStyle(.white)
                            .lineLimit(2)
                            .minimumScaleFactor(0.86)
                        Text(featured.artistName)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.white.opacity(0.70))
                            .lineLimit(1)

                        Spacer(minLength: 4)

                        HStack(spacing: 8) {
                            ForEach(Array(others.enumerated()), id: \.element.id) { i, album in
                                RecentAlbumCoverView(entry: album, cornerRadius: 6, placeholderIndex: i + 1)
                                    .frame(width: 34, height: 34)
                            }
                            Spacer(minLength: 0)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(16)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

private struct LargeQuickAccessView: View {
    let albums: [RecentAlbumEntry]

    private var featured: RecentAlbumEntry { albums[0] }
    private var others: [RecentAlbumEntry] { Array(albums.dropFirst().prefix(4)) }

    var body: some View {
        GeometryReader { geometry in
            let contentWidth = max(0, geometry.size.width - 36)
            let coverSide = min(contentWidth, max(132, geometry.size.height * 0.48))
            let thumbSide = min(58, max(38, (contentWidth - 30) / 4))

            ZStack {
                RecentAlbumCoverView(entry: featured, cornerRadius: 0, placeholderIndex: 0)
                    .scaleEffect(1.18)
                    .blur(radius: 38)
                    .overlay(Color.black.opacity(0.46))

                VStack(alignment: .leading, spacing: 10) {
                    Text("最近播放")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.55))
                        .textCase(.uppercase)
                        .tracking(0.6)

                    RecentAlbumCoverView(entry: featured, cornerRadius: 14, placeholderIndex: 0)
                        .frame(width: coverSide, height: coverSide)
                        .frame(maxWidth: .infinity, alignment: .center)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(featured.title)
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(.white)
                            .lineLimit(1)
                            .minimumScaleFactor(0.86)
                        Text(featured.artistName)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.white.opacity(0.70))
                            .lineLimit(1)
                    }

                    Spacer(minLength: 0)

                    HStack(spacing: 10) {
                        ForEach(Array(others.enumerated()), id: \.element.id) { i, album in
                            RecentAlbumCoverView(entry: album, cornerRadius: 8, placeholderIndex: i + 1)
                                .frame(width: thumbSide, height: thumbSide)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(18)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

// MARK: - 空状态 (极简)

private struct MediumQuickAccessEmptyState: View {
    var body: some View {
        WidgetCanvas(padding: 18) {
            HStack(spacing: 16) {
                WidgetEmptyStateIcon(systemName: "square.stack.fill", size: 64)
                VStack(alignment: .leading, spacing: 4) {
                    Text("暂无最近播放")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(.white)
                    Text("开始播放后,最近专辑会出现在这里")
                        .font(.system(size: 12))
                        .foregroundStyle(.white.opacity(0.62))
                        .lineLimit(2)
                }
                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        }
    }
}

private struct LargeQuickAccessEmptyState: View {
    var body: some View {
        WidgetCanvas(padding: 22) {
            VStack(alignment: .leading, spacing: 14) {
                WidgetEmptyStateIcon(systemName: "square.stack.fill", size: 78)
                VStack(alignment: .leading, spacing: 6) {
                    Text("暂无最近播放")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundStyle(.white)
                    Text("最近播放过的专辑会自动同步到桌面")
                        .font(.system(size: 13))
                        .foregroundStyle(.white.opacity(0.62))
                        .lineLimit(3)
                }
                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        }
    }
}
