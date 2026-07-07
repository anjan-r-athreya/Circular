//
//  SettingsView.swift
//  CircleRun
//
//  Run and route preferences that apply to every generated loop.
//

import SwiftUI

struct SettingsView: View {
    @AppStorage("targetPaceMinPerMile") private var paceMinPerMile: Double = MapboxMapInterface.Controls.defaultPaceMinPerMile
    @AppStorage("preferSafePaths") private var preferSafePaths: Bool = true
    @AppStorage("loopHeading") private var loopHeading: String = LoopPreferences.Heading.any.rawValue
    @AppStorage("terrainPreference") private var terrainPreference: String = LoopPreferences.Terrain.any.rawValue
    /// 0 means no limit.
    @AppStorage("maxElevationGainFeet") private var maxElevationGainFeet: Double = 0
    @AppStorage("hasCompletedIntro") private var hasCompletedIntro = false
    @AppStorage("voiceCuesEnabled") private var voiceCuesEnabled = true

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text(MapboxMapInterface.Text.pacePrompt)
                            Spacer()
                            Text("\(paceString(paceMinPerMile)) /mi")
                                .foregroundColor(.secondary)
                        }
                        Slider(
                            value: $paceMinPerMile,
                            in: MapboxMapInterface.Controls.paceRange,
                            step: MapboxMapInterface.Controls.paceStep
                        )
                        .tint(MapboxMapInterface.Colors.primary)
                    }
                } header: {
                    Text(MapboxMapInterface.Text.runningSection)
                } footer: {
                    Text(MapboxMapInterface.Text.paceFooter)
                }

                Section {
                    Toggle(isOn: $voiceCuesEnabled) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Voice announcements")
                            Text("Turn-by-turn cues and mile splits, spoken during runs")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .tint(MapboxMapInterface.Colors.primary)
                } header: {
                    Text("During Runs")
                }

                Section {
                    Toggle(isOn: $preferSafePaths) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(MapboxMapInterface.Text.safePathsToggle)
                            Text(MapboxMapInterface.Text.safePathsDetail)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .tint(MapboxMapInterface.Colors.primary)

                    Picker(MapboxMapInterface.Text.headingPrompt, selection: $loopHeading) {
                        Text("Any").tag(LoopPreferences.Heading.any.rawValue)
                        Text("North").tag(LoopPreferences.Heading.north.rawValue)
                        Text("East").tag(LoopPreferences.Heading.east.rawValue)
                        Text("South").tag(LoopPreferences.Heading.south.rawValue)
                        Text("West").tag(LoopPreferences.Heading.west.rawValue)
                    }
                } header: {
                    Text(MapboxMapInterface.Text.routePreferencesSection)
                }

                Section {
                    Picker("Terrain", selection: $terrainPreference) {
                        Text("Any").tag(LoopPreferences.Terrain.any.rawValue)
                        Text("Flat").tag(LoopPreferences.Terrain.flat.rawValue)
                        Text("Rolling").tag(LoopPreferences.Terrain.rolling.rawValue)
                        Text("Hilly").tag(LoopPreferences.Terrain.hilly.rawValue)
                    }
                    .pickerStyle(.segmented)

                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Max elevation gain")
                            Spacer()
                            Text(maxElevationGainFeet > 0
                                 ? String(format: "%.0f ft", maxElevationGainFeet)
                                 : "No limit")
                                .foregroundColor(.secondary)
                        }
                        Slider(value: $maxElevationGainFeet, in: 0...2000, step: 100)
                            .tint(MapboxMapInterface.Colors.primary)
                    }
                } header: {
                    Text("Terrain & Elevation")
                } footer: {
                    Text("Generated loops are steered toward the chosen terrain and kept under the climb limit. Slide to zero for no limit.")
                }

                Section {
                    Button("Replay intro") {
                        withAnimation(.easeOut(duration: 0.5)) {
                            hasCompletedIntro = false
                        }
                    }
                    .foregroundColor(MapboxMapInterface.Colors.primary)
                } footer: {
                    Text("Show the first-launch walkthrough again.")
                }
            }
            .navigationTitle(MapboxMapInterface.Text.settingsTitle)
        }
    }

    private func paceString(_ minutesPerMile: Double) -> String {
        let minutes = Int(minutesPerMile)
        let seconds = Int((minutesPerMile - Double(minutes)) * 60)
        return String(format: "%d:%02d", minutes, seconds)
    }
}

#Preview {
    SettingsView()
}
