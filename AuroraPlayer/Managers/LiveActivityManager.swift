//
//  LiveActivityManager.swift
//  AuroraPlayer
//
//  Drives the Dynamic Island / Lock Screen Live Activity from the main app
//  target. See AuroraActivityAttributes.swift and SETUP.md for the one-time
//  Widget Extension target you need to add in Xcode for the Island UI itself
//  to render — this file works standalone (it'll just have no visual effect
//  until that target exists, it won't crash or fail to compile).
//

import Foundation
import ActivityKit
import Combine

@MainActor
final class LiveActivityManager {
    static let shared = LiveActivityManager()

    private var currentActivity: Activity<AuroraActivityAttributes>?
    private var cancellables = Set<AnyCancellable>()
    private let audio = AudioPlayerManager.shared

    private init() {
        observe()
    }

    private func observe() {
        audio.$currentSong
            .removeDuplicates()
            .sink { [weak self] song in
                guard let self else { return }
                if let song {
                    self.start(for: song)
                } else {
                    Task { await self.end() }
                }
            }
            .store(in: &cancellables)

        audio.$isPlaying
            .combineLatest(audio.$currentTime)
            .sink { [weak self] isPlaying, elapsed in
                self?.update(isPlaying: isPlaying, elapsed: elapsed)
            }
            .store(in: &cancellables)
    }

    private func start(for song: Song) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }

        Task { await currentActivity?.end(nil, dismissalPolicy: .immediate) }

        let attributes = AuroraActivityAttributes(songID: song.id.uuidString)
        let state = AuroraActivityAttributes.ContentState(
            title: song.title,
            artist: song.artist,
            elapsed: 0,
            duration: song.duration,
            isPlaying: true,
            artworkFileName: song.artworkFileName
        )

        do {
            currentActivity = try Activity.request(
                attributes: attributes,
                content: .init(state: state, staleDate: nil)
            )
        } catch {
            print("Live Activity failed to start: \(error.localizedDescription)")
        }
    }

    private func update(isPlaying: Bool, elapsed: TimeInterval) {
        guard let activity = currentActivity, let song = audio.currentSong else { return }
        let state = AuroraActivityAttributes.ContentState(
            title: song.title,
            artist: song.artist,
            elapsed: elapsed,
            duration: song.duration,
            isPlaying: isPlaying,
            artworkFileName: song.artworkFileName
        )
        Task {
            await activity.update(.init(state: state, staleDate: nil))
        }
    }

    private func end() async {
        await currentActivity?.end(nil, dismissalPolicy: .immediate)
        currentActivity = nil
    }
}
