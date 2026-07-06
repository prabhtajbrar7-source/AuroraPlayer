//
//  Song.swift
//  AuroraPlayer
//
//  Core data model representing a single imported track.
//

import Foundation
import AVFoundation
import SwiftUI

/// A single track imported into the local library.
/// Artwork is stored on disk (not in the struct) so the model stays lightweight and Codable.
struct Song: Identifiable, Codable, Equatable, Hashable {
    let id: UUID
    var title: String
    var artist: String
    var album: String
    var genre: String
    var duration: TimeInterval
    /// Relative filename inside the app's Documents/Library folder.
    var fileName: String
    /// Relative filename of the cached artwork (jpg) inside Documents/Artwork, if any.
    var artworkFileName: String?
    var dateAdded: Date
    var playCount: Int
    var skipCount: Int
    var lastPlayedAt: Date?
    var isFavorite: Bool
    /// Rough tempo estimate in BPM, used by the AI engine for "energy" based smart playlists.
    /// Not a true audio analysis (that would need a DSP tempo tracker) — derived heuristically.
    var estimatedEnergy: Double // 0.0 (chill) ... 1.0 (high energy)

    init(
        id: UUID = UUID(),
        title: String,
        artist: String,
        album: String,
        genre: String,
        duration: TimeInterval,
        fileName: String,
        artworkFileName: String? = nil,
        dateAdded: Date = Date(),
        playCount: Int = 0,
        skipCount: Int = 0,
        lastPlayedAt: Date? = nil,
        isFavorite: Bool = false,
        estimatedEnergy: Double = 0.5
    ) {
        self.id = id
        self.title = title
        self.artist = artist
        self.album = album
        self.genre = genre
        self.duration = duration
        self.fileName = fileName
        self.artworkFileName = artworkFileName
        self.dateAdded = dateAdded
        self.playCount = playCount
        self.skipCount = skipCount
        self.lastPlayedAt = lastPlayedAt
        self.isFavorite = isFavorite
        self.estimatedEnergy = estimatedEnergy
    }

    var fileURL: URL {
        FileManager.libraryDirectory.appendingPathComponent(fileName)
    }

    var artworkURL: URL? {
        guard let artworkFileName else { return nil }
        return FileManager.artworkDirectory.appendingPathComponent(artworkFileName)
    }

    var formattedDuration: String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

// MARK: - Metadata extraction

extension Song {
    /// Builds a Song by reading ID3/AAC metadata from a locally copied audio file.
    /// Falls back to sensible defaults (filename as title, "Unknown Artist", etc.) when tags are missing.
    static func makeFromLocalFile(fileName: String) async -> Song {
        let url = FileManager.libraryDirectory.appendingPathComponent(fileName)
        let asset = AVURLAsset(url: url)

        var title = (fileName as NSString).deletingPathExtension
        var artist = "Unknown Artist"
        var album = "Unknown Album"
        var genre = "Unknown"
        var duration: TimeInterval = 0
        var artworkFileName: String?

        do {
            let commonMetadata = try await asset.load(.commonMetadata)
            for item in commonMetadata {
                guard let key = item.commonKey else { continue }
                switch key {
                case .commonKeyTitle:
                    if let value = try? await item.load(.stringValue), !value.isEmpty { title = value }
                case .commonKeyArtist:
                    if let value = try? await item.load(.stringValue), !value.isEmpty { artist = value }
                case .commonKeyAlbumName:
                    if let value = try? await item.load(.stringValue), !value.isEmpty { album = value }
                case .commonKeyType:
                    if let value = try? await item.load(.stringValue), !value.isEmpty { genre = value }
                case .commonKeyArtwork:
                    if let data = try? await item.load(.dataValue) {
                        artworkFileName = ArtworkStore.save(imageData: data, forSongNamed: fileName)
                    }
                default:
                    break
                }
            }

            let cmDuration = try await asset.load(.duration)
            duration = CMTimeGetSeconds(cmDuration)
            if duration.isNaN || duration.isInfinite { duration = 0 }
        } catch {
            // Metadata read failed — the file will still play, just with generic info.
            print("Metadata read failed for \(fileName): \(error.localizedDescription)")
        }

        // Very rough "energy" heuristic from genre keywords, purely to seed AI smart playlists
        // until the user has enough listening history for real personalization.
        let energy = Self.energyHeuristic(genre: genre, title: title)

        return Song(
            title: title,
            artist: artist,
            album: album,
            genre: genre,
            duration: duration,
            fileName: fileName,
            artworkFileName: artworkFileName,
            estimatedEnergy: energy
        )
    }

    private static func energyHeuristic(genre: String, title: String) -> Double {
        let text = (genre + " " + title).lowercased()
        let highEnergyWords = ["edm", "dance", "party", "rock", "metal", "hype", "trap", "drill", "techno", "house", "remix"]
        let lowEnergyWords = ["acoustic", "ballad", "lofi", "lo-fi", "chill", "ambient", "piano", "sleep", "calm", "study"]
        if highEnergyWords.contains(where: text.contains) { return 0.8 }
        if lowEnergyWords.contains(where: text.contains) { return 0.25 }
        return 0.5
    }
}

/// Lightweight helper for writing/reading cached artwork JPEGs to disk.
enum ArtworkStore {
    static func save(imageData: Data, forSongNamed fileName: String) -> String? {
        let artworkName = (fileName as NSString).deletingPathExtension + ".jpg"
        let destination = FileManager.artworkDirectory.appendingPathComponent(artworkName)
        do {
            if let image = UIImage(data: imageData), let jpeg = image.jpegData(compressionQuality: 0.85) {
                try jpeg.write(to: destination, options: .atomic)
                return artworkName
            }
        } catch {
            print("Failed to cache artwork: \(error.localizedDescription)")
        }
        return nil
    }
}
