//
//  SettingsView.swift
//  AuroraPlayer
//

import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var theme: ThemeManager
    @State private var showAbout = false

    var body: some View {
        NavigationStack {
            ZStack {
                theme.backgroundGradient.ignoresSafeArea()

                Form {
                    Section("Appearance") {
                        ThemePickerView()
                            .listRowBackground(Color.clear)
                        Toggle("Wave Visualizer", isOn: Binding(
                            get: { theme.settings.showWaveVisualizer },
                            set: { theme.settings.showWaveVisualizer = $0 }
                        ))
                        .listRowBackground(Color.white.opacity(0.06))
                    }

                    Section("Haptics") {
                        Toggle("Haptic Feedback", isOn: Binding(
                            get: { theme.settings.hapticsEnabled },
                            set: { theme.settings.hapticsEnabled = $0 }
                        ))
                        .listRowBackground(Color.white.opacity(0.06))

                        if theme.settings.hapticsEnabled {
                            VStack(alignment: .leading) {
                                Text("Intensity").font(.caption).foregroundStyle(.secondary)
                                Slider(value: Binding(
                                    get: { theme.settings.hapticIntensity },
                                    set: { theme.settings.hapticIntensity = $0 }
                                ), in: 0...1)
                            }
                            .listRowBackground(Color.white.opacity(0.06))
                        }
                    }

                    Section("Playback") {
                        VStack(alignment: .leading) {
                            Text("Crossfade: \(Int(theme.settings.crossfadeSeconds))s")
                                .font(.subheadline)
                            Slider(value: Binding(
                                get: { theme.settings.crossfadeSeconds },
                                set: { theme.settings.crossfadeSeconds = $0 }
                            ), in: 0...8, step: 1)
                        }
                        .listRowBackground(Color.white.opacity(0.06))

                        Toggle("Gapless Playback", isOn: Binding(
                            get: { theme.settings.gaplessPlayback },
                            set: { theme.settings.gaplessPlayback = $0 }
                        ))
                        .listRowBackground(Color.white.opacity(0.06))
                    }

                    Section("AI") {
                        Picker("Provider", selection: Binding(
                            get: { theme.settings.aiProvider },
                            set: { theme.settings.aiProvider = $0 }
                        )) {
                            ForEach(AppSettings.AIProvider.allCases, id: \.self) { provider in
                                Text(provider.rawValue).tag(provider)
                            }
                        }
                        .listRowBackground(Color.white.opacity(0.06))

                        if theme.settings.aiProvider != .onDeviceOnly {
                            SecureField("API Key", text: Binding(
                                get: { theme.settings.aiAPIKey },
                                set: { theme.settings.aiAPIKey = $0 }
                            ))
                            .listRowBackground(Color.white.opacity(0.06))
                            Text("Stored only on this device. Metadata (titles/artists/genres) is sent to generate playlists — never audio files.")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .listRowBackground(Color.clear)
                        }
                    }

                    Section {
                        Button("About AuroraPlayer") { showAbout = true }
                            .listRowBackground(Color.white.opacity(0.06))
                    }
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("Settings")
            .sheet(isPresented: $showAbout) { AboutView() }
        }
    }
}
