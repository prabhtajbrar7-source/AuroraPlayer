//
//  PlaylistDetailView.swift
//  AuroraPlayer
//

import SwiftUI

struct PlaylistDetailView: View {
    let playlist: Playlist
    @EnvironmentObject var library: LibraryManager
    @EnvironmentObject var queue: QueueManager
    @EnvironmentObject var theme: ThemeManager

    var body: some View {
        let songs = library.songs(in: playlist)

        ZStack {
            theme.backgroundGradient.ignoresSafeArea()

            List {
                Section {
                    header(songCount: songs.count)
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                }

                ForEach(songs) { song in
                    SongRowView(
                        song: song,
                        isPlaying: queue.nowPlayingSong?.id == song.id,
                        onTap: { queue.playAll(songs, startingAt: songs.firstIndex(of: song) ?? 0) },
                        onPlayNext: { queue.playNext(song) },
                        onAddToQueue: { queue.addToQueue(song) },
                        onToggleFavorite: { library.toggleFavorite(song) }
                    )
                    .listRowBackground(Color.clear)
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
        }
        .navigationTitle(playlist.name)
        .navigationBarTitleDisplayMode(.inline)
    }

    private func header(songCount: Int) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            if playlist.isAIGenerated, let prompt = playlist.sourcePrompt {
                Label("AI-generated from “\(prompt)”", systemImage: "sparkles")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Button {
                let songs = library.songs(in: playlist)
                guard !songs.isEmpty else { return }
                queue.playAll(songs)
            } label: {
                Label("Play All", systemImage: "play.fill")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(.vertical, 8)
    }
}
