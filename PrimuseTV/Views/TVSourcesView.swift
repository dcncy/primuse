#if os(tvOS)
import SwiftUI

/// tvOS 音乐源 — 左列状态列表 + 右列「用 iPhone 配对」扫码卡(对应 TVSourcesArtboard)。
/// tvOS 不便输入 ftp://、凭据,所以新增源走配对的 iPhone 扫码。
struct TVSourcesView: View {
    @Environment(TVStore.self) private var store

    var body: some View {
        ZStack {
            TVColor.bg.ignoresSafeArea()
            HStack(alignment: .top, spacing: 60) {
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 6) {
                        TVEyebrow(text: "音乐源")
                        Text("已连接 · \(store.sources.filter { $0.status == .connected }.count) 个")
                            .font(TVFont.pageTitle).foregroundStyle(.white)
                            .padding(.bottom, 22)
                        VStack(spacing: 12) {
                            ForEach(store.sources) { s in TVSourceRow(source: s) }
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                VStack(alignment: .leading, spacing: 0) {
                    TVEyebrow(text: "添加新源")
                    Text("用 iPhone 配对")
                        .font(.system(size: 32, weight: .bold)).foregroundStyle(.white)
                        .padding(.top, 6).padding(.bottom, 22)
                    TVPairCard()
                }
                .frame(width: 560)
            }
            .tvPage()
        }
    }
}

private struct TVSourceRow: View {
    let source: TVSource

    var body: some View {
        TVFocusButton(radius: TVRadius.card, scale: 1.015, lift: 4) { _ in
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
            .background(TVColor.card)
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
        case .connected: return "在线"
        case .scanning: return "扫描"
        case .authFailed: return "凭据失败"
        case .disabled: return "禁用"
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

/// 配对扫码卡 — 程序化二维码 + 说明 + 配对码。
private struct TVPairCard: View {
    var body: some View {
        TVFocusButton(radius: 28, scale: 1.02, lift: 6) { _ in
            VStack(spacing: 22) {
                TVQRCode().frame(width: 240, height: 240)
                VStack(spacing: 6) {
                    Text("用 iPhone 摄像头扫码")
                        .font(.system(size: 26, weight: .bold)).foregroundStyle(.white)
                    Text("在 Primuse 配对的 iPhone 上输入 NAS\n地址 / 凭据 / OAuth 后，会自动同步到 TV")
                        .font(.system(size: 17)).foregroundStyle(.white.opacity(0.62))
                        .multilineTextAlignment(.center).lineSpacing(4)
                    Text("4 7 2 9")
                        .font(.system(size: 18, design: .monospaced)).tracking(6)
                        .foregroundStyle(TVColor.textFaint)
                        .padding(.top, 8)
                }
            }
            .padding(30)
            .frame(maxWidth: .infinity)
            .background(.white.opacity(0.08))
        }
    }
}

/// 风格化二维码 — 3 个定位角 + 确定性数据点(纯装饰)。
struct TVQRCode: View {
    private let n = 13
    var body: some View {
        GeometryReader { geo in
            let gap: CGFloat = 2
            let pad: CGFloat = 14
            let inner = min(geo.size.width, geo.size.height) - pad * 2
            let dot = (inner - gap * CGFloat(n - 1)) / CGFloat(n)
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(.white)
                .overlay {
                    VStack(spacing: gap) {
                        ForEach(0..<n, id: \.self) { y in
                            HStack(spacing: gap) {
                                ForEach(0..<n, id: \.self) { x in
                                    RoundedRectangle(cornerRadius: 1)
                                        .fill(on(x, y) ? Color(hex: "#1f1c19") : .clear)
                                        .frame(width: dot, height: dot)
                                }
                            }
                        }
                    }
                    .padding(pad)
                }
        }
    }

    private func on(_ x: Int, _ y: Int) -> Bool {
        let isMarker = (x < 3 && y < 3) || (x > 9 && y < 3) || (x < 3 && y > 9)
        let isMarkerOuter = isMarker && (x == 0 || x == 2 || y == 0 || y == 2 || (x > 9 && x == 12) || (y > 9 && y == 12))
        let seed = (x * 31 + y * 17) % 7
        return isMarkerOuter || (isMarker && x % 3 == 1 && y % 3 == 1) || (!isMarker && seed < 3)
    }
}
#endif
