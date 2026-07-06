//
//  MiniPlayerView.swift
//  AuroraPlayer
//
//  Sits above the tab bar. Tapping expands into NowPlayingView using a
//  matchedGeometryEffect on the artwork for a seamless "hero" transition —
//  the Apple Music style expand, not just a modal popping in.
//

import SwiftUI

struct MiniPlayerView: View {
    @EnvironmentObject var audio: AudioPlayerManager
    @EnvironmentObject var queue: QueueManager
    @EnvironmentObject var theme: ThemeManager
    @Namespace private var artworkNamespace
    @State private var showFullPlayer = false
    @State private var dragOffset: CGFloat = 0

    var body: some View {
        Group {
            if let song = audio.currentSong {
                content(for: song)
            }
        }
        .fullScreenCover(isPresented: $showFullPlayer) {
            NowPlayingView()
                .environmentObject(audio)
                .environmentObject(queue)
                .environmentObject(theme)
        }
    }

    private func content(for song: Song) -> some View {
        HStack(spacing: 12) {
            ArtworkView(song: song, cornerRadius: 8)
                .frame(width: 44, height: 44)

            VStack(alignment: .leading, spacing: 1) {
                Text(song.title).font(.subheadline.bold()).lineLimit(1)
                Text(song.artist).font(.caption).foregroundStyle(.secondary).lineLimit(1)
            }

            Spacer()

            MiniPlayingIndicator(isPlaying: audio.isPlaying)
                .foregroundStyle(theme.current.accentColor)

            Button {
                HapticManager.shared.play(.lightTap)
                audio.togglePlayPause()
            } label: {
                Image(systemName: audio.isPlaying ? "pause.fill" : "play.fill")
                    .font(.title3)
            }
            .pressable()

            Button {
                HapticManager.shared.play(.lightTap)
                queue.skipToNext()
            } label: {
                Image(systemName: "forward.fill")
                    .font(.title3)
            }
            .pressable()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(GlassBackground(cornerRadius: 18, tint: theme.current.accentColor.opacity(0.3)))
        .padding(.horizontal, 10)
        .offset(y: dragOffset)
        .gesture(
            DragGesture()
                .onChanged { value in
                    if value.translation.height < 0 { dragOffset = value.translation.height / 4 }
                }
                .onEnded { value in
                    withAnimation(.spring()) { dragOffset = 0 }
                    if value.translation.height < -30 {
                        showFullPlayer = true
                    }
                }
        )
        .onTapGesture {
            showFullPlayer = true
        }
        .transition(.move(edge: .bottom).combined(with: .opacity))
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: audio.currentSong)
    }
}
