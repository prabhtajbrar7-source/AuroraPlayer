//
//  LibraryManager.swift
//  AuroraPlayer
//
//  Owns the song catalog and playlists. Handles the "Local Import" feature:
//  the user picks audio files with the system file picker, we copy them into
//  our sandbox (so they survive even if the original is removed), then read
//  their tags with AVFoundation.
//

import Foundation
import SwiftUI
import UniformTypeIdentifiers
import Combine

@MainActor
final class LibraryManager: ObservableObject {
    static let shared = LibraryManager()

    @Published private(set) var songs: [Song] = []
    @Published private(set) var playlists: [Playlist] = []
    @Published var isImporting: Bool = false
    @Published var importProgress: (done: Int, total: Int) = (0, 0)

    private init() {
        songs = PersistenceManager.shared.loadSongs()
        playlists = PersistenceManager.shared.loadPlaylists()
    }

    var favoriteSongs: [Song] { songs.filter(\.isFavorite) }

    var recentlyAdded: [Song] {
        songs.sorted { $0.dateAdded > $1.dateAdded }
    }

    var mostPlayed: [Song] {
        songs.filter { $0.playCount > 0 }.sorted { $0.playCount > $1.playCount }
    }

    func song(for id: UUID) -> Song? {
        songs.first { $0.id == id }
    }

    // MARK: Import

    /// Content types accepted by the file importer / document picker.
    static let importableTypes: [UTType] = [.audio, .mp3, .wav, .aiff, .mpeg4Audio]

    func importFiles(from urls: [URL]) async {
        isImporting = true
        importProgress = (0, urls.count)
        defer { isImporting = false }

        for url in urls {
            let didStartAccessing = url.startAccessingSecurityScopedResource()
            defer { if didStartAccessing { url.stopAccessingSecurityScopedResource() } }

            let destinationName = "\(UUID().uuidString).\(url.pathExtension)"
            let destination = FileManager.libraryDirectory.appendingPathComponent(destinationName)

            do {
                try FileManager.default.copyItem(at: url, to: destination)
                let song = await Song.makeFromLocalFile(fileName: destinationName)
                songs.append(song)
                importProgress.done += 1
                persistSongs()
            } catch {
                print("Import failed for \(url.lastPathComponent): \(error.localizedDescription)")
            }
        }
    }

    func delete(_ song: Song) {
        try? FileManager.default.removeItem(at: song.fileURL)
        if let artworkURL = song.artworkURL {
            try? FileManager.default.removeItem(at: artworkURL)
        }
        songs.removeAll { $0.id == song.id }
        for index in playlists.indices {
            playlists[index].songIDs.removeAll { $0 == song.id }
        }
        persistSongs()
        persistPlaylists()
    }

    func toggleFavorite(_ song: Song) {
        guard let index = songs.firstIndex(where: { $0.id == song.id }) else { return }
        songs[index].isFavorite.toggle()
        persistSongs()
    }

    func recordPlay(for song: Song) {
        guard let index = songs.firstIndex(where: { $0.id == song.id }) else { return }
        songs[index].playCount += 1
        songs[index].lastPlayedAt = Date()
        persistSongs()
    }

    func recordSkip(for song: Song) {
        guard let index = songs.firstIndex(where: { $0.id == song.id }) else { return }
        songs[index].skipCount += 1
        persistSongs()
    }

    // MARK: Playlists

    func createPlaylist(
        name: String,
        songIDs: [UUID] = [],
        isAIGenerated: Bool = false,
        sourcePrompt: String? = nil,
        iconSymbol: String = "music.note.list",
        colorName: String = "aurora.violet"
    ) -> Playlist {
        let playlist = Playlist(
            name: name,
            songIDs: songIDs,
            isAIGenerated: isAIGenerated,
            sourcePrompt: sourcePrompt,
            iconSymbol: iconSymbol,
            colorName: colorName
        )
        playlists.append(playlist)
        persistPlaylists()
        return playlist
    }

    func delete(playlist: Playlist) {
        playlists.removeAll { $0.id == playlist.id }
        persistPlaylists()
    }

    func add(_ song: Song, to playlist: Playlist) {
        guard let index = playlists.firstIndex(where: { $0.id == playlist.id }) else { return }
        guard !playlists[index].songIDs.contains(song.id) else { return }
        playlists[index].songIDs.append(song.id)
        persistPlaylists()
    }

    func songs(in playlist: Playlist) -> [Song] {
        playlist.songIDs.compactMap { id in songs.first { $0.id == id } }
    }

    // MARK: Persistence

    private func persistSongs() {
        PersistenceManager.shared.saveSongs(songs)
    }

    private func persistPlaylists() {
        PersistenceManager.shared.savePlaylists(playlists)
    }
}
