//
//  ActivityView.swift
//  CircleRun
//
//  The complete run log: streak, weekly mileage, and every saved run.
//

import SwiftUI

struct ActivityView: View {
    @ObservedObject private var store = RunStore.shared

    var body: some View {
        NavigationStack {
            Group {
                if store.runs.isEmpty {
                    emptyState
                } else {
                    List {
                        Section {
                            statsHeader
                                .listRowInsets(EdgeInsets())
                                .listRowBackground(Color.clear)
                        }

                        Section("Runs") {
                            ForEach(store.runs) { run in
                                NavigationLink(destination: RunDetailView(run: run)) {
                                    runRow(run)
                                }
                            }
                            .onDelete { offsets in
                                offsets.map { store.runs[$0] }.forEach(store.delete)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Activity")
            #if DEBUG
            // Dev-only: fill or clear the tab with fake runs to preview it.
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button {
                            Haptics.success()
                            store.seedSampleData()
                        } label: {
                            Label("Load sample data", systemImage: "wand.and.stars")
                        }
                        Button(role: .destructive) {
                            Haptics.selection()
                            store.clearHistory()
                        } label: {
                            Label("Clear history", systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
            #endif
        }
    }

    private var statsHeader: some View {
        HStack(spacing: 12) {
            statCard(value: "\(store.currentStreakDays)",
                     unit: store.currentStreakDays == 1 ? "day streak" : "day streak",
                     icon: "flame.fill", color: .orange)
            statCard(value: String(format: "%.1f", store.thisWeekMiles),
                     unit: "mi this week",
                     icon: "calendar", color: .blue)
            statCard(value: String(format: "%.0f", store.totalMiles),
                     unit: "mi total",
                     icon: "figure.run", color: .green)
        }
        .padding(.vertical, 8)
    }

    private func statCard(value: String, unit: String, icon: String, color: Color) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundColor(color)
            Text(value)
                .font(.title3.weight(.bold))
                .monospacedDigit()
            Text(unit)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(.secondarySystemGroupedBackground))
        )
    }

    private func runRow(_ run: RunRecord) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                Text(run.routeName)
                    .font(.subheadline.weight(.semibold))
                Text(run.date.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 3) {
                Text(String(format: "%.2f mi", run.miles))
                    .font(.subheadline.weight(.semibold))
                    .monospacedDigit()
                Text("\(formatTime(run.seconds)) · \(formatPace(run.paceSecondsPerMile))")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .monospacedDigit()
            }
        }
        .padding(.vertical, 2)
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "figure.run.circle")
                .font(.system(size: 60))
                .foregroundColor(.secondary)

            Text("No Runs Yet")
                .font(.title2)
                .fontWeight(.semibold)

            Text("Finish a run and save it — your history, weekly miles, and streak will build here.")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
    }

    private func formatTime(_ seconds: TimeInterval) -> String {
        let hours = Int(seconds) / 3600
        let minutes = (Int(seconds) % 3600) / 60
        let secs = Int(seconds) % 60
        return hours > 0
            ? String(format: "%d:%02d:%02d", hours, minutes, secs)
            : String(format: "%d:%02d", minutes, secs)
    }

    private func formatPace(_ secondsPerMile: Double) -> String {
        guard secondsPerMile > 0 else { return "—" }
        let minutes = Int(secondsPerMile) / 60
        let seconds = Int(secondsPerMile) % 60
        return String(format: "%d'%02d\"", minutes, seconds)
    }
}

#Preview {
    ActivityView()
}
