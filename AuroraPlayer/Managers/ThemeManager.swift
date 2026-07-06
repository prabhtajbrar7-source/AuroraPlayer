//
//  ThemeManager.swift
//  AuroraPlayer
//
//  Single source of truth for "what does the app look like right now".
//  Every screen reads `ThemeManager.shared.current` instead of hardcoding
//  colors, so switching a theme in Settings updates the whole app instantly.
//

import SwiftUI
import UIKit
import Combine

@MainActor
final class ThemeManager: ObservableObject {
    static let shared = ThemeManager()

    @Published private(set) var current: AppTheme
    @Published var settings: AppSettings {
        didSet { PersistenceManager.shared.saveSettings(settings) }
    }

    /// Live palette extracted from whatever artwork is currently playing.
    /// Views that want the "dynamic artwork colors" background bind to this.
    @Published var artworkPalette: ArtworkPalette = .placeholder

    private init() {
        let loadedSettings = PersistenceManager.shared.loadSettings()
        self.settings = loadedSettings
        self.current = AppTheme.all.first { $0.id == loadedSettings.themeID } ?? .aurora
    }

    func select(_ theme: AppTheme) {
        current = theme
        settings.themeID = theme.id
        HapticManager.shared.play(.selection)
    }

    /// Called by NowPlayingManager/observers whenever a new song's artwork loads.
    func updatePalette(from image: UIImage?) {
        guard let image else {
            artworkPalette = .placeholder
            return
        }
        artworkPalette = ColorExtractor.extractPalette(from: image)
    }

    /// The gradient every "glass" screen should sit on top of, respecting the
    /// current theme's `backgroundStyle`.
    var backgroundGradient: LinearGradient {
        switch current.backgroundStyle {
        case .dynamicArtwork:
            return LinearGradient(
                colors: [artworkPalette.shadow, artworkPalette.dominant, artworkPalette.accent.opacity(0.6)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .auroraGradient:
            return LinearGradient(
                colors: [current.accentColor, current.secondaryColor, .black],
                startPoint: .top,
                endPoint: .bottom
            )
        case .midnight:
            return LinearGradient(
                colors: [Color.black, Color(hex: "0B0B12")],
                startPoint: .top,
                endPoint: .bottom
            )
        case .daylight:
            return LinearGradient(
                colors: [Color.white, current.accentColor.opacity(0.15)],
                startPoint: .top,
                endPoint: .bottom
            )
        }
    }
}
