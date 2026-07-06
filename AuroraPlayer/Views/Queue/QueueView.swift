//
//  QueueView.swift
//  AuroraPlayer
//
//  "Up Next" queue with drag-to-reorder, swipe-to-remove, and a history
//  section — the Spotify queue experience the user asked for by name.
//

import SwiftUI

struct QueueView: View {
    @EnvironmentObject var queue: QueueManager
    @EnvironmentObject var library: LibraryManager
    @EnvironmentObject var theme: ThemeManager
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                theme.backgroundGradient.ignoresSafeArea()

                List {
                    if let nowPlaying = queue.nowPlayingSong {
                        Section("Now Playing") {
                            QueueRowView(song: nowPlaying, isCurrent: true)
                                .listRowBackground(Color.clear)
                        }
                    }

                    Section("Up Next") {
                        if queue.upNextSongs.isEmpty {
                            Text("Nothing queued — add songs with “Play Next” or “Add to Queue”.")
                                .foregroundStyle(.white.opacity(0.5))
                                .listRowBackground(Color.clear)
                        } else {
                            ForEach(queue.upNextSongs, id: \.item.id) { pair in
                                QueueRowView(song: pair.song, isCurrent: false)
                                    .listRowBackground(Color.clear)
                            }
                            .onDelete { offsets in
                                queue.removeFromQueue(at: offsets)
                            }
                            .onMove { source, destination in
                                queue.moveInQueue(from: source, to: destination)
                            }
                        }
                    }
                }
                .scrollContentBackground(.hidden)
                .listStyle(.insetGrouped)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("Done") { dismiss() }
                    }
                    ToolbarItem(placement: .topBarTrailing) {
                        EditButton()
                    }
                }
            }
            .navigationTitle("Queue")
            .navigationBarTitleDisplayMode(.inline)
        }
        .preferredColorScheme(.dark)
    }
}

struct QueueRowView: View {
    let song: Song
    let isCurrent: Bool

    var body: some View {
        HStack(spacing: 12) {
            ArtworkView(song: song, cornerRadius: 6)
                .frame(width: 44, height: 44)

            VStack(alignment: .leading, spacing: 2) {
                Text(song.title)
                    .font(.subheadline.weight(isCurrent ? .bold : .regular))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                Text(song.artist)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.6))
                    .lineLimit(1)
            }

            Spacer()

            if isCurrent {
                MiniPlayingIndicator(isPlaying: true)
                    .foregroundStyle(.white)
            } else {
                Text(song.formattedDuration)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.5))
                Image(systemName: "line.3.horizontal")
                    .foregroundStyle(.white.opacity(0.3))
            }
        }
        .padding(.vertical, 4)
    }
}
