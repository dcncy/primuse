import SwiftUI
import PrimuseKit

/// DLNA Renderer 模式的设置面 ── toggle 开关 + 当前状态展示 + 实时事件日志。
/// 开关持久化用 @AppStorage,实际生效由 onChange 调 service.start/stop。
/// 调试日志直接显示最近 30 条 SSDP / SOAP / GENA 事件,帮用户判断 DLNA
/// 控制点有没有真的发现 / 推送到本机。
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

            // 实时调试日志 ── 仅在运行时显示。展开后看到 control point 的
            // 发现 / 控制 / 订阅请求,判断 DLNA 链路有没有真的打通。
            if renderer.isRunning {
                Section(String(localized: "settings_dlna_log_section")) {
                    if renderer.recentEvents.isEmpty {
                        Text(String(localized: "settings_dlna_log_empty"))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(renderer.recentEvents) { event in
                            eventRow(event)
                        }
                    }
                }
            }
        }
        .navigationTitle("settings_dlna_section")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            // 用户上次打开 toggle 后 app 重启,需要恢复 service 状态。
            if enabled && !renderer.isRunning { renderer.start() }
        }
    }

    private func eventRow(_ event: DLNARendererService.DebugEvent) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: icon(for: event.kind))
                .font(.caption)
                .foregroundStyle(color(for: event.kind))
                .frame(width: 18)
            VStack(alignment: .leading, spacing: 2) {
                Text(event.detail)
                    .font(.system(size: 12, weight: .regular, design: .monospaced))
                    .lineLimit(2)
                Text(event.timestamp.formatted(date: .omitted, time: .standard))
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
    }

    private func icon(for kind: DLNARendererService.DebugEvent.Kind) -> String {
        switch kind {
        case .discovery: return "dot.radiowaves.left.and.right"
        case .control: return "play.fill"
        case .event: return "bell.fill"
        case .error: return "exclamationmark.triangle.fill"
        }
    }

    private func color(for kind: DLNARendererService.DebugEvent.Kind) -> Color {
        switch kind {
        case .discovery: return .blue
        case .control: return .green
        case .event: return .orange
        case .error: return .red
        }
    }
}
