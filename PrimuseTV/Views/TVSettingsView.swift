#if os(tvOS)
import SwiftUI

/// tvOS 设置 — 左列常用清单,右列 Siri Remote 图示(对应 TVSettingsArtboard)。
/// 刻意精简:无 EQ 推子 / 刮削源 / SSL 信任,这些留在 macOS / iOS。
struct TVSettingsView: View {
    @Environment(\.dismiss) private var dismiss

    private struct Row: Identifiable {
        let id: String
        let icon: String
        let value: String
        init(_ id: String, _ icon: String, _ value: String) { self.id = id; self.icon = icon; self.value = value }
    }
    private let rows: [Row] = [
        .init("音频输出", "hifispeaker.fill", "AirPods Pro · 空间音频"),
        .init("AirPlay / DLNA", "airplayaudio", "Sony BRAVIA · 客厅"),
        .init("空间音频", "airpodspro", "开启 · 跟随头部"),
        .init("ReplayGain", "speaker.wave.2.fill", "Album mode"),
        .init("睡眠定时器", "moon.zzz.fill", "30 分钟后停止"),
        .init("歌词字号", "textformat.size", "1.2 ×"),
        .init("iCloud 同步", "icloud.fill", "已连接 · 潘家共享库"),
        .init("Scrobble", "waveform", "Last.fm · panforever"),
        .init("关于 Primuse", "info.circle", "1.0.0 (1) · tvOS 18"),
    ]

    var body: some View {
        ZStack {
            TVColor.bg.ignoresSafeArea()
            HStack(alignment: .top, spacing: 80) {
                VStack(alignment: .leading, spacing: 0) {
                    TVEyebrow(text: "设置").padding(.bottom, 6)
                    Text("常用").font(TVFont.pageTitle).foregroundStyle(.white).padding(.bottom, 24)
                    VStack(spacing: 12) {
                        ForEach(rows) { r in settingRow(r) }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                VStack(alignment: .leading, spacing: 0) {
                    TVEyebrow(text: "遥控提示").padding(.bottom, 24)
                    HStack { Spacer(); TVSiriRemote(); Spacer() }
                    VStack(alignment: .leading, spacing: 14) {
                        TVRemoteHint("圆形触控板", "上 / 下移动焦点 · 长按打开选项")
                        TVRemoteHint("播放 / 暂停", "任意位置切歌 · 双按下一首")
                        TVRemoteHint("Siri 按钮", "「播放周杰伦的七里香」· 全局可用")
                        TVRemoteHint("Menu / 返回", "返回上一层 · 长按回主页")
                        TVRemoteHint("TV 按钮", "单按回 Primuse 首页 · 双按多任务")
                    }
                    .padding(.top, 32)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .tvPage()
        }
        .onExitCommand { dismiss() }
    }

    private func settingRow(_ r: Row) -> some View {
        TVFocusButton(radius: 14, scale: 1.02, lift: 0) { focused in
            HStack(spacing: 18) {
                Image(systemName: r.icon).font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 40, height: 40)
                    .background(focused ? AnyShapeStyle(TVColor.brand) : AnyShapeStyle(Color.white.opacity(0.10)),
                                in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                Text(r.id).font(.system(size: 22, weight: focused ? .bold : .medium)).foregroundStyle(.white)
                Spacer(minLength: 0)
                Text(r.value).font(.system(size: 18)).foregroundStyle(.white.opacity(0.62))
                Image(systemName: "chevron.right").font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.35))
            }
            .padding(.horizontal, 22).padding(.vertical, 16)
            .frame(maxWidth: .infinity)
            .background(focused ? Color.white.opacity(0.10) : TVColor.card)
        }
    }
}

private struct TVRemoteHint: View {
    let binding: String
    let label: String
    init(_ binding: String, _ label: String) { self.binding = binding; self.label = label }
    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 14) {
            Text(binding).font(.system(size: 15, weight: .semibold)).foregroundStyle(.white)
                .frame(minWidth: 180).padding(.horizontal, 12).padding(.vertical, 6)
                .background(.white.opacity(0.10), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .strokeBorder(.white.opacity(0.18), lineWidth: 0.5)
                }
            Text(label).font(.system(size: 18)).foregroundStyle(.white.opacity(0.7))
        }
    }
}

/// 风格化 Siri Remote。
private struct TVSiriRemote: View {
    var body: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(RadialGradient(colors: [.white.opacity(0.08), .clear],
                                         center: UnitPoint(x: 0.5, y: 0.3), startRadius: 0, endRadius: 90))
                    .overlay { Circle().strokeBorder(.white.opacity(0.16), lineWidth: 0.5) }
                    .frame(width: 150, height: 150)
                ForEach([0.0, 90.0, 180.0, 270.0], id: \.self) { deg in
                    Image(systemName: "chevron.up").font(.system(size: 16))
                        .foregroundStyle(.white.opacity(0.45))
                        .offset(y: -56)
                        .rotationEffect(.degrees(deg))
                }
                Circle().fill(.white.opacity(0.18))
                    .overlay { Circle().strokeBorder(.white.opacity(0.3), lineWidth: 0.5) }
                    .frame(width: 24, height: 24)
            }
            .padding(.top, 10)

            let grid = [("arrow.uturn.backward", "Back"), ("tv", "TV"),
                        ("speaker.slash.fill", "Mute"), ("mic.fill", "Siri")]
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                ForEach(grid, id: \.0) { b in
                    VStack(spacing: 3) {
                        Image(systemName: b.0).font(.system(size: 16)).foregroundStyle(.white.opacity(0.7))
                        Text(b.1).font(.system(size: 9)).foregroundStyle(.white.opacity(0.4))
                    }
                    .frame(maxWidth: .infinity).frame(height: 48)
                    .background(.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay { RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(.white.opacity(0.12), lineWidth: 0.5) }
                }
            }

            HStack(spacing: 14) {
                Image(systemName: "backward.fill")
                Image(systemName: "playpause.fill")
                Image(systemName: "forward.fill")
            }
            .font(.system(size: 16)).foregroundStyle(.white.opacity(0.6))
            .frame(maxWidth: .infinity).frame(height: 48)
            .background(.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay { RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(.white.opacity(0.12), lineWidth: 0.5) }

            Text("SIRI REMOTE").font(.system(size: 11, weight: .medium)).tracking(1.6)
                .foregroundStyle(.white.opacity(0.4)).padding(.top, 4)
        }
        .padding(24)
        .frame(width: 200)
        .background(
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .fill(LinearGradient(colors: [Color(hex: "#2a2722"), Color(hex: "#16140f")],
                                     startPoint: .topLeading, endPoint: .bottomTrailing))
        )
        .overlay {
            RoundedRectangle(cornerRadius: 32, style: .continuous).strokeBorder(.white.opacity(0.16), lineWidth: 0.5)
        }
        .shadow(color: .black.opacity(0.6), radius: 30, y: 14)
    }
}
#endif
