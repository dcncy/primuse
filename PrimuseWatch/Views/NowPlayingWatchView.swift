import SwiftUI

/// Watch 端的 Now Playing 主屏。
///
/// 布局: 封面 + 歌名 / 艺术家 / 当前歌词 + 进度条 + 上/暂/下三个按钮。
/// 主色跟 iPhone ThemeService 同步, RGB 推过来实时着色。
///
/// 调进度两种方式:
/// - 数字表冠旋转 ── 进入"调进度模式"后转表冠 ±N 秒精细调整 (一圈≈30s)
/// - 进度条点击 ── 点哪儿跳哪儿 (粗调, 没那么精确)
struct NowPlayingWatchView: View {
    @Environment(WatchPlayerStore.self) private var store
    /// 数字表冠绑定的 seek 偏移 (秒)。每次进 NowPlaying 重置成当前 currentTime,
    /// 用户转表冠会修改这个值, 松手后 .onChange 把值同步给 store.seek。
    @State private var crownTime: Double = 0
    /// crown 实际生效时机: 用户停止旋转 0.4s 后才发 seek, 避免连续转动期间
    /// 每一帧都狂发 sendMessage 把链路打满。
    @State private var seekDebounceTask: Task<Void, Never>?

    var body: some View {
        ScrollView {
            VStack(spacing: 10) {
                if store.hasSong {
                    cover
                    titleBlock
                    if !store.currentLyric.isEmpty {
                        lyricLine
                    }
                    progressBlock
                    transportButtons
                } else {
                    emptyState
                }
            }
            .padding(.horizontal, 8)
            .padding(.top, 4)
        }
        .navigationTitle("猿音")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            store.requestCurrentState()
            crownTime = store.currentTime
        }
        // 数字表冠 ── 转动时直接调 seek 时间, 1 step = 1 秒。
        .focusable(store.hasSong)
        .digitalCrownRotation(
            $crownTime,
            from: 0,
            through: max(1, store.duration),
            by: 1,
            sensitivity: .low,
            isContinuous: false,
            isHapticFeedbackEnabled: true
        )
        .onChange(of: crownTime) { _, newValue in
            // 用户停转 0.4s 后才发 seek, 避免连转中每帧都打 sendMessage。
            seekDebounceTask?.cancel()
            seekDebounceTask = Task { [newValue] in
                try? await Task.sleep(nanoseconds: 400_000_000)
                guard !Task.isCancelled else { return }
                await MainActor.run { store.seek(to: newValue) }
            }
        }
        // 当 iPhone 推过来的 currentTime 跟本地 crownTime 偏离很远 (例如换歌
        // 或 iPhone 端 seek 了), 把 crown 拉回当前位置。差值小不动避免
        // 抖动 ── 100ms 外推就会让 currentTime 缓慢漂移, 不能盲目跟随。
        .onChange(of: store.songID) { _, _ in crownTime = store.currentTime }
    }

    private var cover: some View {
        ZStack {
            if let img = store.coverImage {
                Image(uiImage: img)
                    .resizable()
                    .scaledToFill()
            } else {
                LinearGradient(
                    colors: [store.accent.opacity(0.5), store.accent.opacity(0.2)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .overlay {
                    Image(systemName: "music.note")
                        .font(.system(size: 32))
                        .foregroundStyle(.white.opacity(0.7))
                }
            }
        }
        .frame(width: 110, height: 110)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private var titleBlock: some View {
        VStack(spacing: 2) {
            Text(store.title)
                .font(.headline)
                .lineLimit(1)
                .truncationMode(.middle)
            Text(store.artist)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
    }

    /// 当前歌词单行 ── 在艺术家下面紧跟一行, 跟随播放进度自动更新。
    /// 暂停时停留在最后一行歌词不动。
    private var lyricLine: some View {
        Text(store.currentLyric)
            .font(.caption2)
            .foregroundStyle(store.accent)
            .lineLimit(2)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 4)
            .id(store.currentLyric)
            .transition(.opacity)
            .animation(.easeInOut(duration: 0.2), value: store.currentLyric)
    }

    private var progressBlock: some View {
        VStack(spacing: 2) {
            // 自定义进度条 ── 支持 tap-to-seek (点哪跳哪)。比 ProgressView
            // 多一个 GeometryReader 算点击位置在条上的比例。
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.secondary.opacity(0.25))
                    Capsule()
                        .fill(store.accent)
                        .frame(width: geo.size.width * CGFloat(store.progress))
                }
                .contentShape(Rectangle())
                .onTapGesture { location in
                    guard store.duration > 0, geo.size.width > 0 else { return }
                    let ratio = max(0, min(1, location.x / geo.size.width))
                    store.seek(to: store.duration * Double(ratio))
                }
            }
            .frame(height: 6)

            HStack {
                Text(formatTime(store.currentTime))
                    .monospacedDigit()
                Spacer()
                Text(formatTime(store.duration))
                    .monospacedDigit()
            }
            .font(.caption2)
            .foregroundStyle(.secondary)
        }
    }

    private var transportButtons: some View {
        HStack(spacing: 14) {
            Button { store.previous() } label: {
                Image(systemName: "backward.fill").font(.title3)
            }
            .buttonStyle(.plain)
            .frame(width: 44, height: 44)

            Button { store.togglePlayPause() } label: {
                ZStack {
                    Circle()
                        .fill(store.accent)
                    Group {
                        if store.isLoading {
                            ProgressView().tint(.white)
                        } else {
                            Image(systemName: store.isPlaying ? "pause.fill" : "play.fill")
                                .font(.title2)
                                .foregroundStyle(.white)
                                .contentTransition(.symbolEffect(.replace))
                        }
                    }
                }
                .frame(width: 56, height: 56)
            }
            .buttonStyle(.plain)

            Button { store.next() } label: {
                Image(systemName: "forward.fill").font(.title3)
            }
            .buttonStyle(.plain)
            .frame(width: 44, height: 44)
        }
        .padding(.top, 4)
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "iphone.gen3")
                .font(.system(size: 36))
                .foregroundStyle(.secondary)
            Text("还没有播放")
                .font(.headline)
            Text(store.isReachable ? "在 iPhone 上选一首歌开始播放" : "请确认 iPhone 已解锁并打开猿音")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 24)
    }

    private func formatTime(_ t: TimeInterval) -> String {
        guard t.isFinite, t >= 0 else { return "--:--" }
        let total = Int(t)
        return String(format: "%d:%02d", total / 60, total % 60)
    }
}
