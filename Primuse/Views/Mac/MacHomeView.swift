#if os(macOS)
import SwiftUI
import PrimuseKit

/// macOS home as a real library dashboard. It uses the user's own cover art
/// and live source/scan/backfill state, so the first screen explains what
/// Primuse is managing instead of just showing another content list.
struct MacHomeView: View {
    @Environment(MusicLibrary.self) private var library
    @Environment(AudioPlayerService.self) private var player
    @Environment(SourcesStore.self) private var sourcesStore
    @Environment(ScanService.self) private var scanService
    @Environment(MetadataBackfillService.self) private var backfill

    private var hasContent: Bool { !library.visibleSongs.isEmpty }

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 28) {
                heroSection

                if hasContent {
                    dashboardGrid
                    recentlyAddedAlbumsSection
                    recentlyPlayedSection
                    if !library.visibleArtists.isEmpty {
                        artistsSection
                    }
                } else {
                    emptyState
                }
            }
            .padding(.horizontal, 32)
            .padding(.top, 24)
            .padding(.bottom, 104)
        }
    }

    // MARK: - Hero

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<12: return String(localized: "greeting_morning")
        case 12..<18: return String(localized: "greeting_afternoon")
        case 18..<22: return String(localized: "greeting_evening")
        default: return String(localized: "greeting_night")
        }
    }

    private var heroSection: some View {
        HStack(alignment: .center, spacing: 28) {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(greeting)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                    Text("home_dashboard_title")
                        .font(.system(size: 36, weight: .bold))
                        .lineLimit(2)
                    Text("home_dashboard_subtitle")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                HStack(spacing: 10) {
                    Button { playLibrary(shuffled: true) } label: {
                        Label("shuffle", systemImage: "shuffle")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)

                    Button { playLibrary(shuffled: false) } label: {
                        Label("play_all", systemImage: "play.fill")
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                }
                .disabled(!hasContent)
            }

            Spacer(minLength: 20)

            coverMosaic
                .frame(width: 316, height: 206)
        }
        .padding(22)
        .background(.background.secondary, in: .rect(cornerRadius: 8))
    }

    private var coverMosaic: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(.quaternary)

            LazyVGrid(columns: Array(repeating: GridItem(.fixed(88), spacing: 8), count: 3), spacing: 8) {
                ForEach(Array(mosaicSongs.prefix(6).enumerated()), id: \.element.id) { index, song in
                    CachedArtworkView(
                        coverRef: song.coverArtFileName,
                        songID: song.id,
                        size: 88,
                        cornerRadius: 7,
                        sourceID: song.sourceID,
                        filePath: song.filePath
                    )
                    .rotationEffect(.degrees(index.isMultiple(of: 2) ? -1.5 : 1.5))
                    .shadow(color: .black.opacity(0.14), radius: 5, y: 3)
                }
            }
            .padding(14)

            if mosaicSongs.isEmpty {
                Image(systemName: "music.note.list")
                    .font(.system(size: 44, weight: .semibold))
                    .foregroundStyle(.tertiary)
            }
        }
    }

    private var mosaicSongs: [Song] {
        let recent = library.recentlyPlayedSongs(limit: 12)
        let added = library.visibleSongs.sorted { $0.dateAdded > $1.dateAdded }.prefix(40)
        var pool = recent
        for song in added where !pool.contains(where: { $0.id == song.id }) {
            pool.append(song)
        }
        let covered = pool.filter { $0.coverArtFileName?.isEmpty == false }
        return Array((covered.isEmpty ? pool : covered).prefix(6))
    }

    // MARK: - Dashboard

    private var dashboardGrid: some View {
        LazyVGrid(columns: [
            GridItem(.adaptive(minimum: 280, maximum: 420), spacing: 14, alignment: .top)
        ], alignment: .leading, spacing: 14) {
            libraryHealthCard
            sourceStatusCard
            pipelineCard
        }
    }

    private var libraryHealthCard: some View {
        dashboardCard(title: "home_health_title", icon: "waveform.path.ecg") {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 12) {
                    metricBlock(value: library.visibleSongs.count, label: "tab_songs")
                    metricBlock(value: library.visibleAlbums.count, label: "tab_albums")
                    metricBlock(value: library.visibleArtists.count, label: "tab_artists")
                }
                healthRow("home_cover_art", value: coverRatio, color: .purple)
                healthRow("home_lyrics", value: lyricsRatio, color: .teal)
                healthRow("home_playable", value: playableRatio, color: .green)
            }
        }
    }

    private var sourceStatusCard: some View {
        dashboardCard(title: "home_sources_title", icon: "externaldrive.connected.to.line.below") {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 12) {
                    metricBlock(value: enabledSourcesCount, label: "home_enabled_sources")
                    metricBlock(value: activeScans.count, label: "home_active_scans")
                    metricBlock(value: backfill.remainingCount(forSource: nil), label: "home_pending_details")
                }

                if let scan = activeScans.first {
                    VStack(alignment: .leading, spacing: 6) {
                        ProgressView(value: scan.totalCount > 0 ? min(scan.progress, 1) : nil)
                        Text(scan.currentFile.isEmpty ? String(localized: "scan_in_progress") : scan.currentFile)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                } else {
                    Label("home_no_scans", systemImage: "checkmark.circle.fill")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var pipelineCard: some View {
        dashboardCard(title: "home_source_pipeline", icon: "point.3.connected.trianglepath.dotted") {
            HStack(spacing: 0) {
                pipelineNode("externaldrive.fill", "home_pipeline_sources", isActive: !sourcesStore.sources.isEmpty)
                pipelineLine()
                pipelineNode("waveform.badge.magnifyingglass", "home_pipeline_scan", isActive: !activeScans.isEmpty || hasContent)
                pipelineLine()
                pipelineNode("wand.and.stars", "home_pipeline_metadata", isActive: backfill.remainingCount(forSource: nil) == 0 && hasContent)
                pipelineLine()
                pipelineNode("play.fill", "home_pipeline_listen", isActive: player.currentSong != nil)
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 4)
        }
    }

    private func dashboardCard<Content: View>(
        title: LocalizedStringKey,
        icon: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .foregroundStyle(.secondary)
                    .frame(width: 20)
                Text(title)
                    .font(.headline)
                Spacer()
            }
            content()
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.background.secondary, in: .rect(cornerRadius: 8))
    }

    private func metricBlock(value: Int, label: LocalizedStringKey) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value, format: .number)
                .font(.title3.weight(.semibold))
                .monospacedDigit()
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func healthRow(_ title: LocalizedStringKey, value: Double, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                Text(title)
                Spacer()
                Text(value, format: .percent.precision(.fractionLength(0)))
                    .monospacedDigit()
            }
            .font(.caption)
            .foregroundStyle(.secondary)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(.quaternary)
                    Capsule()
                        .fill(color.gradient)
                        .frame(width: geo.size.width * min(max(value, 0), 1))
                }
            }
            .frame(height: 6)
        }
    }

    private func pipelineNode(_ icon: String, _ title: LocalizedStringKey, isActive: Bool) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(isActive ? Color.accentColor : .secondary)
                .frame(width: 34, height: 34)
                .background(isActive ? Color.accentColor.opacity(0.16) : Color.secondary.opacity(0.10),
                            in: .circle)
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .frame(width: 66)
    }

    private func pipelineLine() -> some View {
        Rectangle()
            .fill(.quaternary)
            .frame(height: 2)
            .frame(maxWidth: .infinity)
            .padding(.bottom, 20)
    }

    private var activeScans: [ScanService.ScanState] {
        scanService.scanStates.values.filter { $0.isScanning || $0.canResume }
    }

    private var enabledSourcesCount: Int {
        sourcesStore.sources.filter(\.isEnabled).count
    }

    private var coverRatio: Double { ratio(count: library.visibleSongs.filter { $0.coverArtFileName?.isEmpty == false }.count) }
    private var lyricsRatio: Double { ratio(count: library.visibleSongs.filter { $0.lyricsFileName?.isEmpty == false }.count) }
    private var playableRatio: Double { ratio(count: library.visibleSongs.filter(\.isPlayable).count) }

    private func ratio(count: Int) -> Double {
        guard !library.visibleSongs.isEmpty else { return 0 }
        return Double(count) / Double(library.visibleSongs.count)
    }

    private var librarySummary: String {
        let songs = String(localized: "tab_songs")
        let albums = String(localized: "tab_albums")
        let artists = String(localized: "tab_artists")
        return "\(library.songCount) \(songs) · \(library.albumCount) \(albums) · \(library.artistCount) \(artists)"
    }

    // MARK: - Recently Added

    private var recentlyAddedAlbumsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("recently_added")
                .font(.title3).fontWeight(.semibold)

            LazyVGrid(columns: [
                GridItem(.adaptive(minimum: 130, maximum: 170), spacing: 18, alignment: .top)
            ], alignment: .leading, spacing: 22) {
                ForEach(library.recentlyAddedAlbums(limit: 12)) { album in
                    Button { playAlbum(album) } label: {
                        albumCard(album)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func albumCard(_ album: Album) -> some View {
        let song = library.songs(forAlbum: album.id).first
        return VStack(alignment: .leading, spacing: 8) {
            CachedArtworkView(
                coverRef: song?.coverArtFileName,
                songID: song?.id ?? "",
                cornerRadius: 8,
                sourceID: song?.sourceID,
                filePath: song?.filePath
            )
            .aspectRatio(1, contentMode: .fit)
            .shadow(color: .black.opacity(0.18), radius: 6, y: 3)

            Text(album.title)
                .font(.callout)
                .fontWeight(.medium)
                .lineLimit(1)
            if let artist = album.artistName {
                Text(artist)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
    }

    // MARK: - Recently Played

    private var recentlyPlayedSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("recently_played")
                .font(.title3).fontWeight(.semibold)

            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 10) {
                    ForEach(recentSongs) { song in
                        Button { playSong(song) } label: {
                            recentSongChip(song)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private func recentSongChip(_ song: Song) -> some View {
        HStack(spacing: 10) {
            CachedArtworkView(
                coverRef: song.coverArtFileName,
                songID: song.id,
                size: 44,
                cornerRadius: 6,
                sourceID: song.sourceID,
                filePath: song.filePath
            )
            VStack(alignment: .leading, spacing: 2) {
                Text(song.title)
                    .font(.caption)
                    .fontWeight(.medium)
                    .lineLimit(1)
                Text(song.artistName ?? "")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .frame(width: 160, alignment: .leading)
        }
        .padding(8)
        .background(.background.secondary, in: .rect(cornerRadius: 8))
    }

    private var recentSongs: [Song] {
        let recent = library.recentlyPlayedSongs(limit: 18)
        if !recent.isEmpty { return recent }
        return Array(library.visibleSongs.sorted { $0.dateAdded > $1.dateAdded }.prefix(18))
    }

    // MARK: - Artists

    private var artistsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("tab_artists")
                .font(.title3).fontWeight(.semibold)

            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 16) {
                    ForEach(library.visibleArtists.prefix(10)) { artist in
                        NavigationLink(value: artist) {
                            VStack(spacing: 6) {
                                CachedArtworkView(
                                    artistID: artist.id,
                                    artistName: artist.name,
                                    size: 84,
                                    cornerRadius: 42
                                )
                                Text(artist.name)
                                    .font(.caption)
                                    .lineLimit(1)
                                    .frame(width: 84)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    // MARK: - Empty

    private var emptyState: some View {
        VStack(spacing: 18) {
            Spacer().frame(height: 60)
            Image(systemName: "music.note.list")
                .font(.system(size: 56))
                .foregroundStyle(.tertiary)
            Text("welcome_title")
                .font(.title2).fontWeight(.semibold)
            Text("welcome_desc")
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Text("home_empty_mac_hint")
                .font(.caption)
                .foregroundStyle(.tertiary)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Actions

    private func playAlbum(_ album: Album) {
        var queue = library.songs(forAlbum: album.id)
        if queue.count < 20 {
            let existingIDs = Set(queue.map(\.id))
            let extra = library.visibleSongs.filter { !existingIDs.contains($0.id) }.shuffled()
            queue.append(contentsOf: extra)
        }
        queue = queue.filteredPlayable()
        guard let first = queue.first else { return }
        player.shuffleEnabled = false
        player.setQueue(queue, startAt: 0)
        Task { await player.play(song: first) }
    }

    private func playSong(_ song: Song) {
        var queue = library.recentlyPlayedSongs(limit: 50)
        if !queue.contains(where: { $0.id == song.id }) { queue.insert(song, at: 0) }
        if queue.count < 20 {
            let existingIDs = Set(queue.map(\.id))
            queue.append(contentsOf: library.visibleSongs.filter { !existingIDs.contains($0.id) })
        }
        queue = queue.filteredPlayable()
        guard let startIndex = queue.firstIndex(where: { $0.id == song.id }) else { return }
        player.shuffleEnabled = false
        player.setQueue(queue, startAt: startIndex)
        Task { await player.play(song: queue[startIndex]) }
    }

    private func playLibrary(shuffled: Bool) {
        let candidates = library.visibleSongs.filteredPlayable()
        guard !candidates.isEmpty else { return }
        let queue = shuffled ? candidates.shuffled() : candidates
        guard let first = queue.first else { return }
        player.shuffleEnabled = false
        player.setQueue(queue, startAt: 0)
        Task { await player.play(song: first) }
    }
}
#endif
