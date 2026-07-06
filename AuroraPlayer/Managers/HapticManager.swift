//
//  HapticManager.swift
//  AuroraPlayer
//
//  Two tiers: quick UIFeedbackGenerator taps for everyday UI (buttons, toggles,
//  selection), and a couple of custom CoreHaptics patterns for the moments that
//  should feel special (starting playback, favoriting a track). Falls back
//  gracefully on devices/simulators without a Taptic Engine.
//

import CoreHaptics
import UIKit

@MainActor
final class HapticManager {
    static let shared = HapticManager()

    enum Event {
        case selection
        case lightTap
        case success
        case warning
        case playbackStart
        case favoriteToggled
    }

    private var engine: CHHapticEngine?
    private let supportsHaptics = CHHapticEngine.capabilitiesForHardware().supportsHaptics

    private let selectionGenerator = UISelectionFeedbackGenerator()
    private let impactLight = UIImpactFeedbackGenerator(style: .light)
    private let impactMedium = UIImpactFeedbackGenerator(style: .medium)
    private let notificationGenerator = UINotificationFeedbackGenerator()

    private init() {
        guard supportsHaptics else { return }
        do {
            engine = try CHHapticEngine()
            try engine?.start()
            engine?.resetHandler = { [weak self] in
                try? self?.engine?.start()
            }
            engine?.stoppedHandler = { _ in }
        } catch {
            print("Haptic engine failed to start: \(error.localizedDescription)")
        }
    }

    var isEnabled: Bool {
        get { ThemeManager.shared.settings.hapticsEnabled }
    }

    func play(_ event: Event) {
        guard isEnabled else { return }
        switch event {
        case .selection:
            selectionGenerator.selectionChanged()
        case .lightTap:
            impactLight.impactOccurred()
        case .success:
            notificationGenerator.notificationOccurred(.success)
        case .warning:
            notificationGenerator.notificationOccurred(.warning)
        case .playbackStart:
            playPattern(playbackStartPattern())
        case .favoriteToggled:
            playPattern(favoritePattern())
        }
    }

    // MARK: Custom patterns

    /// A soft "swell" — sharpness rises then falls — used when a track starts playing.
    private func playbackStartPattern() -> CHHapticPattern? {
        let intensity1 = CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.5)
        let sharpness1 = CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.2)
        let intensity2 = CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.8)
        let sharpness2 = CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.6)

        let e1 = CHHapticEvent(eventType: .hapticTransient, parameters: [intensity1, sharpness1], relativeTime: 0)
        let e2 = CHHapticEvent(eventType: .hapticTransient, parameters: [intensity2, sharpness2], relativeTime: 0.09)
        return try? CHHapticPattern(events: [e1, e2], parameters: [])
    }

    /// A quick double-tap "pop" for favoriting a song.
    private func favoritePattern() -> CHHapticPattern? {
        let strong = CHHapticEventParameter(parameterID: .hapticIntensity, value: 1.0)
        let sharp = CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.9)
        let e1 = CHHapticEvent(eventType: .hapticTransient, parameters: [strong, sharp], relativeTime: 0)
        let e2 = CHHapticEvent(eventType: .hapticTransient, parameters: [strong, sharp], relativeTime: 0.06)
        return try? CHHapticPattern(events: [e1, e2], parameters: [])
    }

    private func playPattern(_ pattern: CHHapticPattern?) {
        guard supportsHaptics, let engine, let pattern else {
            impactMedium.impactOccurred() // graceful fallback
            return
        }
        do {
            let player = try engine.makePlayer(with: pattern)
            try player.start(atTime: CHHapticTimeImmediate)
        } catch {
            impactMedium.impactOccurred()
        }
    }
}
