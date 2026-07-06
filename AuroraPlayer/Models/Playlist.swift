//
//  Playlist.swift
//  AuroraPlayer
//

import Foundation

struct Playlist: Identifiable, Codable, Equatable, Hashable {
    let id: UUID
    var name: String
    var songIDs: [UUID]
    var dateCreated: Date
    var isAIGenerated: Bool
    /// The natural-language prompt that produced this playlist, if AI-generated.
    var sourcePrompt: String?
    /// Symbol name shown in the UI (SF Symbol).
    var iconSymbol: String
    /// Accent color name, resolved through ThemeManager.colorPalette.
    var colorName: String

    init(
        id: UUID = UUID(),
        name: String,
        songIDs: [UUID] = [],
        dateCreated: Date = Date(),
        isAIGenerated: Bool = false,
        sourcePrompt: String? = nil,
        iconSymbol: String = "music.note.list",
        colorName: String = "aurora.violet"
    ) {
        self.id = id
        self.name = name
        self.songIDs = songIDs
        self.dateCreated = dateCreated
        self.isAIGenerated = isAIGenerated
        self.sourcePrompt = sourcePrompt
        self.iconSymbol = iconSymbol
        self.colorName = colorName
    }
}

/// A single entry in the playback queue. Wrapping the Song ID (rather than the Song itself)
/// in its own identity lets the same song appear twice in a queue (e.g. "play next" + later in album)
/// without SwiftUI's `List`/`ForEach` id collisions.
struct QueueItem: Identifiable, Codable, Equatable, Hashable {
    let id: UUID
    let songID: UUID
    /// True if the user explicitly inserted this via "Play Next" / "Add to Queue",
    /// as opposed to it being part of the original album/playlist order.
    var isUserAdded: Bool

    init(id: UUID = UUID(), songID: UUID, isUserAdded: Bool = false) {
        self.id = id
        self.songID = songID
        self.isUserAdded = isUserAdded
    }
}
