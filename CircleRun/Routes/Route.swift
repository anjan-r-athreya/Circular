//
//  Route.swift
//  CircleRun
//
//  Created by Anjan Athreya on 5/17/25.
//

import Foundation
import MapKit
import SwiftUI

struct Route: Identifiable, Hashable {
    let id: UUID
    let name: String
    let path: [CLLocationCoordinate2D]
    let runCount: Int
    /// Fastest completed runs of this route, ascending, at most three kept.
    let bestTimes: [TimeInterval]
    let distance: Double  // in miles

    /// The single best (fastest) time, 0 when the route hasn't been run yet.
    var bestTime: TimeInterval { bestTimes.first ?? 0 }

    // Convenience initializer for testing and previews
    static func sample(id: UUID = UUID(), name: String = "Sample Route",
                      coordinates: [CLLocationCoordinate2D]? = nil,
                      runCount: Int = 5,
                      bestTimes: [TimeInterval] = [1320, 1395, 1440],
                      distance: Double = 1.0) -> Route {

        let defaultCoordinates = [
            CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
            CLLocationCoordinate2D(latitude: 37.7750, longitude: -122.4180),
            CLLocationCoordinate2D(latitude: 37.7730, longitude: -122.4170),
            CLLocationCoordinate2D(latitude: 37.7720, longitude: -122.4190)
        ]

        return Route(
            id: id,
            name: name,
            path: coordinates ?? defaultCoordinates,
            runCount: runCount,
            bestTimes: bestTimes,
            distance: distance
        )
    }

    // Sample data for previews and testing
    static let samples = [
        Route.sample(name: "Marina Loop", runCount: 12, bestTimes: [1850, 1920, 2010]),
        Route.sample(name: "Golden Gate Park", runCount: 8, bestTimes: [2250, 2380]),
        Route.sample(name: "Embarcadero Run", runCount: 15, bestTimes: [1620, 1655, 1701])
    ]

    // For Hashable conformance
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: Route, rhs: Route) -> Bool {
        lhs.id == rhs.id
    }

    init(id: UUID, name: String, path: [CLLocationCoordinate2D], runCount: Int, bestTimes: [TimeInterval], distance: Double) {
        self.id = id
        self.name = name
        self.path = path
        self.runCount = runCount
        self.bestTimes = bestTimes
        self.distance = distance
    }

    /// A copy of this route with a newly recorded run folded in: run count
    /// bumped and the time slotted into the top three if it qualifies.
    func recordingRun(time: TimeInterval) -> Route {
        let times = Array((bestTimes + [time]).filter { $0 > 0 }.sorted().prefix(3))
        return Route(id: id, name: name, path: path,
                     runCount: runCount + 1, bestTimes: times, distance: distance)
    }
}
