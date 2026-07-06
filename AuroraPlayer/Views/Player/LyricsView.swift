//
//  LyricsView.swift
//  AuroraPlayer
//
//  Apple Music / Lyra-style scrolling lyrics with the current line highlighted
//  and past/future lines dimmed. AuroraPlayer doesn't fetch lyrics from any
//  service out of the box (that needs a licensed lyrics API + your own key —
//  see the comment on `LyricLine.demo` below for where to plug one in);
//  what's here is the full synced-highlighting UI, ready to drive from real data.
//

import SwiftUI

struct LyricLine: Identifiable, Equatable {
    let id = UUID()
    let time: TimeInterval
    let text: String

    /// Placeholder timeline so the UI has something to demonstrate immediately.
    /// Replace this with real timestamps parsed from an LRC file or a lyrics API
    /// response (most synced-lyrics APIs return `[mm:ss.xx] line` LRC format).
    static func demo(duration: TimeInterval) -> [LyricLine] {
        let placeholders = [
            "♪ Instrumental intro ♪",
            "Import a real .lrc file or wire up a lyrics API",
            "to replace this placeholder timeline —",
            "the highlighting and auto-scroll already work",
            "against whatever timestamps you provide.",
            "♪ ♪ ♪"
        ]
        let step = duration / Double(placeholders.count + 1)
        return placeholders.enumerated().map { index, text in
            LyricLine(time: step * Double(index + 1), text: text)
        }
    }
}

struct LyricsView: View {
    let song: Song?
    @EnvironmentObject var theme: ThemeManager
    @EnvironmentObject var audio: AudioPlayerManager
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            theme.backgroundGradient.ignoresSafeArea()

            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Text("Lyrics").font(.title2.bold()).foregroundStyle(.white)
                    Spacer()
                    Button { dismiss() } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundStyle(.white.opacity(0.6))
                    }
                }
                .padding()

                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(alignment: .leading, spacing: 22) {
                            ForEach(lines) { line in
                                Text(line.text)
                                    .font(currentLine?.id == line.id ? .title3.bold() : .title3)
                                    .foregroundStyle(currentLine?.id == line.id ? .white : .white.opacity(0.4))
                                    .id(line.id)
                                    .animation(.easeInOut(duration: 0.3), value: currentLine)
                            }
                        }
                        .padding(.horizontal, 24)
                        .padding(.bottom, 100)
                    }
                    .onChange(of: currentLine) { _, newValue in
                        guard let newValue else { return }
                        withAnimation(.easeInOut) {
                            proxy.scrollTo(newValue.id, anchor: .center)
                        }
                    }
                }
            }
        }
    }

    private var lines: [LyricLine] {
        LyricLine.demo(duration: max(song?.duration ?? 180, 30))
    }

    private var currentLine: LyricLine? {
        lines.last { $0.time <= audio.currentTime }
    }
}
