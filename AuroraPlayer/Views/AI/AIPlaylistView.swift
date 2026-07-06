//
//  AIPlaylistView.swift
//  AuroraPlayer
//
//  Type a mood/activity/vibe, get a playlist. Runs on-device by default;
//  see AIEngine.swift for the (opt-in) remote LLM path.
//

import SwiftUI

struct AIPlaylistView: View {
    @EnvironmentObject var library: LibraryManager
    @EnvironmentObject var queue: QueueManager
    @EnvironmentObject var theme: ThemeManager
    @State private var prompt: String = ""
    @State private var isGenerating = false
    @State private var result: AIPlaylistResult?
    @State private var errorMessage: String?

    private let suggestions = ["Late night drive", "Gym motivation", "Rainy day study", "Sunday morning chill", "Throwback party"]

    var body: some View {
        NavigationStack {
            ZStack {
                theme.backgroundGradient.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        header

                        GlassCard(cornerRadius: 20) {
                            TextField("Describe a mood, moment, or vibe…", text: $prompt, axis: .vertical)
                                .lineLimit(1...3)
                                .padding(16)
                                .foregroundStyle(.white)
                        }

                        suggestionChips

                        Button {
                            Task { await generate() }
                        } label: {
                            HStack {
                                if isGenerating { ProgressView().tint(.white) }
                                Text(isGenerating ? "Curating…" : "Generate Playlist")
                                    .font(.headline)
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(prompt.trimmingCharacters(in: .whitespaces).isEmpty || isGenerating)

                        if let errorMessage {
                            Text(errorMessage)
                                .font(.footnote)
                                .foregroundStyle(.red)
                        }

                        if let result {
                            resultCard(result)
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("AI Playlists")
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("AI Queue & Playlists", systemImage: "sparkles")
                .font(.title2.bold())
                .foregroundStyle(.white)
            Text(theme.settings.aiProvider == .onDeviceOnly
                 ? "Running fully on-device — no data leaves your phone."
                 : "Using \(theme.settings.aiProvider.rawValue) — metadata only, never audio files.")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.6))
        }
    }

    private var suggestionChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(suggestions, id: \.self) { suggestion in
                    Button(suggestion) { prompt = suggestion }
                        .font(.caption.bold())
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(GlassBackground(cornerRadius: 20))
                        .foregroundStyle(.white)
                }
            }
        }
    }

    private func resultCard(_ result: AIPlaylistResult) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(result.title).font(.title3.bold()).foregroundStyle(.white)
            Text(result.description).font(.footnote).foregroundStyle(.white.opacity(0.7))

            Button {
                let playlist = library.createPlaylist(
                    name: result.title,
                    songIDs: result.songIDs,
                    isAIGenerated: true,
                    sourcePrompt: prompt,
                    iconSymbol: "sparkles",
                    colorName: "aurora.violet"
                )
                let songs = library.songs(in: playlist)
                if !songs.isEmpty { queue.playAll(songs) }
            } label: {
                Label("Save & Play (\(result.songIDs.count) songs)", systemImage: "play.circle.fill")
                    .frame(maxWidth: .infinity)
                    .padding(10)
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
        .background(GlassBackground(cornerRadius: 20))
    }

    private func generate() async {
        isGenerating = true
        errorMessage = nil
        defer { isGenerating = false }
        do {
            result = try await AIEngine.shared.generatePlaylist(prompt: prompt, settings: theme.settings)
            HapticManager.shared.play(.success)
        } catch {
            errorMessage = error.localizedDescription
            HapticManager.shared.play(.warning)
        }
    }
}
