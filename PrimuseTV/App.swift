#if os(tvOS)
import SwiftUI

/// tvOS app 入口。
///
/// 当前为 UI 层:界面按 design/猿音/scenes/tvos.jsx 还原,由 TVStore 的样例数据驱动,
/// 保证可独立编译、可在 tvOS 模拟器预览。后续接入真实曲库(经 iCloud 同步)与播放时,
/// 只需补一个把 PrimuseKit 的 Song/Album/Playlist/MusicSource 映射成 TV* view-model
/// 的 adapter,各 View 无需改动。
@main
struct PrimuseTVApp: App {
    @State private var store = TVStore()

    var body: some Scene {
        WindowGroup {
            TVRoot()
                .environment(store)
                .preferredColorScheme(.dark)
                .tint(TVColor.brand)
                .task { await store.bootstrap() }
        }
    }
}
#endif
