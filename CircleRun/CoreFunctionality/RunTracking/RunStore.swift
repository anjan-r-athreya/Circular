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
