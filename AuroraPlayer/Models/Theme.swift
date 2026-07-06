//
//  Theme.swift
//  AuroraPlayer
//

import SwiftUI

/// A complete visual theme: accent color, glass tint, and background mood.
/// New themes can be added to `AppTheme.all` without touching any view code,
/// since every screen reads colors through `ThemeManager.current`.
struct AppTheme: Identifiable, Codable, Equatable, Hashable {
    var id: String
    var displayName: String
    var accentHex: String
    var secondaryHex: String
    var backgroundStyle: BackgroundStyle
    var glassTintOpacity: Double

    enum BackgroundStyle: String, Codable {
        case dynamicArtwork   // gradient derived live from the current song's artwork
        case auroraGradient   // fixed animated aurora-style gradient
        case midnight         // near-black, minimal
        case daylight         // bright, airy, light mode oriented
    }

    var accentColor: Color { Color(hex: accentHex) }
    var secondaryColor: Color { Color(hex: secondaryHex) }

    static let aurora = AppTheme(
        id: "aurora",
        displayName: "Aurora",
        accentHex: "7F5AF0",
        secondaryHex: "2CB1BC",
        backgroundStyle: .dynamicArtwork,
        glassTintOpacity: 0.18
    )

    static let sunset = AppTheme(
        id: "sunset",
        displayName: "Sunset",
        accentHex: "FF8A5B",
        secondaryHex: "EA526F",
        backgroundStyle: .dynamicArtwork,
        glassTintOpacity: 0.20
    )

    static let midnight = AppTheme(
        id: "midnight",
        displayName: "Midnight",
        accentHex: "5E8DFF",
        secondaryHex: "8A8CF0",
        backgroundStyle: .midnight,
        glassTintOpacity: 0.12
    )

    static let mono = AppTheme(
        id: "mono",
        displayName: "Mono",
        accentHex: "FFFFFF",
        secondaryHex: "A0A0A0",
        backgroundStyle: .midnight,
        glassTintOpacity: 0.10
    )

    static let citrus = AppTheme(
        id: "citrus",
        displayName: "Citrus",
        accentHex: "FFC93C",
        secondaryHex: "6BCB77",
        backgroundStyle: .daylight,
        glassTintOpacity: 0.22
    )

    static let all: [AppTheme] = [.aurora, .sunset, .midnight, .mono, .citrus]
}

extension Color {
    /// Convenience initializer for building Colors from hex strings stored in themes/JSON.
    init(hex: String) {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")
        var rgb: UInt64 = 0
        Scanner(string: hexSanitized).scanHexInt64(&rgb)

        let r = Double((rgb & 0xFF0000) >> 16) / 255.0
        let g = Double((rgb & 0x00FF00) >> 8) / 255.0
        let b = Double(rgb & 0x0000FF) / 255.0
        self.init(red: r, green: g, blue: b)
    }
}
