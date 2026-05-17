import SwiftUI
import PrimuseKit

/// DLNA Renderer 模式的设置面 ── toggle 开关 + 当前状态展示。
/// 开关持久化用 @AppStorage,实际生效由 onChange 调 service.start/stop。
struct DLNARendererSettingsView: View {
    @Environment(DLNARendererService.self) private var renderer
    @AppStorage("dlna.rendererEnabled") private var enabled: Bool = false

    var body: some View {
        Form {
            Section {
                Toggle(String(localized: "settings_dlna_enable"), isOn: $enabled)
                    .onChange(of: enabled) { _, new in
                        if new { renderer.start() } else { renderer.stop() }
                    }
                if renderer.isRunning && !renderer.statusText.isEmpty {
                    HStack {
                        Image(systemName: "dot.radiowaves.left.and.right")
                            .foregroundStyle(.green)
                        Text(renderer.statusText)
                            .font(.subheadline)
                            .lineLimit(2)
                    }
                }
            } footer: {
                Text(String(localized: "settings_dlna_footer"))
                    .font(.footnote)
            }
        }
        .navigationTitle("settings_dlna_section")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            // 用户上次打开 toggle 后 app 重启,需要恢复 service 状态。
            if enabled && !renderer.isRunning { renderer.start() }
        }
    }
}
