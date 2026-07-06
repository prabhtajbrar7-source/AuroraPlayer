//
//  LibraryView.swift
//  AuroraPlayer
//

import SwiftUI

struct LibraryView: View {
    @EnvironmentObject var library: LibraryManager
    @EnvironmentObject var queue: QueueManager
    @EnvironmentObject var theme: ThemeManager
    @State private var showImport = false
    @State private var searchText = ""
    @State private var filter: Filter = .songs

    enum Filter: String, CaseIterable { case songs = "Songs", playlists = "Playlists", favorites = "Favorites" }

    var body: some View {
        NavigationStack {
            ZStack {
                theme.backgroundGradient.ignoresSafeArea()

                VStack(spacing: 0) {
                    Picker("Filter", selection: $filter) {
                        ForEach(Filter.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    .padding()

                    if library.songs.isEmpty {
                        emptyState
                    } else {
                        content
                    }
                }
            }
            .navigationTitle("Library")
            .searchable(text: $searchText, prompt: "Search songs, artists, albums")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showImport = true } label: { Image(systemName: "plus") }
                }
            }
            .sheet(isPresented: $showImport) {
                ImportView().environmentObject(library)
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        switch filter {
        case .songs:
            songList(filteredSongs)
        case .favorites:
            songList(filteredSongs.filter(\.isFavorite))
        case .playlists:
            playlistGrid
        }
    }

    private var filteredSongs: [Song] {
        guard !searchText.isEmpty else { return library.recentlyAdded }
        let query = searchText.lowercased()
        return library.songs.filter {
            $0.title.lowercased().contains(query) ||
            $0.artist.lowercased().contains(query) ||
            $0.album.lowercased().contains(query)
        }
    }

    private func songList(_ songs: [Song]) -> some View {
        List {
            ForEach(songs) { song in
                SongRowView(
                    song: song,
                    isPlaying: queue.nowPlayingSong?.id == song.id,
                    onTap: { queue.playAll(songs, startingAt: songs.firstIndex(of: song) ?? 0) },
                    onPlayNext: { queue.playNext(song) },
                    onAddToQueue: { queue.addToQueue(song) },
                    onToggleFavorite: { library.toggleFavorite(song) },
                    onDelete: { library.delete(song) }
                )
                .listRowBackground(Color.clear)
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }

    private var playlistGrid: some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 16)], spacing: 16) {
                ForEach(library.playlists) { playlist in
                    NavigationLink {
                        PlaylistDetailView(playlist: playlist)
                    } label: {
                        PlaylistTile(playlist: playlist)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding()
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "music.note.list")
                .font(.system(size: 50))
                .foregroundStyle(.secondary)
            Text("Your library is empty")
                .font(.title3.bold())
            Text("Import local audio files to get started.")
                .foregroundStyle(.secondary)
            Button("Import Music") { showImport = true }
                .buttonStyle(.borderedProminent)
                .padding(.top, 8)
            Spacer()
        }
    }
}

struct PlaylistTile: View {
    let playlist: Playlist
    @EnvironmentObject var library: LibraryManager

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(hex: colorHex(for: playlist.colorName)).gradient)
                .aspectRatio(1, contentMode: .fit)
                .overlay(Image(systemName: playlist.iconSymbol).font(.title).foregroundStyle(.white))

            Text(playlist.name)
                .font(.subheadline.bold())
                .lineLimit(1)
            Text("\(playlist.songIDs.count) songs")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func colorHex(for name: String) -> String {
        switch name {
        case "aurora.violet": return "7F5AF0"
        case "aurora.teal": return "2CB1BC"
        case "aurora.sunset": return "FF8A5B"
        default: return "7F5AF0"
        }
    }
}
