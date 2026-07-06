//
//  WaveVisualizerView.swift
//  AuroraPlayer
//
//  Renders `AudioPlayerManager.spectrumBands` (a live 32-band FFT magnitude
//  array, see AudioPlayerManager.processSpectrum) as smooth animated bars.
//  Because the data is real spectrum analysis and not a random/sine fake,
//  the bars genuinely respond to bass hits, vocals, and silence.
//

import SwiftUI

struct WaveVisualizerView: View {
    let bands: [Float]
    var tint: Color = .white
    var barCount: Int = 32

    var body: some View {
        GeometryReader { geo in
            HStack(alignment: .center, spacing: 3) {
                ForEach(0..<barCount, id: \.self) { index in
                    let magnitude = CGFloat(index < bands.count ? bands[index] : 0)
                    RoundedRectangle(cornerRadius: 3)
                        .fill(
                            LinearGradient(
                                colors: [tint, tint.opacity(0.4)],
                                startPoint: .bottom,
                                endPoint: .top
                            )
                        )
                        .frame(height: max(4, magnitude * geo.size.height))
                        .animation(.easeOut(duration: 0.08), value: magnitude)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
        }
    }
}

/// Compact "now playing" indicator (3 tiny animated bars) for mini player /
/// song rows — the little icon Apple Music shows next to the currently
/// playing track.
struct MiniPlayingIndicator: View {
    let isPlaying: Bool
    @State private var phase = false

    var body: some View {
        HStack(alignment: .bottom, spacing: 2) {
            ForEach(0..<3, id: \.self) { i in
                RoundedRectangle(cornerRadius: 1)
                    .frame(width: 3, height: isPlaying && phase ? heights[i].0 : heights[i].1)
            }
        }
        .frame(height: 14)
        .onAppear {
            guard isPlaying else { return }
            withAnimation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true)) {
                phase.toggle()
            }
        }
    }

    private let heights: [(CGFloat, CGFloat)] = [(14, 5), (8, 12), (14, 6)]
}

#Preview {
    WaveVisualizerView(bands: (0..<32).map { _ in Float.random(in: 0...1) })
        .frame(height: 120)
        .padding()
        .background(Color.black)
}
