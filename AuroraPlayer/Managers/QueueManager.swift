//
//  QueueManager.swift
//  AuroraPlayer
//
//  Drives what plays next. Bridges LibraryManager (the catalog) and
//  AudioPlayerManager (the engine) — neither of those needs to know
//  about "queues" or "play next" as a concept, keeping each piece simple.
//

import Foundation
import SwiftUI
import Combine

@MainActor
final class QueueManager: ObservableObject {
    static let shared = QueueManager()

    @Published private(set) var upNext: [QueueItem] = []
    @Published private(set) var history: [QueueItem] = []
    @Published private(set) var nowPlayingItem: QueueItem?
    @Published var crossfadeEnabled: Bool = true

    private let audio = AudioPlayerManager.shared
    private let library = LibraryManager.shared
    private var cancellables = Set<AnyCancellable>()

    private init() {
        audio.onTrackFinished = { [weak self] in
            Task { @MainActor in self?.advance(userInitiated: false) }
        }
    }

    var nowPlayingSong: Song? {
        guard let id = nowPlayingItem?.songID else { return nil }
        return library.song(for: id)
    }

    var upNextSongs: [(item: QueueItem, song: Song)] {
        upNext.compactMap { item in
            guard let song = library.song(for: item.songID) else { return nil }
            return (item, song)
        }
    }

    // MARK: Building a queue

    /// Replaces the whole queue with `songs` and immediately starts playing the first one.
    /// Used when tapping a song in an album/playlist list.
    func playAll(_ songs: [Song], startingAt startIndex: Int = 0) {
        guard !songs.isEmpty else { return }
        let ordered = Array(songs[startIndex...]) + Array(songs[..<startIndex])
        upNext = ordered.dropFirst().map { QueueItem(songID: $0.id) }
        history = []
        let first = ordered[0]
        nowPlayingItem = QueueItem(songID: first.id)
        audio.play(song: first)
        library.recordPlay(for: first)
    }

    /// Spotify-style "Play Next" — inserts right after the currently playing item.
    func playNext(_ song: Song) {
        upNext.insert(QueueItem(songID: song.id, isUserAdded: true), at: 0)
    }

    /// "Add to Queue" — appends to the end of up-next.
    func addToQueue(_ song: Song) {
        upNext.append(QueueItem(songID: song.id, isUserAdded: true))
    }

    func removeFromQueue(at offsets: IndexSet) {
        upNext.remove(atOffsets: offsets)
    }

    func moveInQueue(from source: IndexSet, to destination: Int) {
        upNext.move(fromOffsets: source, toOffset: destination)
    }

    // MARK: Transport

    func advance(userInitiated: Bool) {
        guard let current = nowPlayingItem else { return }
        history.append(current)

        if userInitiated, let song = library.song(for: current.songID) {
            library.recordSkip(for: song)
        }

        guard !upNext.isEmpty else {
            nowPlayingItem = nil
            return
        }

        let next = audio.isShuffleEnabled ? upNext.remove(at: Int.random(in: 0..<upNext.count)) : upNext.removeFirst()
        nowPlayingItem = next
        guard let song = library.song(for: next.songID) else { return }

        let settings = PersistenceManager.shared.loadSettings()
        if crossfadeEnabled, settings.crossfadeSeconds > 0 {
            audio.crossfade(to: song, duration: settings.crossfadeSeconds)
        } else {
            audio.play(song: song)
        }
        library.recordPlay(for: song)
    }

    func previous() {
        // Within the first 3 seconds of a track, "previous" restarts the current song
        // (matches Apple Music / Spotify behavior). Otherwise it jumps back a track.
        if audio.currentTime > 3 || history.isEmpty {
            audio.seek(to: 0)
            return
        }
        guard let last = history.popLast() else { return }
        if let current = nowPlayingItem {
            upNext.insert(current, at: 0)
        }
        nowPlayingItem = last
        if let song = library.song(for: last.songID) {
            audio.play(song: song)
        }
    }

    func skipToNext() {
        advance(userInitiated: true)
    }
}
