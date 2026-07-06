//
//  RouteDetailView.swift
//  CircleRun
//
//  Created by Anjan Athreya on 5/29/25.
//

import SwiftUI
import MapKit
import CoreLocation

struct RouteDetailView: View {
    let route: Route
    @Environment(\.dismiss) private var dismiss
    @State private var showingNavigation = false
    @Environment(\.presentationMode) var presentationMode

    // Stats resolved asynchronously when the view appears
    @State private var startingPoint = "Locating…"
    @State private var terrain = "…"
    @State private var difficulty = "…"
    @State private var elevationGainText = "…"
    @State private var statsLoaded = false

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Map Preview
                MapSnapshotView(
                    coordinates: route.path,
                    size: CGSize(width: UIScreen.main.bounds.width - 32, height: 200),
                    lineColor: .blue
                )
                .clipShape(RoundedRectangle(cornerRadius: 16))

                // Route Stats
                VStack(spacing: 16) {
                    Text(route.name)
                        .font(.title2)
                        .fontWeight(.bold)

                    HStack(spacing: 40) {
                        StatItem(icon: "figure.run", title: "Runs", value: "\(route.runCount)")
                        StatItem(icon: "stopwatch", title: "Best Time",
                                 value: route.bestTime > 0 ? formatTime(route.bestTime) : "—")
                        StatItem(icon: "map", title: "Distance",
                                 value: String(format: "%.2f mi", route.distance))
                    }
                }
                .padding()
                .background(RoundedRectangle(cornerRadius: 16).fill(.ultraThinMaterial))

                // Action Buttons
                HStack(spacing: 12) {
                    // Load in Map Button
                    Button(action: {
                        NotificationCenter.default.post(name: Notification.Name("LoadFavoriteRoute"), object: route)
                        presentationMode.wrappedValue.dismiss()
                    }) {
                        HStack {
                            Image(systemName: "map.fill")
                            Text("Load in Map")
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue.opacity(0.8))
                        .foregroundColor(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                    }

                    // Start Run Button
                    Button(action: {
                        showingNavigation = true
                    }) {
                        HStack {
                            Image(systemName: "location.fill")
                            Text("Start Run")
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                    }
                }
                .padding(.horizontal)

                // Best times podium
                VStack(alignment: .leading, spacing: 12) {
                    Text("Best Times")
                        .font(.headline)
                        .padding(.bottom, 4)

                    if route.bestTimes.isEmpty {
                        Text("Complete a run of this route to set a time.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    } else {
                        ForEach(0..<3, id: \.self) { rank in
                            PodiumRow(
                                rank: rank,
                                time: rank < route.bestTimes.count
                                    ? formatTime(route.bestTimes[rank])
                                    : "—"
                            )
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(RoundedRectangle(cornerRadius: 16).fill(.ultraThinMaterial))

                // Route information, computed from the route itself
                VStack(alignment: .leading, spacing: 12) {
                    Text("Route Information")
                        .font(.headline)
                        .padding(.bottom, 4)

                    InfoRow(icon: "map", title: "Starting Point", value: startingPoint)
                    InfoRow(icon: "figure.walk", title: "Difficulty", value: difficulty)
                    InfoRow(icon: "tree", title: "Terrain", value: terrain)
                    InfoRow(icon: "arrow.up.right", title: "Elevation Gain", value: elevationGainText)
                }
                .padding()
                .background(RoundedRectangle(cornerRadius: 16).fill(.ultraThinMaterial))
            }
            .padding()
        }
        .navigationBarTitleDisplayMode(.inline)
        .fullScreenCover(isPresented: $showingNavigation) {
            NavigationInterface(route: route)
        }
        .task {
            await loadStats()
        }
    }

    // MARK: - Stat loading

    private func loadStats() async {
        guard !statsLoaded else { return }
        statsLoaded = true

        // Starting point: reverse-geocode the first coordinate of the loop.
        if let first = route.path.first {
            let location = CLLocation(latitude: first.latitude, longitude: first.longitude)
            let placemark = try? await CLGeocoder().reverseGeocodeLocation(location).first
            startingPoint = placemark?.thoroughfare
                ?? placemark?.subLocality
                ?? placemark?.locality
                ?? "Unknown"
        } else {
            startingPoint = "Unknown"
        }

        // Terrain, difficulty, and elevation gain from the elevation profile.
        if let gainMeters = await ElevationService.shared.gainMeters(for: route.path) {
            elevationGainText = String(format: "%.0f ft", gainMeters * 3.28084)
            terrain = ElevationService.terrainDescription(gainMeters: gainMeters, miles: route.distance)
            difficulty = ElevationService.difficultyDescription(gainMeters: gainMeters, miles: route.distance)
        } else {
            elevationGainText = "Unavailable"
            terrain = "Unavailable"
            // Distance-only fallback when elevation data can't be fetched.
            difficulty = route.distance < 4 ? "Easy" : route.distance < 8 ? "Moderate" : "Hard"
        }
    }

    private func formatTime(_ timeInterval: TimeInterval) -> String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute, .second]
        formatter.unitsStyle = .abbreviated
        return formatter.string(from: timeInterval) ?? "0s"
    }
}

// MARK: - Supporting Views
private struct StatItem: View {
    let icon: String
    let title: String
    let value: String

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.blue)
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            Text(value)
                .font(.headline)
        }
    }
}

private struct PodiumRow: View {
    let rank: Int
    let time: String

    private var medalColor: Color {
        switch rank {
        case 0: return .yellow
        case 1: return Color(white: 0.75)
        default: return Color(red: 0.8, green: 0.5, blue: 0.2)
        }
    }

    private var label: String {
        switch rank {
        case 0: return "1st"
        case 1: return "2nd"
        default: return "3rd"
        }
    }

    var body: some View {
        HStack {
            Image(systemName: "trophy.fill")
                .foregroundColor(medalColor)
                .frame(width: 24)
            Text(label)
                .foregroundColor(.secondary)
            Spacer()
            Text(time)
                .fontWeight(.medium)
                .monospacedDigit()
        }
    }
}

private struct InfoRow: View {
    let icon: String
    let title: String
    let value: String

    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(.blue)
                .frame(width: 24)
            Text(title)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .fontWeight(.medium)
        }
    }
}

#Preview {
    NavigationStack {
        RouteDetailView(route: Route.sample())
    }
}
