//
//  AboutView.swift
//  AuroraPlayer
//

import SwiftUI

struct AboutView: View {
    @Environment(\.dismiss) private var dismiss

    private let features = [
        ("sparkles", "Liquid Glass UI", "Native iOS 26 glass material with a material-based fallback."),
        ("waveform", "Live Wave Visualizer", "Real FFT spectrum analysis, not a fake animation."),
        ("paintpalette", "Dynamic Artwork Colors", "Backgrounds derived from each song's actual artwork."),
        ("sparkle", "AI Playlists & Smart Queue", "On-device by default, optional cloud AI with your own key."),
        ("lock.iphone", "Lock Screen & Dynamic Island", "Full MPNowPlayingInfoCenter + ActivityKit integration."),
        ("hand.tap", "Haptic Engine", "Custom CoreHaptics patterns, not just generic taps."),
        ("paintbrush", "Theme Engine", "Five built-in themes; easy to add more.")
    ]

    var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(spacing: 8) {
                        Image(systemName: "music.note.house.fill")
                            .font(.system(size: 40))
                        Text("AuroraPlayer").font(.title2.bold())
                        Text("Version 1.0").font(.caption).foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .listRowBackground(Color.clear)
                }

                Section("Features") {
                    ForEach(features, id: \.1) { feature in
                        Label {
                            VStack(alignment: .leading) {
                                Text(feature.1).font(.subheadline.bold())
                                Text(feature.2).font(.caption).foregroundStyle(.secondary)
                            }
                        } icon: {
                            Image(systemName: feature.0)
                        }
                    }
                }
            }
            .navigationTitle("About")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
