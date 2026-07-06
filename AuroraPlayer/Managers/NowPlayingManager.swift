//
//  NowPlayingManager.swift
//  AuroraPlayer
//
//  Publishes the current track to the Lock Screen, Control Center, CarPlay,
//  and AirPods/hardware remote controls via MPNowPlayingInfoCenter and
//  MPRemoteCommandCenter. This is what makes the app show real artwork and
//  scrubbing controls on the Lock Screen — required, not optional, for a
//  music app to feel "premium".
//

import Foundation
import MediaPlayer
import UIKit
import Combine

@MainActor
final class NowPlayingManager {
    static let shared = NowPlayingManager()

    private let audio = AudioPlayerManager.shared
    private let queue = QueueManager.shared
    private var cancellables = Set<AnyCancellable>()
    private var artworkCache: [UUID: MPMediaItemArtwork] = [:]

    private init() {
        configureRemoteCommandCenter()
        observePlaybackState()
    }

    private func observePlaybackState() {
        audio.$currentSong
            .combineLatest(audio.$isPlaying)
            .sink { [weak self] song, isPlaying in
                self?.updateNowPlayingInfo(song: song, isPlaying: isPlaying)
            }
            .store(in: &cancellables)

        audio.$currentTime
            .sink { [weak self] time in
                self?.updateElapsedTime(time)
            }
            .store(in: &cancellables)
    }

    private func updateNowPlayingInfo(song: Song?, isPlaying: Bool) {
        guard let song else {
            MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
            return
        }

        var info: [String: Any] = [
            MPMediaItemPropertyTitle: song.title,
            MPMediaItemPropertyArtist: song.artist,
            MPMediaItemPropertyAlbumTitle: song.album,
            MPMediaItemPropertyPlaybackDuration: song.duration,
            MPNowPlayingInfoPropertyElapsedPlaybackTime: audio.currentTime,
            MPNowPlayingInfoPropertyPlaybackRate: isPlaying ? 1.0 : 0.0,
            MPNowPlayingInfoPropertyDefaultPlaybackRate: 1.0
        ]

        if let artwork = artwork(for: song) {
            info[MPMediaItemPropertyArtwork] = artwork
        }

        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }

    private func updateElapsedTime(_ time: TimeInterval) {
        var info = MPNowPlayingInfoCenter.default().nowPlayingInfo ?? [:]
        info[MPNowPlayingInfoPropertyElapsedPlaybackTime] = time
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }

    private func artwork(for song: Song) -> MPMediaItemArtwork? {
        if let cached = artworkCache[song.id] { return cached }
        guard let url = song.artworkURL, let image = UIImage(contentsOfFile: url.path) else { return nil }
        let artwork = MPMediaItemArtwork(boundsSize: image.size) { _ in image }
        artworkCache[song.id] = artwork
        return artwork
    }

    private func configureRemoteCommandCenter() {
        let center = MPRemoteCommandCenter.shared()

        center.playCommand.addTarget { [weak self] _ in
            self?.audio.resume()
            return .success
        }
        center.pauseCommand.addTarget { [weak self] _ in
            self?.audio.pause()
            return .success
        }
        center.togglePlayPauseCommand.addTarget { [weak self] _ in
            self?.audio.togglePlayPause()
            return .success
        }
        center.nextTrackCommand.addTarget { [weak self] _ in
            self?.queue.skipToNext()
            return .success
        }
        center.previousTrackCommand.addTarget { [weak self] _ in
            self?.queue.previous()
            return .success
        }
        center.changePlaybackPositionCommand.addTarget { [weak self] event in
            guard let event = event as? MPChangePlaybackPositionCommandEvent else { return .commandFailed }
            self?.audio.seek(to: event.positionTime)
            return .success
        }
    }
}
