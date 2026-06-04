#if os(tvOS)
import SwiftUI

/// tvOS app 入口。
///
/// 界面按 design/猿音/scenes/tvos.jsx 还原,由 TVStore 读取经 iCloud 同步下来的
/// 真实曲库快照(library-cache.json / sources.json)驱动。启动时按「自动同步」
/// 偏好决定联网拉取还是仅本地重载。
@main
struct PrimuseTVApp: App {
    @State private var store = TVStore()

    var body: some Scene {
        WindowGroup {
            TVRoot()
                .environment(store)
                .preferredColorScheme(.dark)
                .tint(TVColor.brand)
                .task {
                    store.engine.configureAudioSession()
                    #if DEBUG
                    if ProcessInfo.processInfo.environment["TV_AUDIO_SMOKE"] == "1" {
                        store.engine.runSmokeTest()
                    }
                    #endif
                    let autoSync = UserDefaults.standard.object(forKey: "tvAutoSync") as? Bool ?? true
                    if autoSync { await store.bootstrap() } else { store.reload() }
                }
        }
    }
}
#endif
