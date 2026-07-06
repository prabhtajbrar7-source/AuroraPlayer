//
//  RootTabView.swift
//  AuroraPlayer
//
//  Standard tab bar, with the mini player floating just above it — same
//  layering approach Apple Music/Spotify use so the player is always
//  reachable no matter which tab you're on.
//

import SwiftUI

struct RootTabView: View {
    @EnvironmentObject var audio: AudioPlayerManager
    @EnvironmentObject var theme: ThemeManager
    @EnvironmentObject var library: LibraryManager
    @EnvironmentObject var queue: QueueManager

    var body: some View {
        ZStack(alignment: .bottom) {
            TabView {
                LibraryView()
                    .tabItem { Label("Library", systemImage: "music.note.list") }

                AIPlaylistView()
                    .tabItem { Label("AI", systemImage: "sparkles") }

                SettingsView()
                    .tabItem { Label("Settings", systemImage: "gearshape") }
            }

            if audio.currentSong != nil {
                MiniPlayerView()
                    .padding(.bottom, 50) // sits just above the tab bar
            }
        }
        .environmentObject(theme)
        .environmentObject(library)
        .environmentObject(queue)
    }
}
