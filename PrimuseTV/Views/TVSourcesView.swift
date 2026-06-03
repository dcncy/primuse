#if os(tvOS)
import SwiftUI

/// tvOS 音乐源 — 列出经 iCloud 同步过来的音乐源(只读)。
/// tvOS 不跑原生连接器,音乐源在 iPhone / Mac 上添加后同步到此。
struct TVSourcesView: View {
    @Environment(TVStore.self) private var store

    var body: some View {
        ZStack {
            TVColor.bg.ignoresSafeArea()
            if store.sources.isEmpty {
                TVEmptyState(icon: "server.rack", title: "还没有音乐源",
                             subtitle: "在 iPhone / Mac 上添加音乐源,经 iCloud 同步后在此显示").tvPage()
            } else {
                HStack(alignment: .top, spacing: 60) {
                    ScrollView(.vertical, showsIndicators: false) {
                        VStack(alignment: .leading, spacing: 6) {
                            TVEyebrow(text: "音乐源")
                            Text("音乐源 · \(store.sources.count) 个")
                                .font(TVFont.pageTitle).foregroundStyle(.white)
                                .padding(.bottom, 22)
                            VStack(spacing: 12) {
                                ForEach(store.sources) { s in TVSourceRow(source: s) }
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    VStack(alignment: .leading, spacing: 0) {
                        TVEyebrow(text: "添加音乐源").padding(.bottom, 16)
                        TVSourcesInfoCard()
                    }
                    .frame(width: 520)
                }
                .tvPage()
            }
        }
    }
}

/// tvOS 不直接添加源 —— 说明在 iPhone / Mac 上添加,经 iCloud 同步。
private struct TVSourcesInfoCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Image(systemName: "iphone.and.arrow.forward").font(.system(size: 52))
                .foregroundStyle(TVColor.brand)
            Text("在 iPhone / Mac 上添加").font(.system(size: 26, weight: .bold)).foregroundStyle(.white)
            Text("tvOS 端暂不支持直接添加 NAS / 云盘音乐源。在 iPhone 或 Mac 上添加并扫描后,音乐源与曲库会经 iCloud 自动同步到这里。")
                .font(.system(size: 18)).foregroundStyle(.white.opacity(0.65)).lineSpacing(5)
        }
        .padding(28).frame(maxWidth: .infinity, alignment: .leading)
        .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}

private struct TVSourceRow: View {
    let source: TVSource

    var body: some View {
        TVFocusButton(radius: TVRadius.card, scale: 1.01, lift: 0) { focused in
            HStack(spacing: 18) {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(LinearGradient(colors: [source.color, .black.opacity(0.4)],
                                         startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 46, height: 46)
                    .overlay {
                        Text(source.type.prefix(1).uppercased())
                            .font(.system(size: 22, weight: .bold)).foregroundStyle(.white)
                    }
                VStack(alignment: .leading, spacing: 3) {
                    Text(source.name).font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(.white).lineLimit(1)
                    Text("\(source.type.uppercased()) · \(TVFmt.count(source.songs)) 首")
                        .font(.system(size: 16, design: .monospaced))
                        .foregroundStyle(TVColor.textFaint)
                }
                Spacer(minLength: 0)
                HStack(spacing: 8) {
                    Image(systemName: statusIcon).font(.system(size: 15))
                    Text(statusLabel).font(.system(size: 16, weight: .semibold))
                }
                .foregroundStyle(statusColor)
            }
            .padding(.horizontal, 22).padding(.vertical, 18)
            .frame(maxWidth: .infinity)
            .background(focused ? Color.white.opacity(0.12) : TVColor.card)
        }
    }

    private var statusIcon: String {
        switch source.status {
        case .connected: return "circle.fill"
        case .scanning: return "arrow.triangle.2.circlepath"
        case .authFailed: return "exclamationmark.triangle.fill"
        case .disabled: return "circle"
        }
    }
    private var statusLabel: String {
        switch source.status {
        case .connected: return "已启用"
        case .scanning: return "扫描中"
        case .authFailed: return "凭据失败"
        case .disabled: return "已停用"
        }
    }
    private var statusColor: Color {
        switch source.status {
        case .connected: return TVColor.ok
        case .scanning: return source.color
        case .authFailed: return TVColor.bad
        case .disabled: return TVColor.textGhost
        }
    }
}

#endif
