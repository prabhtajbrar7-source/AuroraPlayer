//
//  Extensions.swift
//  AuroraPlayer
//

import SwiftUI

/// Gives any button a subtle "premium" scale-down + haptic tick on press,
/// matching the feel of Apple Music's tappable rows and controls.
struct PressableButtonStyle: ButtonStyle {
    var scale: CGFloat = 0.96

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? scale : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.6), value: configuration.isPressed)
            .onChange(of: configuration.isPressed) { _, isPressed in
                if isPressed { HapticManager.shared.play(.lightTap) }
            }
    }
}

extension View {
    func pressable(scale: CGFloat = 0.96) -> some View {
        buttonStyle(PressableButtonStyle(scale: scale))
    }

    /// Convenience for applying a corner radius to specific corners only
    /// (used for the mini player's top-rounded sheet look).
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCornerShape(radius: radius, corners: corners))
    }
}

struct RoundedCornerShape: Shape {
    var radius: CGFloat
    var corners: UIRectCorner

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
    }
}

extension TimeInterval {
    var formattedClock: String {
        guard isFinite, !isNaN else { return "0:00" }
        let minutes = Int(self) / 60
        let seconds = Int(self) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}
