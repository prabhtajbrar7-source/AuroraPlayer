//
//  GlassBackground.swift
//  AuroraPlayer
//
//  On iOS 26+, this uses the real system "Liquid Glass" material via
//  `.glassEffect()`. On anything older (or if you'd rather not depend on the
//  brand-new API while it's still settling), it falls back to a hand-built
//  glass look using `.ultraThinMaterial` + a soft specular edge. Both paths
//  look good — the native one just reacts to content behind it a bit more
//  richly (refraction/lensing).
//
//  NOTE: if Xcode flags the `.glassEffect()` call because the exact parameter
//  labels shifted slightly in your SDK version, autocomplete (Ctrl+Space) on
//  `.glassEffect(` will show you the current signature — it's a one-line fix.
//  You can also just delete the `#available` branch and always use the
//  `.ultraThinMaterial` fallback below; it looks great on its own.
//

import SwiftUI

struct GlassBackground: View {
    var cornerRadius: CGFloat = 24
    var tint: Color? = nil
    var interactive: Bool = false

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)

        Group {
            if #available(iOS 26.0, *) {
                shape
                    .fill(.clear)
                    .glassEffect(
                        tint == nil ? .regular : .regular.tint(tint!),
                        in: shape
                    )
            } else {
                shape
                    .fill(.ultraThinMaterial)
                    .overlay(
                        shape.fill(
                            LinearGradient(
                                colors: [(tint ?? .white).opacity(0.14), .clear],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                    )
                    .overlay(
                        shape.stroke(
                            LinearGradient(
                                colors: [.white.opacity(0.55), .white.opacity(0.05)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                    )
                    .shadow(color: .black.opacity(0.25), radius: 12, y: 6)
            }
        }
    }
}

/// A ready-to-use glass card container — the workhorse component used
/// throughout the app for rows, sheets, and the mini player.
struct GlassCard<Content: View>: View {
    var cornerRadius: CGFloat = 24
    var tint: Color? = nil
    @ViewBuilder var content: Content

    var body: some View {
        content
            .background(GlassBackground(cornerRadius: cornerRadius, tint: tint))
    }
}
