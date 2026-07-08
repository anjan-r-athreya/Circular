//
//  ActivityView.swift
//  CircleRun
//
//  The run log in the Night Circuit language: a week panel with glowing
//  day bars, then every run as its own neon loop. Design reference:
//  Night Circuit board, screen 01.
//

import SwiftUI

struct ActivityView: View {
    @ObservedObject private var store = RunStore.shared

    /// routeID → standing best time, so PR runs wear gold in the list.
    @State private var bestTimes: [UUID: TimeInterval] = [:]

    var body: some View {
        NavigationStack {
            ZStack {
                Night.ground.ignoresSafeArea()

                if store.runs.isEmpty {
                    emptyState
                } else {
                    List {
                        Section {
                            header
                                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 4, trailing: 16))
                                .listRowBackground(Color.clear)
                                .listRowSeparator(.hidden)

                            weekPanel
                                .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 12, trailing: 16))
                                .listRowBackground(Color.clear)
                                .listRowSeparator(.hidden)

                            CapLabel(text: "RUNS", color: Night.faint)
                                .listRowInsets(EdgeInsets(top: 0, leading: 22, bottom: 2, trailing: 16))
                                .listRowBackground(Color.clear)
                                .listRowSeparator(.hidden)
                        }

                        Section {
                            ForEach(store.runs) { run in
                                ZStack {
                                    // Card is the visual; the link sits invisible on top.
                                    runCard(run)
                                    NavigationLink(destination: RunDetailView(run: run)) {
                                        EmptyView()
                                    }
                                    .opacity(0)
                                }
                                .listRowInsets(EdgeInsets(top: 5, leading: 16, bottom: 5, trailing: 16))
                                .listRowBackground(Color.clear)
                                .listRowSeparator(.hidden)
                            }
                            .onDelete { offsets in
                                offsets.map { store.runs[$0] }.forEach(store.delete)
                            }
                        }
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .onAppear(perform: loadBestTimes)
            #if DEBUG
            .overlay(alignment: .topTrailing) { debugMenu }
            #endif
        }
        .preferredColorScheme(.dark)
    }

    // MARK: - Header + week panel

    private var header: some View {
        HStack {
            Text("Activity")
                .font(.system(size: 30, weight: .heavy, design: .rounded))
                .foregroundColor(Night.text)

            Spacer()

            if store.currentStreakDays > 0 {
                HStack(spacing: 6) {
                    Image(systemName: "flame.fill")
                        .font(.system(size: 11))
                        .foregroundColor(Night.ember)
                        .shadow(color: Night.ember, radius: 5)
                    Text("\(store.currentStreakDays)-DAY STREAK")
                        .font(.system(size: 10, weight: .bold))
                        .kerning(1.2)
                        .foregroundColor(Night.ember)
                }
                .padding(.horizontal, 11)
                .padding(.vertical, 6)
                .background(Capsule().stroke(Night.ember.opacity(0.5), lineWidth: 1))
                .shadow(color: Night.ember.opacity(0.25), radius: 8)
            }
        }
        .padding(.top, 6)
    }

    private var weekPanel: some View {
        GlowCard {
            VStack(alignment: .leading, spacing: 8) {
                CapLabel(text: "THIS WEEK")

                HStack(alignment: .bottom) {
                    HStack(alignment: .firstTextBaseline, spacing: 3) {
                        Text(String(format: "%.1f", store.thisWeekMiles))
                            .font(.system(size: 36, weight: .heavy, design: .rounded))
                            .monospacedDigit()
                            .foregroundColor(Night.text)
                            .shadow(color: Night.cyan.opacity(0.5), radius: 10)
                        Text("mi")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(Night.dim)
                    }

                    Spacer()

                    weekBars
                }

                HStack {
                    Text(weekMetaLine)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(Night.dim)
                    Spacer()
                    Text("M T W T F S S")
                        .font(.system(size: 9, weight: .semibold))
                        .kerning(2)
                        .foregroundColor(Night.faint)
                }

                DashRule()

                Text(String(format: "%.1f mi lifetime · %d runs", store.totalMiles, store.runs.count))
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(Night.dim)
            }
        }
    }

    private var weekBars: some View {
        let daily = dailyMilesThisWeek()
        let peak = max(daily.max() ?? 1, 0.1)
        let today = todayIndex()

        return HStack(alignment: .bottom, spacing: 5) {
            ForEach(0..<7, id: \.self) { day in
                let fraction = daily[day] / peak
                Capsule()
                    .fill(barStyle(day: day, ran: daily[day] > 0, today: today))
                    .frame(width: 9, height: max(6, 44 * fraction))
                    .shadow(color: daily[day] > 0
                            ? (day == today ? .white.opacity(0.6) : Night.cyan.opacity(0.5))
                            : .clear,
                            radius: 5)
            }
        }
    }

    private func barStyle(day: Int, ran: Bool, today: Int) -> LinearGradient {
        if !ran {
            return LinearGradient(colors: [Color(red: 0.13, green: 0.19, blue: 0.29)],
                                  startPoint: .top, endPoint: .bottom)
        }
        if day == today {
            return LinearGradient(colors: [.white, Night.cyan], startPoint: .top, endPoint: .bottom)
        }
        return LinearGradient(colors: [Night.cyan, Night.blue], startPoint: .top, endPoint: .bottom)
    }

    // MARK: - Run cards

    private func runCard(_ run: RunRecord) -> some View {
        let isPR = isPersonalRecord(run)

        return GlowCard {
            HStack(spacing: 12) {
                traceThumb(run, gold: isPR)

                VStack(alignment: .leading, spacing: 2) {
                    if isPR {
                        CapLabel(text: "◆ BEST TIME", color: Night.gold)
                    }
                    Text(run.routeName)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(Night.text)
                        .lineLimit(1)
                    Text(run.date.formatted(date: .abbreviated, time: .shortened))
                        .font(.system(size: 11))
                        .foregroundColor(Night.dim)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text(String(format: "%.2f", run.miles))
                        .font(.system(size: 21, weight: .heavy, design: .rounded))
                        .monospacedDigit()
                        .foregroundColor(Night.text)
                    Text("\(formatTime(run.seconds)) · \(formatPace(run.paceSecondsPerMile))")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(Night.dim)
                }
            }
        }
    }

    private func traceThumb(_ run: RunRecord, gold: Bool) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 14)
                .fill(Night.panelDeep)
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(Night.line, lineWidth: 1))

            if let path = run.path, path.count > 2 {
                NeonTraceView(coordinates: path.map(\.coordinate),
                              color: gold ? Night.gold : Night.cyan,
                              lineWidth: 2)
                    .padding(5)
            } else {
                Image(systemName: "figure.run")
                    .font(.system(size: 18))
                    .foregroundColor(Night.faint)
            }
        }
        .frame(width: 54, height: 54)
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(spacing: 18) {
            NeonTraceView(coordinates: Route.sample().path, color: Night.blue, lineWidth: 2.4)
                .frame(width: 110, height: 110)
                .opacity(0.9)

            Text("No Runs Yet")
                .font(.system(size: 22, weight: .heavy, design: .rounded))
                .foregroundColor(Night.text)

            Text("Finish a run and save it — your history, weekly miles, and streak light up here.")
                .font(.system(size: 14))
                .foregroundColor(Night.dim)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 44)
        }
    }

    #if DEBUG
    private var debugMenu: some View {
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
                .foregroundColor(Night.dim)
                .padding(.trailing, 18)
                .padding(.top, 14)
        }
    }
    #endif

    // MARK: - Data helpers

    private func loadBestTimes() {
        var times: [UUID: TimeInterval] = [:]
        for favorite in RouteManager.shared.allFavorites() where favorite.bestTime > 0 {
            times[favorite.id] = favorite.bestTime
        }
        bestTimes = times
    }

    private func isPersonalRecord(_ run: RunRecord) -> Bool {
        guard let routeID = run.routeID, let best = bestTimes[routeID] else { return false }
        return abs(best - run.seconds) < 1
    }

    /// Miles per day of the current week, in the calendar's day order.
    private func dailyMilesThisWeek() -> [Double] {
        var days = [Double](repeating: 0, count: 7)
        let calendar = Calendar.current
        guard let weekStart = calendar.dateInterval(of: .weekOfYear, for: Date())?.start else {
            return days
        }
        for run in store.runs where run.date >= weekStart {
            let index = calendar.dateComponents([.day], from: weekStart, to: run.date).day ?? 0
            if (0..<7).contains(index) { days[index] += run.miles }
        }
        return days
    }

    private func todayIndex() -> Int {
        let calendar = Calendar.current
        guard let weekStart = calendar.dateInterval(of: .weekOfYear, for: Date())?.start else { return 0 }
        return min(6, max(0, calendar.dateComponents([.day], from: weekStart, to: Date()).day ?? 0))
    }

    private var weekMetaLine: String {
        let calendar = Calendar.current
        guard let weekStart = calendar.dateInterval(of: .weekOfYear, for: Date())?.start else { return "" }
        let seconds = store.runs.filter { $0.date >= weekStart }.reduce(0.0) { $0 + $1.seconds }
        let hours = Int(seconds) / 3600
        let minutes = (Int(seconds) % 3600) / 60
        return hours > 0 ? "\(hours)h \(String(format: "%02d", minutes))m running" : "\(minutes)m running"
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
