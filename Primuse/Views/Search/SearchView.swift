import SwiftUI
import PrimuseKit

struct SearchView: View {
    private static let recentSearchesKey = "search_recent_queries"
    private static let recentSearchLimit = 12
    private let contentMaxWidth: CGFloat = 980

    @Environment(AudioPlayerService.self) private var player
    @Environment(MusicLibrary.self) private var library
    @Environment(SourcesStore.self) private var sourcesStore
    @Environment(MetadataBackfillService.self) private var backfill
    @Binding var searchText: String
    @State private var searchResults: [Song] = []
    @State private var recentSearches: [String] = []
    @State private var searchTask: Task<Void, Never>?

    var body: some View {
        NavigationStack {
            Group {
                if searchText.isEmpty {
                    if library.visibleSongs.isEmpty {
                        emptyLibraryView
                    } else {
                        recentSearchView
                    }
                } else if searchResults.isEmpty {
                    noResultsView
                } else {
                    searchResultsView
                }
            }
            .navigationTitle("search_title")
            .toolbarTitleDisplayMode(.inlineLarge)
            .searchable(text: $searchText, prompt: Text("search_prompt"))
            .navigationDestination(for: Album.self) { AlbumDetailView(album: $0) }
            .navigationDestination(for: Artist.self) { ArtistDetailView(artist: $0) }
            .onSubmit(of: .search) {
                addRecentSearch(searchText)
            }
        }
        .onAppear(perform: loadRecentSearches)
        .onReceive(NotificationCenter.default.publisher(for: CloudKVSSync.externalChangeNotification)) { note in
            guard let key = note.userInfo?["key"] as? String,
                  key == Self.recentSearchesKey else { return }
            loadRecentSearches()
        }
        .onChange(of: searchText) { _, newValue in
            performSearch(query: newValue)
        }
        .onDisappear {
            searchTask?.cancel()
        }
    }

    private var recentSearchView: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 28) {
                searchHero

                if !recentSearches.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        sectionHeader("recent_searches") {
                            Button(role: .destructive, action: clearRecentSearches) {
                                Label("clear_all", systemImage: "trash")
                                    .labelStyle(.iconOnly)
                            }
                            .buttonStyle(.borderless)
                            .foregroundStyle(.secondary)
                            .help(Text("clear_all"))
                        }

                        FlowLayout(spacing: 10, rowSpacing: 10) {
                            ForEach(recentSearches, id: \.self) { query in
                                Button {
                                    addRecentSearch(query)
                                    searchText = query
                                } label: {
                                    Label(query, systemImage: "clock")
                                        .font(.callout.weight(.medium))
                                        .lineLimit(1)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 8)
                                        .background(.quaternary, in: .rect(cornerRadius: 8))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }

                libraryOverview

                if !quickSearchSuggestions.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        sectionHeader("recently_added")
                        LazyVGrid(columns: [
                            GridItem(.adaptive(minimum: 180, maximum: 240), spacing: 12, alignment: .top)
                        ], alignment: .leading, spacing: 12) {
                            ForEach(quickSearchSuggestions, id: \.self) { suggestion in
                                Button {
                                    addRecentSearch(suggestion)
                                    searchText = suggestion
                                } label: {
                                    HStack(spacing: 10) {
                                        Image(systemName: "magnifyingglass")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                            .frame(width: 22, height: 22)
                                            .background(.quaternary, in: .circle)
                                        Text(suggestion)
                                            .font(.callout)
                                            .lineLimit(1)
                                        Spacer(minLength: 0)
                                    }
                                    .padding(10)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(.background.secondary, in: .rect(cornerRadius: 8))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
            }
            .frame(maxWidth: contentMaxWidth, alignment: .leading)
            .padding(.horizontal, 32)
            .padding(.top, 24)
            .padding(.bottom, 108)
            .frame(maxWidth: .infinity, alignment: .top)
        }
    }

    private var searchResultsView: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 28) {
                resultSummary

                if !matchingAlbums.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        sectionHeader("tab_albums")
                        LazyVGrid(columns: [
                            GridItem(.adaptive(minimum: 180, maximum: 220), spacing: 14, alignment: .top)
                        ], alignment: .leading, spacing: 16) {
                            ForEach(matchingAlbums.prefix(8)) { album in
                                NavigationLink(value: album) {
                                    albumResultCard(album)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }

                if !matchingArtists.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        sectionHeader("tab_artists")
                        ScrollView(.horizontal, showsIndicators: false) {
                            LazyHStack(spacing: 12) {
                                ForEach(matchingArtists.prefix(10)) { artist in
                                    NavigationLink(value: artist) {
                                        artistResultChip(artist)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 10) {
                    sectionHeader("tab_songs")
                    LazyVStack(spacing: 0) {
                        ForEach(searchResults.prefix(40)) { song in
                            SongRowView(
                                song: song,
                                isPlaying: player.currentSong?.id == song.id,
                                context: SongRowView.context(for: song, sourcesStore: sourcesStore, backfill: backfill)
                            )
                            .padding(.vertical, 8)
                            .contentShape(Rectangle())
                            .onTapGesture { playSong(song) }

                            if song.id != searchResults.prefix(40).last?.id {
                                Divider()
                                    .padding(.leading, 54)
                            }
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 4)
                    .background(.background.secondary, in: .rect(cornerRadius: 8))
                }
            }
            .frame(maxWidth: contentMaxWidth, alignment: .leading)
            .padding(.horizontal, 32)
            .padding(.top, 24)
            .padding(.bottom, 108)
            .frame(maxWidth: .infinity, alignment: .top)
        }
    }

    private var emptyLibraryView: some View {
        ContentUnavailableView(
            "search_empty_library",
            systemImage: "magnifyingglass",
            description: Text("search_empty_library_desc")
        )
    }

    private var noResultsView: some View {
        VStack(spacing: 14) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 42, weight: .semibold))
                .foregroundStyle(.tertiary)
            Text(searchText)
                .font(.title3.weight(.semibold))
                .lineLimit(1)
            Text("search_prompt")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .padding(.bottom, 80)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var searchHero: some View {
        HStack(alignment: .center, spacing: 18) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(.background.secondary)
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
            .frame(width: 74, height: 74)

            VStack(alignment: .leading, spacing: 6) {
                Text("search_title")
                    .font(.system(size: 32, weight: .bold))
                Text(librarySummary)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
        }
    }

    private var resultSummary: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(searchText)
                .font(.system(size: 30, weight: .bold))
                .lineLimit(1)
            Text(resultSummaryText)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
    }

    private var libraryOverview: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("library")
            LazyVGrid(columns: [
                GridItem(.adaptive(minimum: 160, maximum: 240), spacing: 12, alignment: .top)
            ], alignment: .leading, spacing: 12) {
                statTile(value: library.visibleSongs.count, title: "tab_songs", icon: "music.note", color: .blue)
                statTile(value: library.visibleAlbums.count, title: "tab_albums", icon: "square.stack.fill", color: .purple)
                statTile(value: library.visibleArtists.count, title: "tab_artists", icon: "music.mic", color: .pink)
            }
        }
    }

    private func sectionHeader(_ title: LocalizedStringKey) -> some View {
        sectionHeader(title) { EmptyView() }
    }

    private func sectionHeader<Trailing: View>(
        _ title: LocalizedStringKey,
        @ViewBuilder trailing: () -> Trailing
    ) -> some View {
        HStack {
            Text(title)
                .font(.headline)
            Spacer()
            trailing()
        }
    }

    private func statTile(value: Int, title: LocalizedStringKey, icon: String, color: Color) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.headline)
                .foregroundStyle(color)
                .frame(width: 34, height: 34)
                .background(color.opacity(0.14), in: .rect(cornerRadius: 8))
            VStack(alignment: .leading, spacing: 2) {
                Text(value, format: .number)
                    .font(.title3.weight(.semibold))
                    .monospacedDigit()
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .background(.background.secondary, in: .rect(cornerRadius: 8))
    }

    private func albumResultCard(_ album: Album) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            CachedArtworkView(
                albumID: album.id,
                albumTitle: album.title,
                artistName: album.artistName,
                size: 156,
                cornerRadius: 8
            )
            .aspectRatio(1, contentMode: .fit)
            .shadow(color: .black.opacity(0.16), radius: 6, y: 3)

            Text(album.title)
                .font(.callout.weight(.medium))
                .lineLimit(1)
            Text(album.artistName ?? "\(album.songCount) \(String(localized: "tab_songs"))")
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
    }

    private func artistResultChip(_ artist: Artist) -> some View {
        HStack(spacing: 10) {
            CachedArtworkView(
                artistID: artist.id,
                artistName: artist.name,
                size: 44,
                cornerRadius: 22
            )
            VStack(alignment: .leading, spacing: 2) {
                Text(artist.name)
                    .font(.callout.weight(.medium))
                    .lineLimit(1)
                Text("\(artist.songCount) \(String(localized: "tab_songs"))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(width: 130, alignment: .leading)
        }
        .padding(8)
        .background(.background.secondary, in: .rect(cornerRadius: 8))
    }

    private var matchingAlbums: [Album] {
        library.visibleAlbums.filter {
            $0.title.localizedCaseInsensitiveContains(searchText)
            || ($0.artistName?.localizedCaseInsensitiveContains(searchText) ?? false)
        }
    }

    private var matchingArtists: [Artist] {
        library.visibleArtists.filter {
            $0.name.localizedCaseInsensitiveContains(searchText)
        }
    }

    private var quickSearchSuggestions: [String] {
        let albumTitles = library.recentlyAddedAlbums(limit: 4).map(\.title)
        let artistNames = library.visibleArtists.prefix(4).map(\.name)
        var seen = Set<String>()
        return (albumTitles + artistNames).filter { seen.insert($0).inserted }.prefix(6).map { $0 }
    }

    private var librarySummary: String {
        "\(library.visibleSongs.count) \(String(localized: "tab_songs")) · \(library.visibleAlbums.count) \(String(localized: "tab_albums")) · \(library.visibleArtists.count) \(String(localized: "tab_artists"))"
    }

    private var resultSummaryText: String {
        "\(searchResults.count) \(String(localized: "tab_songs")) · \(matchingAlbums.count) \(String(localized: "tab_albums")) · \(matchingArtists.count) \(String(localized: "tab_artists"))"
    }

    private func performSearch(query: String) {
        searchTask?.cancel()
        guard !query.isEmpty else {
            searchResults = []
            return
        }

        searchTask = Task {
            // Debounce 200ms
            try? await Task.sleep(for: .milliseconds(200))
            guard !Task.isCancelled else { return }

            let results = library.search(query: query)
            searchResults = results
        }
    }

    private func playSong(_ song: Song) {
        let queue = searchResults.filteredPlayable()
        guard let index = queue.firstIndex(where: { $0.id == song.id }) else { return }
        player.setQueue(queue, startAt: index)
        Task { await player.play(song: song) }
        addRecentSearch(searchText)
    }

    private func loadRecentSearches() {
        recentSearches = UserDefaults.standard.stringArray(forKey: Self.recentSearchesKey) ?? []
    }

    private func addRecentSearch(_ query: String) {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedQuery.isEmpty == false else { return }

        recentSearches.removeAll { $0.caseInsensitiveCompare(trimmedQuery) == .orderedSame }
        recentSearches.insert(trimmedQuery, at: 0)

        if recentSearches.count > Self.recentSearchLimit {
            recentSearches = Array(recentSearches.prefix(Self.recentSearchLimit))
        }

        saveRecentSearches()
    }

    private func deleteRecentSearches(at offsets: IndexSet) {
        recentSearches.remove(atOffsets: offsets)
        saveRecentSearches()
    }

    private func clearRecentSearches() {
        recentSearches.removeAll()
        saveRecentSearches()
    }

    private func saveRecentSearches() {
        UserDefaults.standard.set(recentSearches, forKey: Self.recentSearchesKey)
        CloudKVSSync.shared.markChanged(key: Self.recentSearchesKey)
    }
}

private struct FlowLayout: Layout {
    var spacing: CGFloat
    var rowSpacing: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let rows = rows(in: proposal.width ?? .infinity, subviews: subviews)
        return CGSize(
            width: proposal.width ?? rows.map(\.width).max() ?? 0,
            height: rows.reduce(0) { $0 + $1.height } + CGFloat(max(rows.count - 1, 0)) * rowSpacing
        )
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var y = bounds.minY
        for row in rows(in: bounds.width, subviews: subviews) {
            var x = bounds.minX
            for element in row.elements {
                element.subview.place(
                    at: CGPoint(x: x, y: y),
                    anchor: .topLeading,
                    proposal: ProposedViewSize(element.size)
                )
                x += element.size.width + spacing
            }
            y += row.height + rowSpacing
        }
    }

    private func rows(in maxWidth: CGFloat, subviews: Subviews) -> [FlowRow] {
        var rows: [FlowRow] = []
        var current = FlowRow()

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            let nextWidth = current.elements.isEmpty ? size.width : current.width + spacing + size.width

            if nextWidth > maxWidth, !current.elements.isEmpty {
                rows.append(current)
                current = FlowRow()
            }

            current.elements.append(FlowElement(subview: subview, size: size))
            current.width = current.elements.count == 1 ? size.width : current.width + spacing + size.width
            current.height = max(current.height, size.height)
        }

        if !current.elements.isEmpty {
            rows.append(current)
        }

        return rows
    }

    private struct FlowRow {
        var elements: [FlowElement] = []
        var width: CGFloat = 0
        var height: CGFloat = 0
    }

    private struct FlowElement {
        let subview: LayoutSubview
        let size: CGSize
    }
}
