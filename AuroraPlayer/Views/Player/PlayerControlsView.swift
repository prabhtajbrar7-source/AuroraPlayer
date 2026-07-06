//
//  PlayerControlsView.swift
//  AuroraPlayer
//

import SwiftUI

struct PlayerControlsView: View {
    @EnvironmentObject var audio: AudioPlayerManager
    @EnvironmentObject var queue: QueueManager
    @State private var isScrubbing = false
    @State private var scrubTime: TimeInterval = 0

    var body: some View {
        VStack(spacing: 18) {
            scrubber

            HStack {
                Text((isScrubbing ? scrubTime : audio.currentTime).formattedClock)
                    .monospacedDigit()
                Spacer()
                Text(audio.duration.formattedClock)
                    .monospacedDigit()
            }
            .font(.caption)
            .foregroundStyle(.white.opacity(0.7))

            HStack(spacing: 36) {
                controlButton(systemName: "backward.fill", size: 22) {
                    queue.previous()
                }

                Button {
                    HapticManager.shared.play(.playbackStart)
                    audio.togglePlayPause()
                } label: {
                    ZStack {
                        Circle().fill(.white)
                        Image(systemName: audio.isPlaying ? "pause.fill" : "play.fill")
                            .font(.system(size: 26, weight: .bold))
                            .foregroundStyle(.black)
                            .offset(x: audio.isPlaying ? 0 : 2)
                    }
                    .frame(width: 68, height: 68)
                }
                .pressable(scale: 0.9)

                controlButton(systemName: "forward.fill", size: 22) {
                    queue.skipToNext()
                }
            }

            HStack(spacing: 40) {
                toggleButton(systemName: "shuffle", isOn: audio.isShuffleEnabled) {
                    audio.isShuffleEnabled.toggle()
                }
                toggleButton(
                    systemName: repeatSymbol,
                    isOn: audio.repeatMode != .off
                ) {
                    cycleRepeatMode()
                }
            }
            .padding(.top, 4)
        }
    }

    private var repeatSymbol: String {
        audio.repeatMode == .one ? "repeat.1" : "repeat"
    }

    private func cycleRepeatMode() {
        HapticManager.shared.play(.selection)
        audio.cycleRepeatMode()
    }

    private var scrubber: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(.white.opacity(0.25)).frame(height: 5)
                Capsule()
                    .fill(.white)
                    .frame(width: progressWidth(in: geo.size.width), height: 5)
            }
            .frame(maxHeight: .infinity, alignment: .center)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        isScrubbing = true
                        let fraction = max(0, min(1, value.location.x / geo.size.width))
                        scrubTime = fraction * audio.duration
                    }
                    .onEnded { _ in
                        audio.seek(to: scrubTime)
                        isScrubbing = false
                        HapticManager.shared.play(.lightTap)
                    }
            )
        }
        .frame(height: 20)
    }

    private func progressWidth(in totalWidth: CGFloat) -> CGFloat {
        let time = isScrubbing ? scrubTime : audio.currentTime
        guard audio.duration > 0 else { return 0 }
        return totalWidth * CGFloat(time / audio.duration)
    }

    private func controlButton(systemName: String, size: CGFloat, action: @escaping () -> Void) -> some View {
        Button(action: {
            HapticManager.shared.play(.lightTap)
            action()
        }) {
            Image(systemName: systemName)
                .font(.system(size: size, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 44, height: 44)
        }
        .pressable()
    }

    private func toggleButton(systemName: String, isOn: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(isOn ? Color.white : Color.white.opacity(0.5))
        }
        .pressable()
    }
}
