import SwiftUI
import PrimuseKit

struct MiniPlayerView: View {
    var onTap: (() -> Void)? = nil
    @Environment(AudioPlayerService.self) private var player

    var body: some View {
        HStack(spacing: 12) {
            CachedArtworkView(
                coverRef: player.currentSong?.coverArtFileName,
                songID: player.currentSong?.id ?? "",
                size: 46,
                cornerRadius: 10,
                sourceID: player.currentSong?.sourceID,
                filePath: player.currentSong?.filePath
            )
            .shadow(color: .black.opacity(0.16), radius: 8, y: 4)
            .onTapGesture { onTap?() }

            VStack(alignment: .leading, spacing: 5) {
                VStack(alignment: .leading, spacing: 1) {
                    Text(player.currentSong?.title ?? String(localized: "player_empty_title"))
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .lineLimit(1)
                        .foregroundStyle(.primary)
                    Text(player.currentSong?.artistName ?? String(localized: "unknown_artist"))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                ProgressView(value: player.currentTime, total: max(player.duration, 0.01))
                    .progressViewStyle(.linear)
                    .tint(.primary.opacity(0.72))
                    .opacity(player.currentSong == nil ? 0.35 : 1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .onTapGesture { onTap?() }

            HStack(spacing: 2) {
                Button {
                    player.togglePlayPause()
                } label: {
                    ZStack {
                        Image(systemName: "play.fill")
                            .font(.body)
                            .opacity(0)
                        if player.isLoading {
                            ProgressView()
                                .controlSize(.small)
                        } else {
                            Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                                .font(.body)
                                .contentTransition(.symbolEffect(.replace))
                        }
                    }
                    .frame(width: 38, height: 38)
                    .background(.primary.opacity(0.08), in: Circle())
                }
                .buttonStyle(.plain)
                .disabled(player.isLoading)

                Button {
                    Task { await player.next() }
                } label: {
                    Image(systemName: "forward.fill")
                        .font(.caption)
                        .frame(width: 34, height: 34)
                }
                .buttonStyle(.plain)
            }
            .fixedSize()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(.ultraThinMaterial)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(.primary.opacity(0.08), lineWidth: 1)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }
}
