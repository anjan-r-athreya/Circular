//
//  RunDetailView.swift
//  CircleRun
//
//  Everything about one run: the GPS trace on a map, the headline stat
//  grid, per-mile splits, and Apple Watch heart rate / calories pulled
//  from HealthKit when they exist for the run's time window.
//

import SwiftUI
import CoreLocation

struct RunDetailView: View {
    let run: RunRecord

    @State private var elevationGainFeet: Double?
    @State private var heartRate: HealthKitService.HeartRateSummary?
    @State private var calories: Double?
    @State private var isPersonalRecord = false
    @State private var shareItem: ShareItem?

    private var traceCoordinates: [CLLocationCoordinate2D] {
        run.path?.map(\.coordinate) ?? []
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                header

                if traceCoordinates.count > 1 {
                    MapSnapshotView(
                        coordinates: traceCoordinates,
                        size: CGSize(width: UIScreen.main.bounds.width - 32, height: 220),
                        lineColor: .blue
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                }

                if isPersonalRecord {
                    personalRecordBadge
                }

                statGrid

                if let splits = run.mileSplitSeconds, !splits.isEmpty {
                    splitsCard(splits)
                }

                if let heart = heartRateToShow {
                    heartRateCard(heart)
                }
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Run")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if traceCoordinates.count > 1 {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: shareTrace) {
                        Image(systemName: "square.and.arrow.up")
                    }
                }
            }
        }
        .sheet(item: $shareItem) { item in
            ShareSheet(items: [item.url])
        }
        .task { await loadDetails() }
    }

    // MARK: - Sections

    private var header: some View {
        VStack(spacing: 4) {
            Text(run.routeName)
                .font(.title2.weight(.bold))
            Text(run.date.formatted(date: .complete, time: .shortened))
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private var personalRecordBadge: some View {
        HStack(spacing: 10) {
            Image(systemName: "trophy.fill")
                .foregroundColor(.yellow)
            Text("Best time on this route")
                .font(.subheadline.weight(.semibold))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Capsule().fill(Color.yellow.opacity(0.15)))
        .overlay(Capsule().stroke(Color.yellow.opacity(0.5), lineWidth: 1))
    }

    private var statGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            statCell(value: String(format: "%.2f mi", run.miles), label: "Distance",
                     icon: "point.topleft.down.to.point.bottomright.curvepath", tint: .blue)
            statCell(value: formatTime(run.seconds), label: "Time",
                     icon: "stopwatch", tint: .blue)
            statCell(value: formatPace(run.paceSecondsPerMile) + " /mi", label: "Avg Pace",
                     icon: "speedometer", tint: .green)
            statCell(value: elevationGainFeet.map { String(format: "%.0f ft", $0) } ?? "—",
                     label: "Elev Gain", icon: "arrow.up.right", tint: .orange)
            if let calories = caloriesToShow {
                statCell(value: String(format: "%.0f", calories), label: "Calories",
                         icon: "flame.fill", tint: .red)
            }
            if let heart = heartRateToShow {
                statCell(value: String(format: "%.0f bpm", heart.average), label: "Avg Heart Rate",
                         icon: "heart.fill", tint: .pink)
            }
        }
    }

    private func statCell(value: String, label: String, icon: String, tint: Color) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(tint)
            Text(value)
                .font(.title3.weight(.bold))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(RoundedRectangle(cornerRadius: 14).fill(Color(.secondarySystemGroupedBackground)))
    }

    private func splitsCard(_ splits: [Double]) -> some View {
        let fastest = splits.min() ?? 1

        return VStack(alignment: .leading, spacing: 10) {
            Text("Splits")
                .font(.headline)

            ForEach(splits.indices, id: \.self) { index in
                let split = splits[index]
                let isFastest = split == fastest && splits.count > 1
                HStack(spacing: 10) {
                    Text("Mi \(index + 1)")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(.secondary)
                        .frame(width: 38, alignment: .leading)

                    // Bar length ∝ speed, so the fastest mile is the longest.
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule().fill(Color(.tertiarySystemFill))
                            Capsule()
                                .fill(isFastest ? Color.green : Color.blue.opacity(0.75))
                                .frame(width: geo.size.width * (fastest / split))
                        }
                    }
                    .frame(height: 10)

                    Text(formatPace(split))
                        .font(.caption.weight(isFastest ? .bold : .regular))
                        .monospacedDigit()
                        .foregroundColor(isFastest ? .green : .primary)
                        .frame(width: 44, alignment: .trailing)
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 14).fill(Color(.secondarySystemGroupedBackground)))
    }

    private func heartRateCard(_ heart: HealthKitService.HeartRateSummary) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("Heart Rate", systemImage: "heart.fill")
                    .font(.headline)
                    .foregroundColor(.pink)
                Spacer()
                Text(String(format: "avg %.0f · max %.0f bpm", heart.average, heart.peak))
                    .font(.caption.weight(.medium))
                    .foregroundColor(.secondary)
                    .monospacedDigit()
            }

            heartRateChart(heart.series)
                .frame(height: 70)
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 14).fill(Color(.secondarySystemGroupedBackground)))
    }

    private func heartRateChart(_ series: [Double]) -> some View {
        GeometryReader { geo in
            let lo = (series.min() ?? 0) - 5
            let hi = (series.max() ?? 1) + 5
            let span = max(hi - lo, 10)
            let points = series.enumerated().map { index, value in
                CGPoint(x: geo.size.width * CGFloat(index) / CGFloat(max(series.count - 1, 1)),
                        y: geo.size.height * CGFloat(1 - (value - lo) / span))
            }

            ZStack {
                Path { path in
                    guard let first = points.first else { return }
                    path.move(to: CGPoint(x: first.x, y: geo.size.height))
                    points.forEach { path.addLine(to: $0) }
                    path.addLine(to: CGPoint(x: points[points.count - 1].x, y: geo.size.height))
                    path.closeSubpath()
                }
                .fill(LinearGradient(colors: [.pink.opacity(0.3), .pink.opacity(0.03)],
                                     startPoint: .top, endPoint: .bottom))

                Path { path in
                    guard let first = points.first else { return }
                    path.move(to: first)
                    points.dropFirst().forEach { path.addLine(to: $0) }
                }
                .stroke(Color.pink, style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
            }
        }
    }

    // MARK: - Data

    /// Stored metrics win (sample data carries them); otherwise whatever
    /// HealthKit turned up for the run's window.
    private var heartRateToShow: HealthKitService.HeartRateSummary? {
        if let avg = run.avgHeartRate, let max = run.maxHeartRate {
            return HealthKitService.HeartRateSummary(average: avg, peak: max,
                                                     series: run.heartRateSeries ?? [])
        }
        return heartRate
    }

    private var caloriesToShow: Double? {
        run.calories ?? calories
    }

    private func loadDetails() async {
        // Trophy check: is this run the route's standing best?
        if let routeID = run.routeID,
           let favorite = RouteManager.shared.favorite(withID: routeID),
           favorite.bestTime > 0, abs(favorite.bestTime - run.seconds) < 1 {
            isPersonalRecord = true
        }

        if traceCoordinates.count > 1 {
            if let gain = await ElevationService.shared.gainMeters(for: traceCoordinates) {
                elevationGainFeet = gain * 3.28084
            }
        }

        // Watch metrics, when the run doesn't already carry them.
        if run.avgHeartRate == nil || run.calories == nil {
            HealthKitService.shared.requestReadAuthorization()
            let start = run.date.addingTimeInterval(-run.seconds)
            if run.avgHeartRate == nil {
                heartRate = await HealthKitService.shared.heartRate(from: start, to: run.date)
            }
            if run.calories == nil {
                calories = await HealthKitService.shared.activeCalories(from: start, to: run.date)
            }
        }
    }

    private func shareTrace() {
        Haptics.selection()
        if let url = RouteSharing.gpxFileURL(coordinates: traceCoordinates,
                                             name: run.routeName,
                                             distanceMiles: run.miles) {
            shareItem = ShareItem(url: url)
        }
    }

    // MARK: - Formatting

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
