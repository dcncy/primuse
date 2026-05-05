import SwiftUI
import PrimuseKit

struct SettingsView: View {
    @AppStorage(UserNotificationService.notifyLongTasksKey) private var notifyLongTasks: Bool = true

    var body: some View {
        NavigationStack {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    settingsHeader

                    SettingsSectionCard(title: "playback", icon: "play.circle.fill", tint: .blue) {
                        SettingsNavRow("playback_settings", systemImage: "play.circle", tint: .blue) {
                            PlaybackSettingsView()
                        }
                        SettingsNavRow("equalizer", systemImage: "slider.horizontal.3", tint: .cyan) {
                            EqualizerView()
                        }
                        SettingsNavRow("audio_effects", systemImage: "waveform.badge.plus", tint: .purple) {
                            AudioEffectsView()
                        }
                    }

                    SettingsSectionCard(title: "library", icon: "books.vertical.fill", tint: .pink) {
                        SettingsNavRow("metadata_scraping", systemImage: "wand.and.stars", tint: .pink) {
                            MetadataScrapingView()
                        }
                        SettingsNavRow("lyrics_translation_title", systemImage: "character.bubble", tint: .teal) {
                            LyricsTranslationSettingsView()
                        }
                        SettingsNavRow("dup_title", systemImage: "square.stack.3d.up.badge.automatic", tint: .orange) {
                            DuplicateSongsView()
                        }
                        SettingsNavRow("playlist_import_title", systemImage: "tray.and.arrow.down", tint: .green) {
                            PlaylistImportView()
                        }
                        SettingsNavRow("storage_management", systemImage: "internaldrive", tint: .indigo) {
                            StorageManagementView()
                        }
                    }

                    SettingsSectionCard(title: "security", icon: "lock.shield.fill", tint: .green) {
                        SettingsNavRow("trusted_domains", systemImage: "lock.shield", tint: .green,
                                       trailing: "\(SSLTrustStore.shared.trustedDomains.count)") {
                            TrustedDomainsView()
                        }
                    }

                    #if os(iOS)
                    SettingsSectionCard(title: "appearance", icon: "sparkles", tint: .purple) {
                        SettingsNavRow("app_icon", systemImage: "app.badge", tint: .purple) {
                            AppIconSettingsView()
                        }
                    }
                    #endif

                    SettingsSectionCard(title: "sync", icon: "icloud.fill", tint: .blue) {
                        SettingsNavRow("icloud_sync_title", systemImage: "icloud", tint: .blue) {
                            CloudSyncSettingsView()
                        }
                        SettingsNavRow("recently_deleted", systemImage: "trash", tint: .red) {
                            RecentlyDeletedView()
                        }
                        #if os(iOS)
                        SettingsNavRow("stats_title", systemImage: "chart.bar.xaxis", tint: .cyan) {
                            ListeningStatsView()
                        }
                        #endif
                        SettingsNavRow("scrobble_title", systemImage: "music.note.list", tint: .pink) {
                            ScrobbleSettingsView()
                        }
                    }

                    notificationCard
                    aboutCard
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 18)
                .padding(.bottom, 20)
            }
            .background(settingsBackground)
            .navigationTitle("settings_title")
            .toolbarTitleDisplayMode(.inlineLarge)
        }
    }

    private var settingsHeader: some View {
        HStack(spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(.blue.opacity(0.16))
                Image(systemName: "gearshape.2.fill")
                    .font(.system(size: 30, weight: .semibold))
                    .foregroundStyle(.blue)
            }
            .frame(width: 70, height: 70)

            VStack(alignment: .leading, spacing: 6) {
                Text("settings_title")
                    .font(.largeTitle.bold())
                Text("settings_overview_subtitle")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
        .padding(.vertical, 6)
    }

    private var notificationCard: some View {
        SettingsSectionCard(title: "notifications", icon: "bell.badge.fill", tint: .orange) {
            Toggle(isOn: $notifyLongTasks) {
                Label {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("notify_long_tasks")
                            .font(.body.weight(.medium))
                        Text("notify_long_tasks_hint")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                } icon: {
                    SettingsIcon(systemImage: "clock.badge.checkmark", tint: .orange)
                }
            }
            .toggleStyle(.switch)
            .padding(.vertical, 2)
        }
    }

    private var aboutCard: some View {
        SettingsSectionCard(title: "about", icon: "info.circle.fill", tint: .secondary) {
            SettingsInfoRow("version", value: Bundle.main.appVersion)
            SettingsInfoRow("build", value: Bundle.main.appBuildNumber)
            SettingsNavRow("licenses", systemImage: "doc.text", tint: .secondary) {
                LicensesView()
            }
        }
    }

    private var settingsBackground: some View {
        #if os(iOS)
        Color(uiColor: .systemGroupedBackground).ignoresSafeArea()
        #else
        Color(nsColor: .windowBackgroundColor).ignoresSafeArea()
        #endif
    }
}

private struct SettingsSectionCard<Content: View>: View {
    let title: LocalizedStringKey
    let icon: String
    let tint: Color
    @ViewBuilder var content: Content

    init(title: LocalizedStringKey, icon: String, tint: Color, @ViewBuilder content: () -> Content) {
        self.title = title
        self.icon = icon
        self.tint = tint
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(tint)
                    .frame(width: 18)
                Text(title)
                    .font(.headline)
                Spacer()
            }
            VStack(spacing: 0) {
                content
            }
            .padding(12)
            .background(.background, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(.primary.opacity(0.06), lineWidth: 1)
            }
        }
    }
}

private struct SettingsNavRow<Destination: View>: View {
    let title: LocalizedStringKey
    let systemImage: String
    let tint: Color
    let trailing: String?
    @ViewBuilder var destination: Destination

    init(_ title: LocalizedStringKey,
         systemImage: String,
         tint: Color,
         trailing: String? = nil,
         @ViewBuilder destination: () -> Destination) {
        self.title = title
        self.systemImage = systemImage
        self.tint = tint
        self.trailing = trailing
        self.destination = destination()
    }

    var body: some View {
        NavigationLink {
            destination
        } label: {
            HStack(spacing: 12) {
                SettingsIcon(systemImage: systemImage, tint: tint)
                Text(title)
                    .font(.body.weight(.medium))
                    .foregroundStyle(.primary)
                Spacer(minLength: 12)
                if let trailing {
                    Text(trailing)
                        .font(.subheadline.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(.vertical, 9)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

private struct SettingsInfoRow: View {
    let title: LocalizedStringKey
    let value: String

    init(_ title: LocalizedStringKey, value: String) {
        self.title = title
        self.value = value
    }

    var body: some View {
        HStack(spacing: 12) {
            Text(title)
                .font(.body.weight(.medium))
            Spacer()
            Text(value)
                .font(.subheadline.monospacedDigit())
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 9)
    }
}

private struct SettingsIcon: View {
    let systemImage: String
    let tint: Color

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(tint.opacity(0.14))
            Image(systemName: systemImage)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(tint)
        }
        .frame(width: 34, height: 34)
    }
}

struct MetadataScrapingView: View {
    @Environment(MusicLibrary.self) private var library
    @Environment(MusicScraperService.self) private var scraperService
    @Environment(ScraperSettingsStore.self) private var scraperSettings

    @State private var editingCookieSourceId: String?
    @State private var cookieText = ""
    @State private var showImportSheet = false
    @State private var importText = ""
    #if os(iOS)
    @State private var shareTarget: ShareTarget?

    /// 分享 sheet 用 — URL 不是 Identifiable，包一层。
    struct ShareTarget: Identifiable {
        let id = UUID()
        let url: URL
    }
    #endif
    @State private var importError: String?
    @State private var importMode: ImportMode = .paste
    @State private var editingConfigSource: ScraperSourceConfig?
    @State private var editingConfigJSON = ""
    @State private var isReordering = false

    enum ImportMode { case paste, url }

    var body: some View {
        @Bindable var settings = scraperSettings

        Form {
            Section {
                ForEach(settings.sources) { source in
                    HStack(spacing: 12) {
                        Image(systemName: source.type.iconName)
                            .font(.title3)
                            .foregroundStyle(source.isEnabled ? source.type.themeColor : .secondary)
                            .frame(width: 28)

                        Text(source.type.displayName)
                            .font(.subheadline)
                            .fontWeight(.medium)

                        if source.type.supportsWordLevelLyrics {
                            Text("lyrics_word_level_badge")
                                .font(.caption2.weight(.semibold))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(
                                    Capsule().fill(source.type.themeColor.opacity(0.15))
                                )
                                .foregroundStyle(source.type.themeColor)
                                .accessibilityLabel(Text("lyrics_word_level_hint"))
                        }

                        Spacer()

                        if source.type.supportsCookie {
                            Button {
                                editingCookieSourceId = source.id
                                cookieText = source.cookie ?? ""
                            } label: {
                                Image(systemName: "key")
                                    .font(.caption)
                                    .foregroundStyle(source.cookie?.isEmpty == false ? Color.green : Color.secondary)
                            }
                            .buttonStyle(.plain)
                        }

                        Toggle("", isOn: Binding(
                            get: { source.isEnabled },
                            set: { _ in scraperSettings.toggleSource(id: source.id) }
                        ))
                        .labelsHidden()
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        if !source.type.isBuiltIn {
                            Button(role: .destructive) {
                                scraperSettings.removeCustomSource(id: source.id)
                            } label: {
                                Image(systemName: "trash")
                            }

                            Button {
                                if case .custom(let configId) = source.type,
                                   let config = ScraperConfigStore.shared.config(for: configId) {
                                    let encoder = JSONEncoder()
                                    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
                                    if let data = try? encoder.encode(config),
                                       let json = String(data: data, encoding: .utf8) {
                                        editingConfigJSON = json
                                        editingConfigSource = source
                                    }
                                }
                            } label: {
                                Image(systemName: "doc.text")
                            }
                            .tint(.blue)

                            #if os(iOS)
                            Button {
                                if let url = makeShareableConfigFile(for: source) {
                                    shareTarget = ShareTarget(url: url)
                                }
                            } label: {
                                Image(systemName: "square.and.arrow.up")
                            }
                            .tint(.green)
                            #endif
                        }
                    }
                }
                .onMove { scraperSettings.reorderSources(fromOffsets: $0, toOffset: $1) }
            } header: {
                HStack {
                    Text("scraper_sources")
                    Spacer()
                    Button(isReordering ? String(localized: "done") : String(localized: "reorder")) {
                        withAnimation { isReordering.toggle() }
                    }
                    .font(.caption)
                    .textCase(nil)
                }
            }

            Section {
                Button {
                    importText = ""
                    importError = nil
                    showImportSheet = true
                } label: {
                    Label("import_scraper_source", systemImage: "plus.circle")
                }
            } header: {
                Text("custom_sources")
            } footer: {
                Text("import_scraper_footer")
            }

            Section("scraper_options") {
                Toggle("only_fill_missing", isOn: $settings.onlyFillMissingFields)

                Button("reset_scraper_defaults") {
                    scraperSettings.resetToDefaults()
                }
                .foregroundStyle(.red)
            }

            Section {
                if scraperService.isScraping {
                    VStack(alignment: .leading, spacing: 10) {
                        ProgressView(value: scraperService.progress)
                        Text(scraperService.currentSongTitle)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)

                        HStack(spacing: 12) {
                            Text("\(scraperService.processedCount)/\(scraperService.totalCount)")
                            Text("·")
                            Text("\(scraperService.updatedCount) \(String(localized: "updated_count"))")
                            Text("·")
                            Text("\(scraperService.failedCount) \(String(localized: "failed_count"))")
                        }
                        .font(.caption2)
                        .foregroundStyle(.secondary)

                        Button("cancel", role: .cancel) {
                            scraperService.cancel()
                        }
                        .buttonStyle(.borderless)
                    }
                } else {
                    Button("scrape_missing_metadata") {
                        scraperService.scrapeMissingMetadata(in: library)
                    }

                    Button("rescrape_library") {
                        scraperService.rescrapeLibrary(in: library)
                    }
                }
            } header: {
                Text("scrape_actions")
            } footer: {
                Text("scrape_description")
            }
        }
        .navigationTitle("metadata_scraping")
        .navigationBarTitleDisplayMode(.inline)
        #if os(iOS)
        .environment(\.editMode, isReordering ? .constant(.active) : .constant(.inactive))
        #endif
        .alert("cookie_config", isPresented: Binding(
            get: { editingCookieSourceId != nil },
            set: { if !$0 { editingCookieSourceId = nil } }
        )) {
            TextField("cookie_placeholder", text: $cookieText)
            Button("save") {
                if let id = editingCookieSourceId {
                    scraperSettings.updateCookie(id: id, cookie: cookieText.isEmpty ? nil : cookieText)
                }
                editingCookieSourceId = nil
            }
            Button("cancel", role: .cancel) {
                editingCookieSourceId = nil
            }
        } message: {
            Text("cookie_config_message")
        }
        .sheet(isPresented: $showImportSheet) {
            importScraperSheet
        }
        .sheet(item: $editingConfigSource) { source in
            editConfigSheet(source: source)
        }
        #if os(iOS)
        .sheet(item: $shareTarget) { target in
            ShareSheet(items: [target.url])
        }
        #endif
    }

    #if os(iOS)
    /// 把指定源的 ScraperConfig（含 secrets）写入临时文件返回 URL，供 ShareSheet 使用。
    /// 注意：分享出去的 JSON 包含 secrets，因此目标只能是用户私下分享（AirDrop / 信任的私人聊天）。
    private func makeShareableConfigFile(for source: ScraperSourceConfig) -> URL? {
        guard case .custom(let configId) = source.type,
              let config = ScraperConfigStore.shared.config(for: configId) else { return nil }

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        // ScraperConfig.encode(to:) 默认跳 secrets，先编出主体，再 inject secrets 拼成完整 bundle。
        guard let mainData = try? encoder.encode(config),
              var dict = (try? JSONSerialization.jsonObject(with: mainData)) as? [String: Any] else { return nil }
        if let secrets = config.secrets, !secrets.isEmpty {
            dict["secrets"] = secrets
        }
        guard let bundleData = try? JSONSerialization.data(
            withJSONObject: dict,
            options: [.prettyPrinted, .sortedKeys]
        ) else { return nil }

        let safeId = configId.filter { $0.isLetter || $0.isNumber || $0 == "-" || $0 == "_" }
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(safeId.isEmpty ? "scraper" : safeId).json")
        do {
            try bundleData.write(to: url, options: .atomic)
            return url
        } catch {
            plog("⚠️ Share scraper config: write temp file failed: \(error.localizedDescription)")
            return nil
        }
    }
    #endif

    private var importScraperSheet: some View {
        NavigationStack {
            Form {
                Picker("import_mode", selection: $importMode) {
                    Text("paste_config").tag(ImportMode.paste)
                    Text("from_url").tag(ImportMode.url)
                }
                .pickerStyle(.segmented)

                Section {
                    if importMode == .paste {
                        TextEditor(text: $importText)
                            .font(.system(.caption, design: .monospaced))
                            .frame(minHeight: 200)
                    } else {
                        TextField("config_url_placeholder", text: $importText)
                            .keyboardType(.URL)
                            .autocapitalization(.none)
                    }
                } footer: {
                    if importMode == .paste {
                        Text("paste_config_footer")
                    } else {
                        Text("url_config_footer")
                    }
                }

                if let error = importError {
                    Section {
                        Text(error).foregroundStyle(.red).font(.caption)
                    }
                }
            }
            .navigationTitle("import_scraper_source")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("cancel") { showImportSheet = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("import_action") {
                        performImport()
                    }
                    .disabled(importText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func editConfigSheet(source: ScraperSourceConfig) -> some View {
        NavigationStack {
            Form {
                Section {
                    TextEditor(text: $editingConfigJSON)
                        .font(.system(.caption, design: .monospaced))
                        .frame(minHeight: 300)
                }
            }
            .navigationTitle(source.type.displayName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("cancel") { editingConfigSource = nil }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("save") {
                        do {
                            let configs = try ScraperConfigStore.shared.importFromJSON(editingConfigJSON)
                            guard configs.count == 1, let config = configs.first else {
                                plog("Config save error: edit accepts a single source only, got \(configs.count)")
                                return
                            }
                            scraperSettings.addCustomSource(config)
                            editingConfigSource = nil
                        } catch {
                            plog("Config save error: \(error.localizedDescription)")
                        }
                    }
                }
            }
        }
        .presentationDetents([.large])
    }

    private func performImport() {
        importError = nil
        let text = importText.trimmingCharacters(in: .whitespacesAndNewlines)
        plog("📥 Import: mode=\(importMode == .url ? "url" : "paste") textLen=\(text.count)")

        if importMode == .url {
            guard let url = URL(string: text) else {
                importError = String(localized: "invalid_url")
                return
            }
            Task {
                do {
                    let configs = try await ScraperConfigStore.shared.importFromURL(url)
                    plog("📥 Import success (url): count=\(configs.count) ids=\(configs.map(\.id))")
                    for config in configs { scraperSettings.addCustomSource(config) }
                    showImportSheet = false
                } catch {
                    importError = error.localizedDescription
                }
            }
        } else {
            do {
                let configs = try ScraperConfigStore.shared.importFromJSON(text)
                plog("📥 Import success: count=\(configs.count) ids=\(configs.map(\.id))")
                for config in configs { scraperSettings.addCustomSource(config) }
                showImportSheet = false
            } catch {
                plog("📥 Import failed: \(error.localizedDescription)")
                importError = error.localizedDescription
            }
        }
    }
}

struct PlaybackSettingsView: View {
    @Environment(PlaybackSettingsStore.self) private var playbackSettings

    var body: some View {
        @Bindable var settings = playbackSettings

        Form {
            Section {
                Toggle("gapless_playback", isOn: $settings.gaplessEnabled)
                    .disabled(true)
            } footer: {
                Text("gapless_not_available")
            }

            Section {
                Toggle("crossfade", isOn: $settings.crossfadeEnabled)

                if settings.crossfadeEnabled {
                    // 之前 Slider 的 trailing label "3s" 和下方 caption2 "3 秒"
                    // 同时显示,在 macOS Form 里产生左右各一处重复的当前值。
                    // 改为「title 左 / 当前值右」一行 + slider 单独一行,只显示一次值。
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("crossfade_duration")
                                .font(.caption)
                            Spacer()
                            Text("\(Int(settings.crossfadeDuration)) \(String(localized: "seconds"))")
                                .font(.caption)
                                .monospacedDigit()
                                .foregroundStyle(.secondary)
                        }
                        Slider(value: $settings.crossfadeDuration, in: 1...12, step: 1)
                    }
                }
            } footer: {
                Text("crossfade_desc")
            }

            Section {
                Toggle("replay_gain", isOn: $settings.replayGainEnabled)

                if settings.replayGainEnabled {
                    // 用 LabeledContent 显式分隔 title / Picker, 这样 macOS Form
                    // 才会把 dropdown 推到行尾, 不会"模式 单曲"挤在最左留一片空白。
                    LabeledContent {
                        Picker("", selection: $settings.replayGainMode) {
                            ForEach(ReplayGainMode.allCases, id: \.self) { mode in
                                Text(mode.displayName).tag(mode)
                            }
                        }
                        .labelsHidden()
                        .pickerStyle(.menu)
                    } label: {
                        Text("rg_mode")
                    }
                }
            } footer: {
                Text("replay_gain_desc")
            }

        }
        #if os(macOS)
        // macOS Settings 已经把 tab 标题画在窗口顶部,navigationTitle 在
        // 这里既看不见也会让 SwiftUI 警告。Form 用 grouped 样式才像
        // System Settings,跟 EqualizerView / AudioEffectsView 保持一致。
        .formStyle(.grouped)
        #else
        .navigationTitle("playback_settings")
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }
}

// MARK: - Storage Management

struct StorageManagementView: View {
    @Environment(SourceManager.self) private var sourceManager
    @Environment(PlaybackSettingsStore.self) private var playbackSettings
    @Environment(MetadataBackfillService.self) private var backfill
    @AppStorage(MetadataBackfillService.wifiOnlyDefaultsKey) private var cloudScanWifiOnly: Bool = true
    @State private var audioCacheSize: String = "..."
    @State private var imageCacheSize: String = "..."
    @State private var metadataSize: String = "..."
    @State private var isClearingAudio = false
    @State private var isClearingImages = false
    @State private var isClearingMetadata = false
    @State private var audioBreakdown: SourceManager.AudioCacheBreakdown?
    @State private var isClearingPartials = false
    @State private var isClearingOrphans = false
    /// 清理结果提示 — 失败时让用户知道为什么没全清掉 (通常是当前正在播放的歌)。
    @State private var cacheActionToast: String?
    @State private var logShareItem: LogShareItem?

    struct LogShareItem: Identifiable {
        let id = UUID()
        let url: URL
    }

    var body: some View {
        @Bindable var settings = playbackSettings

        List {
            Section {
                Toggle("cloud_scan_wifi_only", isOn: $cloudScanWifiOnly)
                    .onChange(of: cloudScanWifiOnly) { _, _ in
                        // Re-evaluate immediately so the user sees backfill
                        // start (or stop) right after flipping the switch.
                        backfill.refreshQueue()
                    }
                if backfill.hasPendingWork {
                    HStack {
                        Text("backfill_in_progress")
                        Spacer()
                        Text(String(format: String(localized: "backfill_remaining"), backfill.remainingCount))
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }
                }
            } header: {
                Text("network")
            } footer: {
                Text("cloud_scan_wifi_only_footer")
            }

            Section {
                Toggle("audio_cache_enabled", isOn: $settings.audioCacheEnabled)

                storageRow(
                    icon: "waveform",
                    title: "audio_cache",
                    size: audioCacheSize,
                    isClearing: isClearingAudio
                ) {
                    isClearingAudio = true
                    Task {
                        let result = sourceManager.clearAudioCache()
                        await refreshSizes()
                        isClearingAudio = false
                        flashCacheToast(freed: result.freedBytes, failed: result.failedCount)
                    }
                }

                if let bd = audioBreakdown {
                    audioBreakdownDetail(bd)
                }

                storageRow(
                    icon: "photo",
                    title: "image_cache",
                    size: imageCacheSize,
                    isClearing: isClearingImages
                ) {
                    isClearingImages = true
                    Task {
                        try? await ImageCache.shared.clearDiskCache()
                        CachedArtworkView.clearMemoryCache()
                        await refreshSizes()
                        isClearingImages = false
                    }
                }
            } header: {
                Text("cache")
            } footer: {
                Text("cache_clear_footer")
            }

            Section {
                storageRow(
                    icon: "music.note.list",
                    title: "cover_art_lyrics",
                    size: metadataSize,
                    isClearing: isClearingMetadata
                ) {
                    isClearingMetadata = true
                    Task {
                        await MetadataAssetStore.shared.clearAll()
                        CachedArtworkView.clearMemoryCache()
                        await refreshSizes()
                        isClearingMetadata = false
                    }
                }
            } header: {
                Text("persistent_data")
            } footer: {
                Text("metadata_clear_footer")
            }

            // Debug 区只在 Debug 构建里显示 —— 生产 Release 不出现这个入口,
            // 普通用户看不到 (避免误触把开发日志泄露)。
            #if DEBUG
            Section {
                Button {
                    logShareItem = LogShareItem(url: FileLogger.shared.logFileURL)
                } label: {
                    Label("storage_export_log", systemImage: "square.and.arrow.up.on.square")
                }
            } header: {
                Text("debug")
            } footer: {
                Text("storage_export_log_footer")
            }
            #endif
        }
        #if os(iOS)
        .sheet(item: $logShareItem) { item in
            ShareSheet(items: [item.url])
        }
        #endif
        .navigationTitle("storage_management")
        .navigationBarTitleDisplayMode(.inline)
        .task { await refreshSizes() }
        .overlay(alignment: .bottom) {
            if let msg = cacheActionToast {
                Text(msg)
                    .font(.subheadline)
                    .padding(.horizontal, 16).padding(.vertical, 10)
                    .background(.thinMaterial, in: Capsule())
                    .padding(.bottom, 24)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
    }

    private func flashCacheToast(freed: Int64, failed: Int) {
        let fmt = ByteCountFormatter()
        fmt.countStyle = .file
        let freedStr = fmt.string(fromByteCount: freed)
        let msg: String
        if failed > 0 {
            // 通常是当前正在播放的歌锁住了文件 — 提示一下用户暂停后重试
            msg = String(format: String(localized: "cache_clear_partial_format"), freedStr, failed)
        } else {
            msg = String(format: String(localized: "cache_clear_done_format"), freedStr)
        }
        withAnimation { cacheActionToast = msg }
        Task {
            try? await Task.sleep(for: .seconds(3))
            withAnimation { cacheActionToast = nil }
        }
    }

    private func storageRow(
        icon: String,
        title: LocalizedStringKey,
        size: String,
        isClearing: Bool,
        onClear: @escaping () -> Void
    ) -> some View {
        HStack {
            Label(title, systemImage: icon)
            Spacer()
            if isClearing {
                ProgressView()
            } else {
                Text(size)
                    .foregroundStyle(.secondary)
            }
            Button(role: .destructive) { onClear() } label: {
                Image(systemName: "trash")
                    .font(.caption)
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .disabled(isClearing)
        }
    }

    @ViewBuilder
    private func audioBreakdownDetail(_ bd: SourceManager.AudioCacheBreakdown) -> some View {
        let fmt = ByteCountFormatter()
        let _ = (fmt.countStyle = .file)

        // 缩进 + 小一号字, 提示是 audio cache 的细分
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "checkmark.circle")
                    .foregroundStyle(.secondary).font(.caption)
                Text("cache_completed").font(.caption).foregroundStyle(.secondary)
                Spacer()
                Text(fmt.string(fromByteCount: bd.completedBytes))
                    .font(.caption).foregroundStyle(.secondary).monospacedDigit()
            }

            if bd.activeBytes > 0 {
                HStack {
                    Image(systemName: "play.circle")
                        .foregroundStyle(.blue).font(.caption)
                    Text("cache_active").font(.caption).foregroundStyle(.secondary)
                    Spacer()
                    Text(fmt.string(fromByteCount: bd.activeBytes))
                        .font(.caption).foregroundStyle(.blue).monospacedDigit()
                }
            }

            if bd.prewarmSeedBytes > 0 {
                HStack {
                    Image(systemName: "bolt.circle")
                        .foregroundStyle(.secondary).font(.caption)
                    Text("cache_prewarm_seed").font(.caption).foregroundStyle(.secondary)
                    Spacer()
                    Text(fmt.string(fromByteCount: bd.prewarmSeedBytes))
                        .font(.caption).foregroundStyle(.secondary).monospacedDigit()
                }
            }

            HStack {
                Image(systemName: "ellipsis.circle")
                    .foregroundStyle(.secondary).font(.caption)
                Text("cache_partial").font(.caption).foregroundStyle(.secondary)
                Spacer()
                Text(fmt.string(fromByteCount: bd.partialBytes))
                    .font(.caption).foregroundStyle(.secondary).monospacedDigit()
                if bd.partialBytes > 0 {
                    Button(role: .destructive) {
                        isClearingPartials = true
                        Task {
                            let result = sourceManager.purgeAllPartialFiles()
                            await refreshSizes()
                            isClearingPartials = false
                            flashCacheToast(freed: result.freedBytes, failed: result.failedCount)
                        }
                    } label: {
                        if isClearingPartials {
                            ProgressView().controlSize(.mini)
                        } else {
                            Image(systemName: "trash").font(.caption2)
                        }
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.mini)
                    .disabled(isClearingPartials)
                }
            }

            if bd.orphanedBytes > 0 {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange).font(.caption)
                    Text("cache_orphaned").font(.caption).foregroundStyle(.secondary)
                    Spacer()
                    Text(fmt.string(fromByteCount: bd.orphanedBytes))
                        .font(.caption).foregroundStyle(.orange).monospacedDigit()
                    Button(role: .destructive) {
                        isClearingOrphans = true
                        Task {
                            await sourceManager.purgeOrphanedAudioCache()
                            await refreshSizes()
                            isClearingOrphans = false
                        }
                    } label: {
                        if isClearingOrphans {
                            ProgressView().controlSize(.mini)
                        } else {
                            Image(systemName: "trash").font(.caption2)
                        }
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.mini)
                    .disabled(isClearingOrphans)
                }
            }
        }
        .padding(.leading, 24)
    }

    private func refreshSizes() async {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file

        let audio = Int64(sourceManager.audioCacheSize())
        audioCacheSize = formatter.string(fromByteCount: audio)
        audioBreakdown = await sourceManager.audioCacheBreakdown()

        let images = (try? await ImageCache.shared.diskCacheSize()) ?? 0
        imageCacheSize = formatter.string(fromByteCount: images)

        let metadata = await MetadataAssetStore.shared.cacheSize()
        metadataSize = formatter.string(fromByteCount: metadata)
    }
}

// MARK: - Trusted Domains

struct TrustedDomainsView: View {
    @State private var newDomain = ""
    @State private var showAddAlert = false

    var body: some View {
        List {
            Section {
                ForEach(SSLTrustStore.shared.trustedDomains, id: \.self) { domain in
                    Text(domain)
                }
                .onDelete { indexSet in
                    let domains = SSLTrustStore.shared.trustedDomains
                    for index in indexSet {
                        SSLTrustStore.shared.untrust(domain: domains[index])
                    }
                }

                if SSLTrustStore.shared.trustedDomains.isEmpty {
                    Text("no_trusted_domains")
                        .foregroundStyle(.secondary)
                }
            } footer: {
                Text("trusted_domains_footer")
            }
        }
        .navigationTitle("trusted_domains")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    newDomain = ""
                    showAddAlert = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .alert("add_trusted_domain", isPresented: $showAddAlert) {
            TextField("domain_placeholder", text: $newDomain)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
            Button("add") {
                let domain = newDomain.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                if !domain.isEmpty {
                    SSLTrustStore.shared.trust(domain: domain)
                }
                newDomain = ""
            }
            Button("cancel", role: .cancel) { newDomain = "" }
        } message: {
            Text("add_trusted_domain_message")
        }
    }
}

struct LicensesView: View {
    var body: some View {
        List {
            Section("open_source") {
                licenseRow("SFBAudioEngine", "MIT License")
                licenseRow("GRDB.swift", "MIT License")
                licenseRow("AMSMB2", "LGPL 2.1")
                licenseRow("FileProvider", "MIT License")
                licenseRow("FLAC", "BSD License")
                licenseRow("mpg123", "LGPL 2.1")
                licenseRow("libsndfile", "LGPL 2.1")
                licenseRow("libogg / libvorbis", "BSD License")
                licenseRow("libopus", "BSD License")
                licenseRow("WavPack", "BSD License")
                licenseRow("Monkey's Audio", "BSD License")
                licenseRow("True Audio (libtta)", "LGPL 2.1")
            }
        }
        .navigationTitle("licenses")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }

    private func licenseRow(_ name: String, _ license: String) -> some View {
        HStack {
            Text(name)
            Spacer()
            Text(license)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}


// MARK: - Share Sheet

#if os(iOS)
/// SwiftUI 包装的 `UIActivityViewController`，让任意 view 通过 `.sheet`
/// 弹出系统分享面板（AirDrop / 微信 / 邮件 / 文件 / 等）。
/// macOS 端用 NSSharingServicePicker，UI 接入方式不同——后续 MacSettingsView
/// 单独适配，本通用 ShareSheet 仅 iOS 编译。
struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ vc: UIActivityViewController, context: Context) {}
}
#endif
