//
//  AnimatedGradientBackground.swift
//  AuroraPlayer
//
//  A slowly drifting mesh-of-blobs gradient, tinted by the current theme /
//  artwork palette. This is the "VisionOS-like" ambient depth behind the
//  Now Playing screen — three soft blurred circles that orbit slowly.
//

import SwiftUI

struct AnimatedGradientBackground: View {
    let palette: ArtworkPalette
    @State private var animate = false

    var body: some View {
        GeometryReader { geo in
            ZStack {
                palette.shadow.ignoresSafeArea()

                blob(color: palette.dominant, size: geo.size.width * 1.1)
                    .offset(x: animate ? -geo.size.width * 0.2 : geo.size.width * 0.15,
                            y: animate ? -geo.size.height * 0.15 : geo.size.height * 0.1)

                blob(color: palette.accent, size: geo.size.width * 0.9)
                    .offset(x: animate ? geo.size.width * 0.25 : -geo.size.width * 0.1,
                            y: animate ? geo.size.height * 0.3 : geo.size.height * 0.45)

                blob(color: palette.dominant.opacity(0.7), size: geo.size.width * 0.7)
                    .offset(x: animate ? geo.size.width * 0.05 : geo.size.width * 0.3,
                            y: animate ? geo.size.height * 0.55 : geo.size.height * 0.05)
            }
            .onAppear {
                withAnimation(.easeInOut(duration: 14).repeatForever(autoreverses: true)) {
                    animate.toggle()
                }
            }
        }
        .ignoresSafeArea()
        .animation(.easeInOut(duration: 0.8), value: palette)
    }

    private func blob(color: Color, size: CGFloat) -> some View {
        Circle()
            .fill(color)
            .frame(width: size, height: size)
            .blur(radius: 80)
            .opacity(0.55)
    }
}
