//
//  NavigationInterface.swift
//  CircleRun
//
//  Created by Anjan Athreya on 5/29/25.
//

import SwiftUI
import MapKit
import CoreLocation

struct NavigationInterface: View {
    let route: Route
    @StateObject private var navigationManager = NavigationManager()
    @Environment(\.dismiss) private var dismiss

    /// Set when the runner taps end; nil while the run is live.
    @State private var summary: RunSummary?

    struct RunSummary {
        let miles: Double
        let seconds: TimeInterval
        /// Covered at least 90% of the route's distance.
        let completedRoute: Bool
        /// Beat the route's previous best time.
        let isPersonalRecord: Bool
    }

    var body: some View {
        ZStack(alignment: .top) {
            // 3D Map View
            MapViewRepresentable(navigationManager: navigationManager)
                .ignoresSafeArea()
            
            // Top Navigation Banner
            VStack(spacing: 0) {
                if let instruction = navigationManager.currentInstruction {
                    HStack(alignment: .center, spacing: 16) {
                        // Distance to next turn
                        Text(instruction.distance)
                            .font(.system(size: 34, weight: .bold))
                            .foregroundColor(.white)
                        
                        Spacer()
                        
                        // Turn arrows
                        HStack(spacing: 4) {
                            ForEach(0..<5) { index in
                                Image(systemName: getTurnArrowSystemName(for: instruction.maneuverType, at: index))
                                    .font(.system(size: 28, weight: .medium))
                                    .foregroundColor(index < 3 ? .gray : .white)
                            }
                        }
                    }
                    .padding(.horizontal)
                    .padding(.top, 8)
                    
                    // Street name
                    if let streetName = instruction.streetName {
                        Text(streetName)
                            .font(.system(size: 20, weight: .medium))
                            .foregroundColor(.white)
                            .padding(.horizontal)
                            .padding(.bottom, 8)
                    }
                }
            }
            .background(Color.black.opacity(0.75))
            
            // Bottom Stats Banner
            VStack {
                Spacer()
                
                HStack(spacing: 12) {
                    statColumn(navigationManager.runningStats.currentPace, "pace", .leading)
                    Spacer()
                    statColumn(navigationManager.runningStats.distanceCovered, "done", .center)
                    Spacer()
                    statColumn(navigationManager.runningStats.elapsedTime, "elapsed", .center)
                    Spacer()
                    statColumn(navigationManager.runningStats.remainingDistance, "left", .trailing)
                }
                .padding()
                .background(Color.black.opacity(0.75))
            }
            
            // Map controls: end run, 2D/3D toggle, re-center
            VStack {
                HStack {
                    Spacer()
                    VStack(spacing: 12) {
                        Button(action: {
                            finishRun()
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 32))
                                .foregroundColor(.white)
                        }

                        // Pause/resume the clock without leaving the run
                        Button(action: {
                            Haptics.selection()
                            navigationManager.togglePause()
                        }) {
                            Image(systemName: navigationManager.runningStats.isPaused
                                  ? "play.fill" : "pause.fill")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(.white)
                                .frame(width: 40, height: 40)
                                .background(navigationManager.runningStats.isPaused
                                            ? Color.orange.opacity(0.9)
                                            : Color.black.opacity(0.6))
                                .clipShape(Circle())
                        }

                        // Toggle between the 3D chase camera and a flat 2D view
                        Button(action: {
                            Haptics.selection()
                            navigationManager.toggle3DMode()
                        }) {
                            Image(systemName: navigationManager.is3DMode ? "view.3d" : "view.2d")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(.white)
                                .frame(width: 40, height: 40)
                                .background(Color.black.opacity(0.6))
                                .clipShape(Circle())
                        }

                        // Shown once the user pans/zooms away from the runner
                        if !navigationManager.isFollowingUser {
                            Button(action: {
                                navigationManager.resumeFollowing()
                            }) {
                                Image(systemName: "location.fill")
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundColor(.white)
                                    .frame(width: 40, height: 40)
                                    .background(Color.blue.opacity(0.9))
                                    .clipShape(Circle())
                            }
                        }
                    }
                    .padding()
                }
                Spacer()
            }
            .padding(.top, 60)

            // End-of-run summary over everything else
            if let summary {
                summaryOverlay(summary)
            }
        }
        .onAppear {
            navigationManager.startNavigation(for: route)
        }
    }

    private func statColumn(_ value: String, _ label: String,
                            _ alignment: HorizontalAlignment) -> some View {
        VStack(alignment: alignment) {
            Text(value)
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.white)
                .monospacedDigit()
            Text(label)
                .font(.system(size: 13))
                .foregroundColor(.gray)
        }
    }

    // MARK: - Run completion

    /// Freezes the run and shows the summary. A run too short to mean
    /// anything (accidental start) just exits.
    private func finishRun() {
        let miles = navigationManager.metersTraveled / 1609.34
        guard miles >= 0.05 else {
            discardRun()
            return
        }

        if !navigationManager.runningStats.isPaused {
            navigationManager.togglePause()
        }

        let elapsed = navigationManager.elapsedSeconds
        let completed = miles >= route.distance * 0.9
        let isPR = completed && route.bestTime > 0 && elapsed < route.bestTime
        summary = RunSummary(miles: miles, seconds: elapsed,
                             completedRoute: completed, isPersonalRecord: isPR)

        if isPR {
            Haptics.milestone()
        } else if completed {
            Haptics.success()
        }
    }

    /// Persists the run to history, and to the route's best times when the
    /// route was actually covered.
    private func saveRun() {
        guard let summary else { return }
        RunStore.shared.record(RunRecord(
            id: UUID(),
            date: Date(),
            routeName: route.name,
            routeID: route.id,
            miles: summary.miles,
            seconds: summary.seconds
        ))
        if summary.completedRoute {
            RouteManager.shared.recordRun(routeID: route.id, time: summary.seconds)
        }
        HealthKitService.shared.saveRun(miles: summary.miles, seconds: summary.seconds)
        navigationManager.stopNavigation()
        dismiss()
    }

    private func discardRun() {
        navigationManager.stopNavigation()
        dismiss()
    }

    private func summaryOverlay(_ summary: RunSummary) -> some View {
        ZStack {
            Color.black.opacity(0.7).ignoresSafeArea()

            VStack(spacing: 20) {
                if summary.isPersonalRecord {
                    Image(systemName: "trophy.fill")
                        .font(.system(size: 44))
                        .foregroundColor(.yellow)
                        .shadow(color: .yellow.opacity(0.7), radius: 12)
                    Text("New Best Time!")
                        .font(.title2.weight(.bold))
                        .foregroundColor(.white)
                } else {
                    Text("Run Complete")
                        .font(.title2.weight(.bold))
                        .foregroundColor(.white)
                }

                VStack(spacing: 12) {
                    summaryRow("Distance", String(format: "%.2f mi", summary.miles))
                    summaryRow("Time", formatSummaryTime(summary.seconds))
                    if summary.miles > 0.05 {
                        summaryRow("Avg pace", formatSummaryPace(summary.seconds / summary.miles))
                    }
                }
                .padding(.vertical, 4)

                if !summary.completedRoute {
                    Text("Route not fully completed — this run won't count toward best times.")
                        .font(.caption)
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                }

                HStack(spacing: 12) {
                    Button(action: {
                        Haptics.selection()
                        discardRun()
                    }) {
                        Text("Discard")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.white.opacity(0.15))
                            .cornerRadius(12)
                    }

                    Button(action: {
                        Haptics.success()
                        saveRun()
                    }) {
                        Text("Save Run")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .cornerRadius(12)
                    }
                }
            }
            .padding(24)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color(white: 0.1))
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(Color.blue.opacity(0.3), lineWidth: 1)
                    )
            )
            .padding(32)
        }
    }

    private func summaryRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
                .foregroundColor(.gray)
            Spacer()
            Text(value)
                .foregroundColor(.white)
                .fontWeight(.semibold)
                .monospacedDigit()
        }
        .font(.body)
        .frame(maxWidth: 220)
    }

    private func formatSummaryTime(_ seconds: TimeInterval) -> String {
        let hours = Int(seconds) / 3600
        let minutes = (Int(seconds) % 3600) / 60
        let secs = Int(seconds) % 60
        return hours > 0
            ? String(format: "%d:%02d:%02d", hours, minutes, secs)
            : String(format: "%d:%02d", minutes, secs)
    }

    private func formatSummaryPace(_ secondsPerMile: Double) -> String {
        let minutes = Int(secondsPerMile) / 60
        let seconds = Int(secondsPerMile) % 60
        return String(format: "%d'%02d\" /mi", minutes, seconds)
    }

    private func getTurnArrowSystemName(for maneuverType: String, at index: Int) -> String {
        if index < 3 {
            return "arrow.up.circle.fill"
        } else if index == 3 {
            switch maneuverType {
            case "turn.right":
                return "arrow.turn.up.right.circle.fill"
            case "turn.left":
                return "arrow.turn.up.left.circle.fill"
            default:
                return "arrow.up.circle.fill"
            }
        } else {
            return maneuverType == "turn.right" ? "arrow.right.circle.fill" : "arrow.left.circle.fill"
        }
    }
}

// MARK: - Preview
#Preview {
    NavigationInterface(route: Route.sample())
} 
