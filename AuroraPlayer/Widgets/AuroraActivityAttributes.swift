//
//  AuroraActivityAttributes.swift
//  AuroraPlayer
//
//  IMPORTANT — read SETUP.md before this compiles for Dynamic Island:
//  Live Activities require a separate "Widget Extension" target in Xcode
//  (File > New > Target > Widget Extension, uncheck "Include Configuration
//  Intent"). This file needs to be added to BOTH the main app target and the
//  widget extension target's "Target Membership" in the File Inspector, since
//  both processes need to agree on the same `ActivityAttributes` type.
//
//  This file has no UI — it's just the shared data contract. The actual
//  Dynamic Island / Lock Screen layout lives in AuroraActivityWidget.swift,
//  which belongs ONLY in the widget extension target.
//

import Foundation
import ActivityKit

struct AuroraActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var title: String
        var artist: String
        var elapsed: TimeInterval
        var duration: TimeInterval
        var isPlaying: Bool
        /// Base64-free reference: the widget extension reads cached artwork from
        /// the shared App Group container by song id, since Live Activity payloads
        /// should stay small.
        var artworkFileName: String?
    }

    var songID: String
}
