//
//  SongRowView.swift
//  AuroraPlayer
//

import SwiftUI

struct SongRowView: View {
    let song: Song
    var isPlaying: Bool = false
    var onTap: () -> Void
    var onPlayNext: (() -> Void)? = nil
    var onAddToQueue: (() -> Void)? = nil
    var onToggleFavorite: (() -> Void)? = nil
    var onDelete: (() -> Void)? = nil

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                ArtworkView(song: song, cornerRadius: 8)
                    .frame(width: 50, height: 50)

                VStack(alignment: .leading, spacing: 2) {
                    Text(song.title)
                        .font(.subheadline.weight(isPlaying ? .bold : .medium))
                        .foregroundStyle(isPlaying ? Color.accentColor : .primary)
                        .lineLimit(1)
                    Text("\(song.artist) — \(song.album)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer()

                if isPlaying {
                    MiniPlayingIndicator(isPlaying: true)
                        .foregroundStyle(Color.accentColor)
                } else {
                    Text(song.formattedDuration)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .contextMenu {
            if let onPlayNext {
                Button { onPlayNext() } label: { Label("Play Next", systemImage: "text.line.first.and.arrowtriangle.forward") }
            }
            if let onAddToQueue {
                Button { onAddToQueue() } label: { Label("Add to Queue", systemImage: "text.badge.plus") }
            }
            if let onToggleFavorite {
                Button { onToggleFavorite() } label: {
                    Label(song.isFavorite ? "Remove from Favorites" : "Add to Favorites",
                          systemImage: song.isFavorite ? "heart.slash" : "heart")
                }
            }
            if let onDelete {
                Button(role: .destructive) { onDelete() } label: { Label("Delete", systemImage: "trash") }
            }
        }
    }
}
