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
    let bestTime: TimeInterval
    let distance: Double  // in miles
    
    // Convenience initializer for testing and previews
    static func sample(id: UUID = UUID(), name: String = "Sample Route",
                      coordinates: [CLLocationCoordinate2D]? = nil,
                      runCount: Int = 5,
                      bestTime: TimeInterval = 1320,
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
            bestTime: bestTime,
            distance: distance
        )
    }
    
    // Sample data for previews and testing
    static let samples = [
        Route.sample(name: "Marina Loop", runCount: 12, bestTime: 1850),
        Route.sample(name: "Golden Gate Park", runCount: 8, bestTime: 2250),
        Route.sample(name: "Embarcadero Run", runCount: 15, bestTime: 1620)
    ]
    
    // For Hashable conformance
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: Route, rhs: Route) -> Bool {
        lhs.id == rhs.id
    }
    
    init(id: UUID, name: String, path: [CLLocationCoordinate2D], runCount: Int, bestTime: TimeInterval, distance: Double) {
        self.id = id
        self.name = name
        self.path = path
        self.runCount = runCount
        self.bestTime = bestTime
        self.distance = distance
    }
}
