//
//  AuroraPlayerApp.swift
//  AuroraPlayer
//

import SwiftUI

@main
struct AuroraPlayerApp: App {
    @StateObject private var theme = ThemeManager.shared
    @StateObject private var library = LibraryManager.shared
    @StateObject private var audio = AudioPlayerManager.shared
    @StateObject private var queue = QueueManager.shared

    // Instantiated for their side effects (Lock Screen + Dynamic Island wiring);
    // they don't publish anything views need to read directly.
    private let nowPlaying = NowPlayingManager.shared
    private let liveActivity = LiveActivityManager.shared

    var body: some Scene {
        WindowGroup {
            RootTabView()
                .environmentObject(theme)
                .environmentObject(library)
                .environmentObject(audio)
                .environmentObject(queue)
                .preferredColorScheme(theme.current.backgroundStyle == .daylight ? ColorScheme.light : ColorScheme.dark)
        }
    }
}
