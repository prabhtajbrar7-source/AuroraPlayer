//
//  NowPlayingView.swift
//  AuroraPlayer
//
//  The full-screen player. Combines: dynamic artwork-driven background,
//  the wave visualizer, glass control surfaces, and a swipe-down-to-dismiss
//  gesture with the same rubber-banding feel Apple Music/Spotify use.
//

import SwiftUI

struct NowPlayingView: View {
    @EnvironmentObject var audio: AudioPlayerManager
    @EnvironmentObject var queue: QueueManager
    @EnvironmentObject var theme: ThemeManager
    @EnvironmentObject var library: LibraryManager
    @Environment(\.dismiss) private var dismiss

    @State private var dragOffset: CGFloat = 0
    @State private var showQueue = false
    @State private var showLyrics = false

    var body: some View {
        ZStack {
            AnimatedGradientBackground(palette: theme.artworkPalette)

            VStack(spacing: 0) {
                grabber

                header

                Spacer(minLength: 12)

                ArtworkView(song: audio.currentSong)
                    .padding(.horizontal, 36)
                    .scaleEffect(audio.isPlaying ? 1.0 : 0.94)
                    .animation(.spring(response: 0.4, dampingFraction: 0.7), value: audio.isPlaying)

                if theme.settings.showWaveVisualizer {
                    WaveVisualizerView(bands: audio.spectrumBands, tint: theme.current.accentColor)
                        .frame(height: 60)
                        .padding(.horizontal, 40)
                        .padding(.top, 20)
                        .opacity(audio.isPlaying ? 1 : 0.3)
                }

                Spacer(minLength: 12)

                titleBlock

                PlayerControlsView()
                    .padding(.top, 8)

                bottomRow
                    .padding(.top, 20)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
            .padding(.top, 8)
        }
        .offset(y: max(0, dragOffset))
        .gesture(
            DragGesture()
                .onChanged { value in
                    dragOffset = value.translation.height
                }
                .onEnded { value in
                    if value.translation.height > 120 {
                        dismiss()
                    } else {
                        withAnimation(.spring()) { dragOffset = 0 }
                    }
                }
        )
        .sheet(isPresented: $showQueue) {
            QueueView().environmentObject(queue).environmentObject(library).environmentObject(theme)
        }
        .sheet(isPresented: $showLyrics) {
            LyricsView(song: audio.currentSong).environmentObject(theme)
        }
        .onChange(of: audio.currentSong) { _, newSong in
            loadPalette(for: newSong)
        }
        .onAppear { loadPalette(for: audio.currentSong) }
    }

    private var grabber: some View {
        Capsule()
            .fill(.white.opacity(0.3))
            .frame(width: 40, height: 5)
            .padding(.top, 8)
    }

    private var header: some View {
        HStack {
            Text("Now Playing")
                .font(.footnote.bold())
                .textCase(.uppercase)
                .foregroundStyle(.white.opacity(0.6))
            Spacer()
            Button {
                dismiss()
            } label: {
                Image(systemName: "chevron.down")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(10)
                    .background(GlassBackground(cornerRadius: 16))
            }
            .pressable()
        }
        .padding(.top, 12)
    }

    private var titleBlock: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text(audio.currentSong?.title ?? "Nothing Playing")
                    .font(.title2.bold())
                    .foregroundStyle(.white)
                    .lineLimit(1)
                Text(audio.currentSong?.artist ?? "Import songs to get started")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.65))
                    .lineLimit(1)
            }
            Spacer()
            if let song = audio.currentSong {
                Button {
                    library.toggleFavorite(song)
                    HapticManager.shared.play(.favoriteToggled)
                } label: {
                    Image(systemName: song.isFavorite ? "heart.fill" : "heart")
                        .font(.title3)
                        .foregroundStyle(song.isFavorite ? theme.current.accentColor : .white)
                }
                .pressable()
            }
        }
        .padding(.top, 8)
    }

    private var bottomRow: some View {
        HStack(spacing: 28) {
            iconButton("text.quote") { showLyrics = true }
            iconButton("airplayaudio") {} // AirPlay route picker would go here via AVRoutePickerView
            Spacer()
            iconButton("list.bullet") { showQueue = true }
        }
    }

    private func iconButton(_ systemName: String, action: @escaping () -> Void) -> some View {
        Button(action: {
            HapticManager.shared.play(.lightTap)
            action()
        }) {
            Image(systemName: systemName)
                .font(.system(size: 17))
                .foregroundStyle(.white.opacity(0.8))
        }
        .pressable()
    }

    private func loadPalette(for song: Song?) {
        guard let url = song?.artworkURL, let image = UIImage(contentsOfFile: url.path) else {
            theme.updatePalette(from: nil)
            return
        }
        theme.updatePalette(from: image)
    }
}
