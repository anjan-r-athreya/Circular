//
//  RunDetailView.swift
//  CircleRun
//
//  One run, Night Circuit style: the trace draws itself on as the hero
//  with a comet lapping it, one giant pace number, glow-dot stat tiles,
//  splits as bars of light (fastest in gold), heart rate in pink.
//  Design reference: Night Circuit board, screens 02–03.
//

import SwiftUI
import CoreLocation

struct RunDetailView: View {
    let run: RunRecord

    @State private var elevationProfile: [Double] = []
    @State private var heartRate: HealthKitService.HeartRateSummary?
    @State private var calories: Double?
    @State private var isPersonalRecord = false
    @State private var shareItem: ShareItem?

    private var traceCoordinates: [CLLocationCoordinate2D] {
        run.path?.map(\.coordinate) ?? []
    }

    var body: some View {
        ZStack {
            Night.ground.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 14) {
                    hero

                    if isPersonalRecord {
                        prBand
                    }

                    statGrid

                    if let splits = run.mileSplitSeconds, !splits.isEmpty {
                        splitsCard(splits)
                    }

                    if let heart = heartRateToShow {
                        heartRateCard(heart)
                    }

                    if elevationProfile.count > 2 {
                        elevationCard
                    }

                    if traceCoordinates.count > 1 {
                        shareButton
                    }
                }
                .padding(16)
            }
        }
        .navigationTitle("Run")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Night.ground, for: .navigationBar)
        .preferredColorScheme(.dark)
        .sheet(item: $shareItem) { item in
            ShareSheet(items: [item.url])
        }
        .task { await loadDetails() }
    }

    // MARK: - Hero

    private var hero: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 22)
                .fill(Night.panelDeep)
            DotGrid()
                .clipShape(RoundedRectangle(cornerRadius: 22))
            RadialGradient(colors: [Night.blue.opacity(0.14), .clear],
                           center: .center, startRadius: 20, endRadius: 220)

            VStack(alignment: .leading, spacing: 6) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(run.routeName)
                        .font(.system(size: 17, weight: .bold))
                        .foregroundColor(Night.text)
                    Text(run.date.formatted(date: .complete, time: .shortened))
                        .font(.system(size: 11))
                        .foregroundColor(Night.dim)
                }

                if traceCoordinates.count > 2 {
                    NeonTraceView(coordinates: traceCoordinates,
                                  color: isPersonalRecord ? Night.gold : Night.blue,
                                  lineWidth: 2.8,
                                  animated: true)
                        .frame(height: 190)
                        .padding(.horizontal, 12)
                }

                HStack(alignment: .firstTextBaseline, spacing: 7) {
                    Text(formatPace(run.paceSecondsPerMile))
                        .font(.system(size: 44, weight: .heavy, design: .rounded))
                        .monospacedDigit()
                        .foregroundColor(Night.text)
                        .shadow(color: Night.cyan.opacity(0.55), radius: 12)
                    Text("/MI AVG PACE")
                        .font(.system(size: 11, weight: .semibold))
                        .kerning(1.6)
                        .foregroundColor(Night.dim)
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .overlay(RoundedRectangle(cornerRadius: 22).stroke(Night.blue.opacity(0.45), lineWidth: 1))
        .shadow(color: Night.blue.opacity(0.14), radius: 18)
    }

    private var prBand: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(Night.gold)
                .frame(width: 13, height: 13)
                .shadow(color: Night.gold, radius: 6)
            Text("BEST TIME ON THIS ROUTE")
                .font(.system(size: 11, weight: .bold))
                .kerning(1.2)
                .foregroundColor(Night.gold)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 9)
        .background(Capsule().fill(Night.gold.opacity(0.08)))
        .overlay(Capsule().stroke(Night.gold.opacity(0.55), lineWidth: 1))
        .shadow(color: Night.gold.opacity(0.22), radius: 10)
    }

    // MARK: - Stats

    private var statGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible())], spacing: 10) {
            StatTile(label: "DISTANCE", value: String(format: "%.2f", run.miles),
                     unit: "mi", tint: Night.blue)
            StatTile(label: "TIME", value: formatTime(run.seconds), tint: Night.cyan)
            StatTile(label: "ELEV GAIN",
                     value: elevationGainFeet.map { String(format: "+%.0f", $0) } ?? "—",
                     unit: elevationGainFeet != nil ? "ft" : nil, tint: Night.ember)
            if let calories = caloriesToShow {
                StatTile(label: "CALORIES", value: String(format: "%.0f", calories),
                         tint: Color(red: 1, green: 0.48, blue: 0.36))
            }
            if let heart = heartRateToShow {
                StatTile(label: "AVG HEART RATE", value: String(format: "%.0f", heart.average),
                         unit: "bpm", tint: Night.pink)
                StatTile(label: "MAX HEART RATE", value: String(format: "%.0f", heart.peak),
                         unit: "bpm", tint: Night.pink)
            }
        }
    }

    private var elevationGainFeet: Double? {
        guard elevationProfile.count > 1 else { return nil }
        return ElevationService.gainMeters(ofProfile: elevationProfile) * 3.28084
    }

    // MARK: - Splits

    private func splitsCard(_ splits: [Double]) -> some View {
        let fastest = splits.min() ?? 1

        return GlowCard {
            VStack(alignment: .leading, spacing: 9) {
                CapLabel(text: "SPLITS", color: Night.cyan)

                ForEach(splits.indices, id: \.self) { index in
                    let split = splits[index]
                    let isFastest = split == fastest && splits.count > 1

                    HStack(spacing: 9) {
                        Text("MI \(index + 1)")
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundColor(Night.dim)
                            .frame(width: 34, alignment: .leading)

                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                Capsule().fill(Color(red: 0.086, green: 0.125, blue: 0.184))
                                Capsule()
                                    .fill(LinearGradient(
                                        colors: isFastest
                                            ? [Color(red: 0.91, green: 0.72, blue: 0.23), Night.gold]
                                            : [Night.blue, Night.cyan],
                                        startPoint: .leading, endPoint: .trailing))
                                    .frame(width: geo.size.width * (fastest / split))
                                    .shadow(color: (isFastest ? Night.gold : Night.cyan).opacity(0.5),
                                            radius: 5)
                            }
                        }
                        .frame(height: 9)

                        Text(formatPace(split))
                            .font(.system(size: 11, design: .monospaced).weight(isFastest ? .bold : .regular))
                            .foregroundColor(isFastest ? Night.gold : Night.text)
                            .frame(width: 46, alignment: .trailing)
                    }
                }

                if splits.count > 1 {
                    HStack {
                        Spacer()
                        CapLabel(text: "◆ FASTEST", color: Night.gold)
                    }
                }
            }
        }
    }

    // MARK: - Heart rate

    private func heartRateCard(_ heart: HealthKitService.HeartRateSummary) -> some View {
        GlowCard(stroke: Night.pink.opacity(0.3), glow: Night.pink.opacity(0.07)) {
            VStack(alignment: .leading, spacing: 9) {
                HStack {
                    CapLabel(text: "HEART RATE", color: Night.pink)
                    Spacer()
                    hrChip(String(format: "AVG %.0f", heart.average))
                    hrChip(String(format: "MAX %.0f", heart.peak))
                }

                if heart.series.count > 2 {
                    heartRateChart(heart.series)
                        .frame(height: 66)

                    HStack {
                        CapLabel(text: "START")
                        Spacer()
                        CapLabel(text: "FINISH")
                    }
                }
            }
        }
    }

    private func hrChip(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 9, weight: .bold, design: .monospaced))
            .foregroundColor(Night.pink)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(Capsule().stroke(Night.pink.opacity(0.5), lineWidth: 1))
    }

    private func heartRateChart(_ series: [Double]) -> some View {
        Canvas { context, size in
            let lo = (series.min() ?? 0) - 5
            let hi = (series.max() ?? 1) + 5
            let span = max(hi - lo, 10)
            let points = series.enumerated().map { index, value in
                CGPoint(x: size.width * CGFloat(index) / CGFloat(max(series.count - 1, 1)),
                        y: size.height * CGFloat(1 - (value - lo) / span))
            }
            guard let first = points.first, let last = points.last else { return }

            var area = Path()
            area.move(to: CGPoint(x: first.x, y: size.height))
            points.forEach { area.addLine(to: $0) }
            area.addLine(to: CGPoint(x: last.x, y: size.height))
            area.closeSubpath()
            context.fill(area, with: .linearGradient(
                Gradient(colors: [Night.pink.opacity(0.32), Night.pink.opacity(0.02)]),
                startPoint: .zero, endPoint: CGPoint(x: 0, y: size.height)))

            var line = Path()
            line.move(to: first)
            points.dropFirst().forEach { line.addLine(to: $0) }
            context.drawLayer { layer in
                layer.addFilter(.blur(radius: 3))
                layer.opacity = 0.7
                layer.stroke(line, with: .color(Night.pink), lineWidth: 4)
            }
            context.stroke(line, with: .color(Night.pink),
                           style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
        }
    }

    // MARK: - Elevation + share

    private var elevationCard: some View {
        GlowCard(stroke: Night.ember.opacity(0.3), glow: Night.ember.opacity(0.06)) {
            VStack(alignment: .leading, spacing: 8) {
                CapLabel(text: "ELEVATION", color: Night.ember)
                elevationChart
                    .frame(height: 44)
            }
        }
    }

    private var elevationChart: some View {
        Canvas { context, size in
            let profile = elevationProfile
            guard let lo = profile.min(), let hi = profile.max() else { return }
            let span = max(hi - lo, 8)
            let points = profile.enumerated().map { index, value in
                CGPoint(x: size.width * CGFloat(index) / CGFloat(max(profile.count - 1, 1)),
                        y: 3 + (size.height - 6) * CGFloat(1 - (value - lo) / span))
            }
            guard let first = points.first, let last = points.last else { return }

            var area = Path()
            area.move(to: CGPoint(x: first.x, y: size.height))
            points.forEach { area.addLine(to: $0) }
            area.addLine(to: CGPoint(x: last.x, y: size.height))
            area.closeSubpath()
            context.fill(area, with: .color(Night.ember.opacity(0.15)))

            var line = Path()
            line.move(to: first)
            points.dropFirst().forEach { line.addLine(to: $0) }
            context.stroke(line, with: .color(Night.ember),
                           style: StrokeStyle(lineWidth: 1.8, lineCap: .round, lineJoin: .round))
        }
    }

    private var shareButton: some View {
        Button(action: shareTrace) {
            Text("Share GPX")
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 13)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(LinearGradient(colors: [Night.blue, Night.cyan],
                                             startPoint: .leading, endPoint: .trailing))
                )
                .shadow(color: Night.blue.opacity(0.4), radius: 12)
        }
        .buttonStyle(ThemeButtonStyle())
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
        if let routeID = run.routeID,
           let favorite = RouteManager.shared.favorite(withID: routeID),
           favorite.bestTime > 0, abs(favorite.bestTime - run.seconds) < 1 {
            isPersonalRecord = true
        }

        if traceCoordinates.count > 1,
           let profile = await ElevationService.shared.profile(for: traceCoordinates) {
            elevationProfile = profile
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
