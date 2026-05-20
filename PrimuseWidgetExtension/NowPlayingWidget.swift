import SwiftUI
import WidgetKit
import PrimuseKit

struct NowPlayingProvider: TimelineProvider {
    func placeholder(in context: Context) -> NowPlayingEntry {
        NowPlayingEntry(date: Date(), state: Self.demoState)
    }

    func getSnapshot(in context: Context, completion: @escaping (NowPlayingEntry) -> Void) {
        // 系统 widget 画廊用 isPreview=true 调这里 —— 用户还没添加 widget,
        // 实际 PlaybackState 大概率是空, 渲染"尚未播放"空状态会让画廊看起来
        // 像功能没做完。预览阶段一律喂 demo 数据,真实使用时才走 App Group。
        if context.isPreview {
            completion(NowPlayingEntry(date: Date(), state: Self.demoState))
        } else {
            completion(NowPlayingEntry(date: Date(), state: PlaybackState.load()))
        }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<NowPlayingEntry>) -> Void) {
        let entry = NowPlayingEntry(date: Date(), state: PlaybackState.load())
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 5, to: Date())!
        completion(Timeline(entries: [entry], policy: .after(nextUpdate)))
    }

    /// 画廊预览 / placeholder 用的假数据 —— 让 widget 在用户挑选时就能
    /// 看到"长大后是啥样",而不是空 state。
    private static let demoState = PlaybackState(
        currentSongID: "demo",
        songTitle: "Beautiful Boy",
        artistName: "John Lennon",
        albumTitle: "Double Fantasy",
        coverArtData: nil,
        coverImageName: nil,
        isPlaying: true,
        currentTime: 88,
        duration: 248,
        queueSongIDs: ["demo-2", "demo-3", "demo-4"]
    )
}

struct NowPlayingEntry: TimelineEntry {
    let date: Date
    let state: PlaybackState?
}

struct NowPlayingWidget: Widget {
    let kind = "NowPlayingWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: NowPlayingProvider()) { entry in
            NowPlayingWidgetView(entry: entry)
                .containerBackground(for: .widget) { Color.clear }
        }
        .contentMarginsDisabled()
        .configurationDisplayName("正在播放")
        .description("在桌面、锁屏、灵动岛附近快速查看当前歌曲和播放进度")
        .supportedFamilies([
            .systemSmall, .systemMedium, .systemLarge,
            .accessoryCircular, .accessoryRectangular, .accessoryInline,
        ])
    }
}

struct NowPlayingWidgetView: View {
    let entry: NowPlayingEntry

    @Environment(\.widgetFamily) private var family

    var body: some View {
        if let state = entry.state, state.currentSongID != nil {
            switch family {
            case .systemSmall: SmallNowPlayingView(state: state)
            case .systemMedium: MediumNowPlayingView(state: state)
            case .systemLarge: LargeNowPlayingView(state: state)
            case .accessoryCircular: AccessoryCircularNowPlaying(state: state)
            case .accessoryRectangular: AccessoryRectangularNowPlaying(state: state)
            case .accessoryInline: AccessoryInlineNowPlaying(state: state)
            default: SmallNowPlayingView(state: state)
            }
        } else {
            switch family {
            case .systemSmall: SmallEmptyStateView()
            case .systemMedium: MediumEmptyStateView()
            case .systemLarge: LargeEmptyStateView()
            case .accessoryCircular: AccessoryCircularEmptyState()
            case .accessoryRectangular: AccessoryRectangularEmptyState()
            case .accessoryInline: AccessoryInlineEmptyState()
            default: SmallEmptyStateView()
            }
        }
    }
}

// MARK: - Home Screen widgets
//
// 设计目标:
// - 封面主导, 文字最少, 装饰最少
// - 单一进度条贴在底部, 极细 + 半透明白
// - 文字粗细对比强: 标题用 .bold(.body), 艺术家用 .secondary
// - 没有封面时落回多色唱片占位, 不再整块品牌紫

private struct SmallNowPlayingView: View {
    let state: PlaybackState

    var body: some View {
        ZStack {
            // 封面填满整个 widget 当背景。.scaleEffect 是 WidgetArtworkBackdrop
            // 同款手法,防止 blur 边缘露出透明。
            WidgetCoverImageView(
                coverImageName: state.coverImageName,
                cornerRadius: 0,
                placeholderIndex: 0
            )
            .scaleEffect(1.05)
            // 底部偏暗的渐变保证标题可读
            LinearGradient(
                colors: [.black.opacity(0.0), .black.opacity(0.55)],
                startPoint: .center,
                endPoint: .bottom
            )

            VStack(alignment: .leading, spacing: 6) {
                Spacer()
                Text(state.songTitle ?? "未知歌曲")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(.white)
                    .lineLimit(2)
                Text(state.artistName ?? "未知艺术家")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.white.opacity(0.78))
                    .lineLimit(1)
                ProgressLine(value: state.currentTime, total: state.duration)
                    .padding(.top, 2)
            }
            .padding(14)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct MediumNowPlayingView: View {
    let state: PlaybackState

    var body: some View {
        GeometryReader { geometry in
            let coverSide = min(112, max(88, geometry.size.height - 32))

            ZStack {
                WidgetCoverImageView(
                    coverImageName: state.coverImageName,
                    cornerRadius: 0,
                    placeholderIndex: 0
                )
                .scaleEffect(1.18)
                .blur(radius: 30)
                .overlay(Color.black.opacity(0.40))

                HStack(spacing: 16) {
                    WidgetCoverImageView(
                        coverImageName: state.coverImageName,
                        cornerRadius: 12,
                        placeholderIndex: 0
                    )
                    .frame(width: coverSide, height: coverSide)

                    VStack(alignment: .leading, spacing: 4) {
                        Spacer()
                        Text(state.songTitle ?? "未知歌曲")
                            .font(.system(size: 17, weight: .bold))
                            .foregroundStyle(.white)
                            .lineLimit(2)
                            .minimumScaleFactor(0.86)
                        Text(state.artistName ?? "未知艺术家")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.white.opacity(0.78))
                            .lineLimit(1)
                        Spacer(minLength: 0)
                        ProgressLine(value: state.currentTime, total: state.duration)
                        HStack {
                            Text(formatTime(state.currentTime))
                            Spacer()
                            Text(formatTime(state.duration))
                        }
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.55))
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(16)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

private struct LargeNowPlayingView: View {
    let state: PlaybackState

    var body: some View {
        GeometryReader { geometry in
            let contentWidth = max(0, geometry.size.width - 40)
            let coverSide = min(contentWidth, max(132, geometry.size.height * 0.52))

            ZStack {
                WidgetCoverImageView(
                    coverImageName: state.coverImageName,
                    cornerRadius: 0,
                    placeholderIndex: 0
                )
                .scaleEffect(1.18)
                .blur(radius: 36)
                .overlay(Color.black.opacity(0.42))

                VStack(spacing: 14) {
                    WidgetCoverImageView(
                        coverImageName: state.coverImageName,
                        cornerRadius: 14,
                        placeholderIndex: 0
                    )
                    .frame(width: coverSide, height: coverSide)

                    VStack(alignment: .leading, spacing: 6) {
                        Text(state.songTitle ?? "未知歌曲")
                            .font(.system(size: 21, weight: .bold))
                            .foregroundStyle(.white)
                            .lineLimit(2)
                            .minimumScaleFactor(0.82)
                        Text(state.artistName ?? "未知艺术家")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(.white.opacity(0.78))
                            .lineLimit(1)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    VStack(spacing: 6) {
                        ProgressLine(value: state.currentTime, total: state.duration)
                        HStack {
                            Text(formatTime(state.currentTime))
                            Spacer()
                            Text(formatTime(state.duration))
                        }
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.55))
                    }
                }
                .padding(20)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

// MARK: - 空状态 (极简: 单 icon + 一行)

private struct SmallEmptyStateView: View {
    var body: some View {
        WidgetCanvas(padding: 14) {
            VStack(alignment: .leading, spacing: 8) {
                Spacer()
                WidgetEmptyStateIcon(systemName: "music.note", size: 42)
                Text("尚未播放")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
                Text("打开猿音继续")
                    .font(.system(size: 11))
                    .foregroundStyle(.white.opacity(0.62))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        }
    }
}

private struct MediumEmptyStateView: View {
    var body: some View {
        WidgetCanvas(padding: 18) {
            HStack(spacing: 16) {
                WidgetEmptyStateIcon(systemName: "music.note", size: 64)
                VStack(alignment: .leading, spacing: 4) {
                    Text("尚未播放")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(.white)
                    Text("打开猿音继续上次的旋律")
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

private struct LargeEmptyStateView: View {
    var body: some View {
        WidgetCanvas(padding: 22) {
            VStack(alignment: .leading, spacing: 14) {
                WidgetEmptyStateIcon(systemName: "music.note", size: 78)
                VStack(alignment: .leading, spacing: 6) {
                    Text("尚未播放")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundStyle(.white)
                    Text("连接你的音乐源,这里会显示当前歌曲和播放进度。")
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

// MARK: - Lock Screen / Accessory families
//
// iOS 16+ 锁屏小组件渲染时,SwiftUI 自动套一个 `widgetAccentable` / 渲染模式
// (full color / accented / vibrant)。这里所有的图标 / 文字都用系统材质,
// 让 vibrant 渲染模式下穿透时颜色协调,不要硬塞 RGB。

private struct AccessoryCircularNowPlaying: View {
    let state: PlaybackState

    var body: some View {
        let total = max(state.duration, 0.01)
        let progress = state.duration > 0
            ? max(0, min(1, state.currentTime / total))
            : 0
        ZStack {
            if state.duration > 0 {
                Gauge(value: progress) {
                    Image(systemName: state.isPlaying ? "waveform" : "pause.fill")
                }
                .gaugeStyle(.accessoryCircularCapacity)
            } else {
                Image(systemName: state.isPlaying ? "waveform" : "pause.fill")
                    .font(.system(size: 22, weight: .semibold))
            }
        }
        .widgetAccentable()
        .containerBackground(for: .widget) { Color.clear }
    }
}

private struct AccessoryRectangularNowPlaying: View {
    let state: PlaybackState

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            HStack(spacing: 4) {
                Image(systemName: state.isPlaying ? "waveform" : "pause.fill")
                    .font(.system(size: 11, weight: .semibold))
                    .widgetAccentable()
                Text(state.songTitle ?? "未知歌曲")
                    .font(.headline)
                    .lineLimit(1)
            }
            Text(state.artistName ?? "未知艺术家")
                .font(.caption2)
                .lineLimit(1)
            if let album = state.albumTitle, !album.isEmpty {
                Text(album)
                    .font(.caption2)
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .containerBackground(for: .widget) { Color.clear }
    }
}

private struct AccessoryInlineNowPlaying: View {
    let state: PlaybackState

    var body: some View {
        let title = state.songTitle ?? "未知歌曲"
        let artist = state.artistName ?? ""
        let symbol = state.isPlaying ? "play.fill" : "pause.fill"
        Label {
            if artist.isEmpty {
                Text(title)
            } else {
                Text("\(title) — \(artist)")
            }
        } icon: {
            Image(systemName: symbol)
        }
        .containerBackground(for: .widget) { Color.clear }
    }
}

private struct AccessoryCircularEmptyState: View {
    var body: some View {
        Image(systemName: "music.note")
            .font(.system(size: 22, weight: .semibold))
            .widgetAccentable()
            .containerBackground(for: .widget) { Color.clear }
    }
}

private struct AccessoryRectangularEmptyState: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            HStack(spacing: 4) {
                Image(systemName: "music.note")
                    .font(.system(size: 11, weight: .semibold))
                    .widgetAccentable()
                Text("猿音")
                    .font(.headline)
            }
            Text("点击开始播放")
                .font(.caption2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .containerBackground(for: .widget) { Color.clear }
    }
}

private struct AccessoryInlineEmptyState: View {
    var body: some View {
        Label("猿音 — 暂未播放", systemImage: "music.note")
            .containerBackground(for: .widget) { Color.clear }
    }
}

// MARK: - 共享原件

/// 极细单线进度条 ── 高 2.5pt, 半透明白 track + 实白 fill。比之前的
/// `WidgetProgressBar` 更克制,贴合 Apple Music widget 的视觉重量。
private struct ProgressLine: View {
    let value: TimeInterval
    let total: TimeInterval

    var body: some View {
        GeometryReader { geo in
            let progress: CGFloat = total > 0
                ? CGFloat(max(0, min(1, value / total)))
                : 0
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(.white.opacity(0.22))
                Capsule()
                    .fill(.white)
                    .frame(width: geo.size.width * progress)
            }
        }
        .frame(height: 2.5)
    }
}
