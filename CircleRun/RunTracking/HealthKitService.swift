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
