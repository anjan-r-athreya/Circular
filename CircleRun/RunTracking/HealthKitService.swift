//
//  HealthKitService.swift
//  CircleRun
//
//  Writes saved runs to Apple Health as running workouts (with distance),
//  when the user has turned sync on in Settings. Write-only — the app
//  never reads Health data.
//

import Foundation
import HealthKit

final class HealthKitService {
    static let shared = HealthKitService()

    private let store = HKHealthStore()

    private init() {}

    var isAvailable: Bool {
        HKHealthStore.isHealthDataAvailable()
    }

    private var syncEnabled: Bool {
        UserDefaults.standard.bool(forKey: "healthKitSyncEnabled")
    }

    /// Requests write authorization; safe to call repeatedly (the system
    /// only prompts once).
    func requestAuthorization(completion: ((Bool) -> Void)? = nil) {
        guard isAvailable else {
            completion?(false)
            return
        }
        let types: Set<HKSampleType> = [
            HKObjectType.workoutType(),
            HKQuantityType(.distanceWalkingRunning),
        ]
        store.requestAuthorization(toShare: types, read: []) { granted, error in
            if let error {
                print("HealthKit authorization failed: \(error.localizedDescription)")
            }
            DispatchQueue.main.async { completion?(granted) }
        }
    }

    // MARK: - Reading Watch metrics

    struct HeartRateSummary {
        let average: Double
        let peak: Double
        /// Chronological BPM samples across the run, for the chart.
        let series: [Double]
    }

    /// Asks to read heart rate and active energy (for run details). Safe to
    /// call repeatedly; the system prompts once.
    func requestReadAuthorization() {
        guard isAvailable else { return }
        let types: Set<HKObjectType> = [
            HKQuantityType(.heartRate),
            HKQuantityType(.activeEnergyBurned),
        ]
        store.requestAuthorization(toShare: [], read: types) { _, error in
            if let error {
                print("HealthKit read authorization failed: \(error.localizedDescription)")
            }
        }
    }

    /// Heart rate recorded (by an Apple Watch or any other source) during
    /// the window. Nil when Health has nothing for it or access was denied —
    /// HealthKit deliberately makes those look identical.
    func heartRate(from start: Date, to end: Date) async -> HeartRateSummary? {
        guard isAvailable else { return nil }
        return await withCheckedContinuation { continuation in
            let predicate = HKQuery.predicateForSamples(withStart: start, end: end)
            let sort = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)
            let query = HKSampleQuery(sampleType: HKQuantityType(.heartRate),
                                      predicate: predicate,
                                      limit: 600,
                                      sortDescriptors: [sort]) { _, samples, _ in
                guard let heartSamples = samples as? [HKQuantitySample],
                      !heartSamples.isEmpty else {
                    continuation.resume(returning: nil)
                    return
                }
                let bpm = HKUnit.count().unitDivided(by: .minute())
                let values = heartSamples.map { $0.quantity.doubleValue(for: bpm) }
                continuation.resume(returning: HeartRateSummary(
                    average: values.reduce(0, +) / Double(values.count),
                    peak: values.max() ?? 0,
                    series: values
                ))
            }
            store.execute(query)
        }
    }

    /// Active calories burned in the window, or nil if Health has none.
    func activeCalories(from start: Date, to end: Date) async -> Double? {
        guard isAvailable else { return nil }
        return await withCheckedContinuation { continuation in
            let predicate = HKQuery.predicateForSamples(withStart: start, end: end)
            let query = HKStatisticsQuery(quantityType: HKQuantityType(.activeEnergyBurned),
                                          quantitySamplePredicate: predicate,
                                          options: .cumulativeSum) { _, statistics, _ in
                guard let sum = statistics?.sumQuantity() else {
                    continuation.resume(returning: nil)
                    return
                }
                continuation.resume(returning: sum.doubleValue(for: .kilocalorie()))
            }
            store.execute(query)
        }
    }

    /// Saves a finished run as an outdoor running workout ending now.
    /// No-op when sync is off, Health is unavailable, or the run is empty.
    func saveRun(miles: Double, seconds: TimeInterval, endDate: Date = Date()) {
        guard syncEnabled, isAvailable, miles > 0.05, seconds > 0 else { return }

        let start = endDate.addingTimeInterval(-seconds)
        let configuration = HKWorkoutConfiguration()
        configuration.activityType = .running
        configuration.locationType = .outdoor

        requestAuthorization { [store] granted in
            guard granted else { return }

            let builder = HKWorkoutBuilder(healthStore: store,
                                           configuration: configuration,
                                           device: .local())
            builder.beginCollection(withStart: start) { began, _ in
                guard began else { return }

                let distance = HKQuantitySample(
                    type: HKQuantityType(.distanceWalkingRunning),
                    quantity: HKQuantity(unit: .mile(), doubleValue: miles),
                    start: start,
                    end: endDate
                )
                builder.add([distance]) { _, _ in
                    builder.endCollection(withEnd: endDate) { ended, _ in
                        guard ended else { return }
                        builder.finishWorkout { workout, error in
                            if let error {
                                print("HealthKit save failed: \(error.localizedDescription)")
                            } else if workout != nil {
                                print("Run saved to Apple Health")
                            }
                        }
                    }
                }
            }
        }
    }
}
