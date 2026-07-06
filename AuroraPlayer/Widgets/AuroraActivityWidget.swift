//
//  AuroraActivityWidget.swift
//  AuroraPlayerWidgets  (Widget Extension target — NOT the main app target)
//
//  Add this file's Target Membership to the Widget Extension only.
//  See SETUP.md, step "Dynamic Island", for how to create that target.
//

import SwiftUI
import WidgetKit
import ActivityKit

struct AuroraActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: AuroraActivityAttributes.self) { context in
            // Lock Screen / Banner presentation
            HStack(spacing: 12) {
                RoundedRectangle(cornerRadius: 8)
                    .fill(.white.opacity(0.15))
                    .frame(width: 44, height: 44)
                    .overlay(Image(systemName: "music.note").foregroundStyle(.white))

                VStack(alignment: .leading, spacing: 2) {
                    Text(context.state.title)
                        .font(.subheadline.bold())
                        .lineLimit(1)
                    Text(context.state.artist)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer()

                Image(systemName: context.state.isPlaying ? "pause.fill" : "play.fill")
                    .font(.title3)
            }
            .padding(14)
            .activityBackgroundTint(Color.black.opacity(0.85))
            .activitySystemActionForegroundColor(.white)

        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(.white.opacity(0.15))
                        .frame(width: 40, height: 40)
                        .overlay(Image(systemName: "music.note"))
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Image(systemName: context.state.isPlaying ? "pause.fill" : "play.fill")
                        .font(.title2)
                }
                DynamicIslandExpandedRegion(.center) {
                    VStack(spacing: 2) {
                        Text(context.state.title).font(.headline).lineLimit(1)
                        Text(context.state.artist).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                    }
                }
                DynamicIslandExpandedRegion(.bottom) {
                    ProgressView(value: context.state.elapsed, total: max(context.state.duration, 1))
                        .tint(.white)
                }
            } compactLeading: {
                Image(systemName: "music.note")
            } compactTrailing: {
                Image(systemName: context.state.isPlaying ? "waveform" : "pause.fill")
            } minimal: {
                Image(systemName: "music.note")
            }
        }
    }
}
