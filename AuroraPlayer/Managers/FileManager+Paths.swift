//
//  FileManager+Paths.swift
//  AuroraPlayer
//
//  Central place for every on-disk location the app uses, so nothing
//  hardcodes a path string more than once.
//

import Foundation

extension FileManager {
    private static var documentsDirectory: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }

    /// Where imported audio files are copied to (so they survive even if the
    /// original is deleted from Files.app / iCloud after import).
    static var libraryDirectory: URL {
        let url = documentsDirectory.appendingPathComponent("Library", isDirectory: true)
        createIfNeeded(url)
        return url
    }

    /// Cached artwork extracted from imported files.
    static var artworkDirectory: URL {
        let url = documentsDirectory.appendingPathComponent("Artwork", isDirectory: true)
        createIfNeeded(url)
        return url
    }

    /// JSON persistence for the song catalog, playlists, and settings.
    static var dataDirectory: URL {
        let url = documentsDirectory.appendingPathComponent("Data", isDirectory: true)
        createIfNeeded(url)
        return url
    }

    private static func createIfNeeded(_ url: URL) {
        if !FileManager.default.fileExists(atPath: url.path) {
            try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        }
    }
}
