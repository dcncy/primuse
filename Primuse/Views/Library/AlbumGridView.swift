import SwiftUI
import PrimuseKit

struct AlbumGridView: View {
    @Environment(MusicLibrary.self) private var library
    @State private var searchText: String = ""
    private let columns = [
        GridItem(.adaptive(minimum: 150), spacing: 16)
    ]

    private var filteredAlbums: [Album] {
        let q = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return library.visibleAlbums }
        return library.visibleAlbums.filter {
            $0.title.localizedCaseInsensitiveContains(q)
            || ($0.artistName?.localizedCaseInsensitiveContains(q) ?? false)
        }
    }

    var body: some View {
        if library.visibleAlbums.isEmpty {
            ContentUnavailableView(
                "no_albums",
                systemImage: "square.stack",
                description: Text("no_albums_desc")
            )
        } else {
            #if os(macOS)
            macAlbumGrid
            #else
            iosAlbumGrid
            #endif
        }
    }

    private var iosAlbumGrid: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 20) {
                ForEach(filteredAlbums) { album in
                    NavigationLink(value: album) {
                        AlbumCardView(album: album)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding()
        }
        .searchable(text: $searchText,
                    placement: .toolbar,
                    prompt: Text("search_albums_prompt"))
    }

    #if os(macOS)
    private var macAlbumGrid: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 18) {
                macSummaryHeader

                if filteredAlbums.isEmpty {
                    ContentUnavailableView.search(text: searchText)
                        .padding(.top, 48)
                } else {
                    LazyVGrid(
                        columns: [GridItem(.adaptive(minimum: 170, maximum: 220), spacing: 16, alignment: .top)],
                        alignment: .leading,
                        spacing: 18
                    ) {
                        ForEach(filteredAlbums) { album in
                            NavigationLink(value: album) {
                                macAlbumCard(album)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 16)
            .padding(.bottom, 112)
        }
        .searchable(text: $searchText,
                    placement: .toolbar,
                    prompt: Text("search_albums_prompt"))
    }

    private var macSummaryHeader: some View {
        HStack(spacing: 14) {
            Image(systemName: "square.stack.fill")
                .font(.title2.weight(.semibold))
                .foregroundStyle(Color.purple)
                .frame(width: 52, height: 52)
                .background(Color.purple.opacity(0.16), in: .rect(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 4) {
                Text("tab_albums")
                    .font(.title3.weight(.semibold))
                Text("\(library.visibleAlbums.count) \(String(localized: "albums_count")) · \(library.visibleArtists.count) \(String(localized: "artists_count"))")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(16)
        .frame(maxWidth: 720, alignment: .leading)
        .background(.background.secondary, in: .rect(cornerRadius: 8))
    }

    private func macAlbumCard(_ album: Album) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            CachedArtworkView(albumID: album.id, albumTitle: album.title,
                              artistName: album.artistName, cornerRadius: 9)
                .aspectRatio(1, contentMode: .fit)
                .shadow(color: .black.opacity(0.10), radius: 8, y: 4)

            VStack(alignment: .leading, spacing: 3) {
                Text(album.title)
                    .font(.callout.weight(.semibold))
                    .lineLimit(1)

                Text(album.artistName ?? String(localized: "unknown_artist"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(10)
        .background(.background.secondary, in: .rect(cornerRadius: 8))
    }
    #endif
}
