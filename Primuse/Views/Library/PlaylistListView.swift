import SwiftUI
import PrimuseKit

struct PlaylistListView: View {
    @Environment(MusicLibrary.self) private var library
    @State private var showNewPlaylist = false
    @State private var newPlaylistName = ""

    private var playlists: [Playlist] {
        library.playlists
    }

    var body: some View {
        #if os(macOS)
        macBody
        #else
        iosBody
        #endif
    }

    @ViewBuilder
    private var iosBody: some View {
        Group {
            if playlists.isEmpty {
                ContentUnavailableView {
                    Label("no_playlists", systemImage: "music.note.list")
                } description: {
                    Text("no_playlists_desc")
                } actions: {
                    Button("new_playlist") {
                        showNewPlaylist = true
                    }
                    .buttonStyle(.borderedProminent)
                }
            } else {
                List {
                    ForEach(playlists) { playlist in
                        NavigationLink(value: playlist) {
                            HStack(spacing: 12) {
                                StoredCoverArtView(fileName: playlist.coverArtPath, size: 48, cornerRadius: 8)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(playlist.name)
                                        .font(.body)

                                    HStack(spacing: 4) {
                                        Text("\(library.songs(forPlaylist: playlist.id).count) \(String(localized: "songs_count"))")
                                        Text("·")
                                        Text(playlist.updatedAt, style: .date)
                                    }
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                }
                                Spacer(minLength: 0)
                            }
                        }
                    }
                    .onDelete(perform: deletePlaylists)
                }
                .listStyle(.plain)
            }
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showNewPlaylist = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .alert("new_playlist", isPresented: $showNewPlaylist) {
            TextField("playlist_name", text: $newPlaylistName)
            Button("cancel", role: .cancel) {
                newPlaylistName = ""
            }
            Button("create") {
                createPlaylist()
            }
        }
    }

    #if os(macOS)
    @ViewBuilder
    private var macBody: some View {
        Group {
            if playlists.isEmpty {
                ContentUnavailableView {
                    Label("no_playlists", systemImage: "music.note.list")
                } description: {
                    Text("no_playlists_desc")
                } actions: {
                    Button("new_playlist") {
                        showNewPlaylist = true
                    }
                    .buttonStyle(.borderedProminent)
                }
            } else {
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 18) {
                        playlistOverview

                        LazyVStack(spacing: 10) {
                            ForEach(playlists) { playlist in
                                NavigationLink(value: playlist) {
                                    playlistCard(playlist)
                                }
                                .buttonStyle(.plain)
                                .contextMenu {
                                    Button(role: .destructive) {
                                        library.deletePlaylist(id: playlist.id)
                                    } label: {
                                        Label("delete", systemImage: "trash")
                                    }
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 16)
                    .padding(.bottom, 112)
                    .frame(maxWidth: 860, alignment: .leading)
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                }
            }
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showNewPlaylist = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .alert("new_playlist", isPresented: $showNewPlaylist) {
            TextField("playlist_name", text: $newPlaylistName)
            Button("cancel", role: .cancel) {
                newPlaylistName = ""
            }
            Button("create") {
                createPlaylist()
            }
        }
    }

    private var playlistOverview: some View {
        HStack(spacing: 14) {
            Image(systemName: "music.note.list")
                .font(.title2.weight(.semibold))
                .foregroundStyle(Color.accentColor)
                .frame(width: 52, height: 52)
                .background(.tint.opacity(0.14), in: .rect(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 4) {
                Text("tab_playlists")
                    .font(.title3.weight(.semibold))
                Text("\(playlists.count) · \(totalPlaylistSongs) \(String(localized: "songs_count"))")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.background.secondary, in: .rect(cornerRadius: 8))
    }

    private var totalPlaylistSongs: Int {
        playlists.reduce(0) { partialResult, playlist in
            partialResult + library.songs(forPlaylist: playlist.id).count
        }
    }

    private func playlistCard(_ playlist: Playlist) -> some View {
        let count = library.songs(forPlaylist: playlist.id).count
        return HStack(spacing: 14) {
            StoredCoverArtView(fileName: playlist.coverArtPath, size: 58, cornerRadius: 8)

            VStack(alignment: .leading, spacing: 4) {
                Text(playlist.name)
                    .font(.headline)
                    .lineLimit(1)

                HStack(spacing: 5) {
                    Text("\(count) \(String(localized: "songs_count"))")
                    Text("·")
                    Text(playlist.updatedAt, style: .date)
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)

            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(12)
        .frame(maxWidth: .infinity, minHeight: 82, alignment: .leading)
        .background(.background.secondary, in: .rect(cornerRadius: 8))
    }
    #endif

    private func createPlaylist() {
        let trimmedName = newPlaylistName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedName.isEmpty == false else { return }
        _ = library.createPlaylist(name: trimmedName)
        newPlaylistName = ""
    }

    private func deletePlaylists(at offsets: IndexSet) {
        for index in offsets {
            library.deletePlaylist(id: playlists[index].id)
        }
    }
}
