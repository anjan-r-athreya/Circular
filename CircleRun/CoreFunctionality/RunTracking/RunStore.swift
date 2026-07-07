//
//  RunStore.swift
//  CircleRun
//
//  Every finished run, persisted. Favorites keep their podium of best
//  times; this is the complete log behind history, weekly mileage, and
//  streaks.
//

import Foundation

struct RunRecord: Identifiable, Codable {
    let id: UUID
    let date: Date
    let routeName: String
    /// The favorite this run was on, when it was one.
    let routeID: UUID?
    let miles: Double
    let seconds: TimeInterval

    var paceSecondsPerMile: Double {
        miles > 0.05 ? seconds / miles : 0
    }
}

final class RunStore: ObservableObject {
    static let shared = RunStore()
    private static let storageKey = "runHistory"

    /// Newest first.
    @Published private(set) var runs: [RunRecord] = []

    private init() {
        load()
    }

    func record(_ run: RunRecord) {
        runs.insert(run, at: 0)
        save()
    }

    func delete(_ run: RunRecord) {
        runs.removeAll { $0.id == run.id }
        save()
    }

    // MARK: - Stats

    var totalMiles: Double {
        runs.reduce(0) { $0 + $1.miles }
    }

    var thisWeekMiles: Double {
        let calendar = Calendar.current
        guard let weekStart = calendar.dateInterval(of: .weekOfYear, for: Date())?.start else {
            return 0
        }
        return runs.filter { $0.date >= weekStart }.reduce(0) { $0 + $1.miles }
    }

    /// Consecutive days with at least one run, counting back from today.
    /// A rest-free today isn't required — the streak survives until a full
    /// day is actually missed.
    var currentStreakDays: Int {
        let calendar = Calendar.current
        let runDays = Set(runs.map { calendar.startOfDay(for: $0.date) })
        guard !runDays.isEmpty else { return 0 }

        var day = calendar.startOfDay(for: Date())
        if !runDays.contains(day) {
            guard let yesterday = calendar.date(byAdding: .day, value: -1, to: day),
                  runDays.contains(yesterday) else { return 0 }
            day = yesterday
        }

        var streak = 0
        while runDays.contains(day) {
            streak += 1
            guard let previous = calendar.date(byAdding: .day, value: -1, to: day) else { break }
            day = previous
        }
        return streak
    }

    // MARK: - Persistence

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: Self.storageKey),
              let decoded = try? JSONDecoder().decode([RunRecord].self, from: data) else { return }
        runs = decoded
    }

    private func save() {
        if let data = try? JSONEncoder().encode(runs) {
            UserDefaults.standard.set(data, forKey: Self.storageKey)
        }
    }
}

#if DEBUG
// Dev-build helpers so the Activity tab can be exercised before any real
// runs exist. Not compiled into release builds.
extension RunStore {
    /// Replaces history with a few weeks of plausible runs, including a
    /// four-day streak ending today.
    func seedSampleData() {
        let calendar = Calendar.current
        let now = Date()
        let routeNames = ["Marina Loop", "River Path 5K", "Generated Route",
                          "Hilltop Circuit", "Park Perimeter"]
        // (days ago, miles, pace min/mi)
        let plan: [(Int, Double, Double)] = [
            (0, 3.1, 9.4), (1, 5.0, 9.9), (2, 2.6, 8.9), (3, 4.2, 10.3),
            (5, 6.2, 10.1), (7, 3.5, 9.2), (8, 3.1, 9.6), (10, 8.0, 10.8),
            (12, 4.0, 9.8), (14, 5.5, 10.2), (16, 3.0, 9.0), (19, 4.4, 10.0),
        ]

        var sample: [RunRecord] = []
        for (i, entry) in plan.enumerated() {
            guard let day = calendar.date(byAdding: .day, value: -entry.0, to: now) else { continue }
            let date = calendar.date(bySettingHour: i % 2 == 0 ? 7 : 18,
                                     minute: (i * 13) % 60,
                                     second: 0, of: day) ?? day
            sample.append(RunRecord(
                id: UUID(),
                date: min(date, now),
                routeName: routeNames[i % routeNames.count],
                routeID: nil,
                miles: entry.1,
                seconds: entry.1 * entry.2 * 60
            ))
        }

        runs = sample.sorted { $0.date > $1.date }
        save()
    }

    func clearHistory() {
        runs = []
        save()
    }
}
#endif
