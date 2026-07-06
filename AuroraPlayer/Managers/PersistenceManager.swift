//
//  PersistenceManager.swift
//  AuroraPlayer
//
//  Simple, dependency-free JSON persistence. No CoreData/SwiftData model
//  registration to get wrong — just Codable structs written to disk.
//  Swap this out for SwiftData later if the library grows huge (10k+ tracks).
//

import Foundation

final class PersistenceManager {
    static let shared = PersistenceManager()
    private init() {}

    private let songsURL = FileManager.dataDirectory.appendingPathComponent("songs.json")
    private let playlistsURL = FileManager.dataDirectory.appendingPathComponent("playlists.json")
    private let settingsURL = FileManager.dataDirectory.appendingPathComponent("settings.json")

    private let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        e.outputFormatting = [.prettyPrinted]
        return e
    }()

    private let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()

    // MARK: Songs

    func loadSongs() -> [Song] {
        load(songsURL, as: [Song].self) ?? []
    }

    func saveSongs(_ songs: [Song]) {
        save(songs, to: songsURL)
    }

    // MARK: Playlists

    func loadPlaylists() -> [Playlist] {
        load(playlistsURL, as: [Playlist].self) ?? []
    }

    func savePlaylists(_ playlists: [Playlist]) {
        save(playlists, to: playlistsURL)
    }

    // MARK: Settings

    func loadSettings() -> AppSettings {
        load(settingsURL, as: AppSettings.self) ?? AppSettings()
    }

    func saveSettings(_ settings: AppSettings) {
        save(settings, to: settingsURL)
    }

    // MARK: Generic helpers

    private func save<T: Encodable>(_ value: T, to url: URL) {
        do {
            let data = try encoder.encode(value)
            try data.write(to: url, options: .atomic)
        } catch {
            print("PersistenceManager save error at \(url.lastPathComponent): \(error.localizedDescription)")
        }
    }

    private func load<T: Decodable>(_ url: URL, as type: T.Type) -> T? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? decoder.decode(T.self, from: data)
    }
}

/// Persisted user preferences — theme, haptics, playback behavior.
struct AppSettings: Codable, Equatable {
    var themeID: String = AppTheme.aurora.id
    var hapticsEnabled: Bool = true
    var hapticIntensity: Double = 1.0
    var crossfadeSeconds: Double = 2.0
    var gaplessPlayback: Bool = true
    var showWaveVisualizer: Bool = true
    var aiSuggestionsEnabled: Bool = true
    /// Optional API key for the remote AI provider. Stored locally only (never bundled/committed).
    var aiAPIKey: String = ""
    var aiProvider: AIProvider = .onDeviceOnly

    enum AIProvider: String, Codable, CaseIterable {
        case onDeviceOnly = "On-Device Only"
        case anthropic = "Anthropic Claude"
        case openAI = "OpenAI"
    }
}
