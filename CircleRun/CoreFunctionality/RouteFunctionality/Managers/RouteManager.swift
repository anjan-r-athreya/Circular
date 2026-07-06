//
//  RouteManager.swift
//  CircleRun
//
//  Created by Anjan Athreya on 4/7/25.
//

import SwiftUI
import Foundation
import MapKit
import CoreLocation

class RouteManager {
    private var isRequestInProgress = false
    static let shared = RouteManager()

    init() {
    }
    
    // Add a method to save a route as favorite
    func saveAsFavorite(name: String, coordinates: [CLLocationCoordinate2D], runTime: TimeInterval = 0) {
        // Create a new Route object
        let newRoute = Route(
            id: UUID(),
            name: name,
            path: coordinates,
            runCount: 0,
            bestTimes: runTime > 0 ? [runTime] : [],
            distance: calculateRouteDistance(coordinates: coordinates)  // Calculate actual distance
        )
        
        // Check if this route already exists to prevent duplicates
        if let existingFavorites = loadFavorites() {
            // Check for a route with same name or very similar path
            for existingRoute in existingFavorites {
                if existingRoute.name == name {
                    // Route with this name already exists, don't add duplicate
                    print("Route with name \(name) already exists in favorites")
                    return
                }
            }
        }
        
        // Add to favorites list
        if var favorites = UserDefaults.standard.object(forKey: "savedFavorites") as? [Data] {
            // Encode and append new route
            if let encodedRoute = try? JSONEncoder().encode(newRoute) {
                favorites.append(encodedRoute)
                UserDefaults.standard.set(favorites, forKey: "savedFavorites")
            }
        } else {
            // Create new favorites array
            if let encodedRoute = try? JSONEncoder().encode(newRoute) {
                UserDefaults.standard.set([encodedRoute], forKey: "savedFavorites")
            }
        }
        
        // Notify that favorites have changed
        NotificationCenter.default.post(name: Notification.Name("FavoritesUpdated"), object: nil)
    }
    
    /// Records a completed run of a favorited route: bumps its run count and
    /// slots the time into the route's top three if it qualifies.
    func recordRun(routeID: UUID, time: TimeInterval) {
        guard time > 0, var favorites = loadFavorites(),
              let index = favorites.firstIndex(where: { $0.id == routeID }) else { return }

        favorites[index] = favorites[index].recordingRun(time: time)
        saveFavoritesToUserDefaults(favorites)
        NotificationCenter.default.post(name: Notification.Name("FavoritesUpdated"), object: nil)
    }

    // Method to remove a route from favorites
    func removeFromFavorites(name: String, coordinates: [CLLocationCoordinate2D]) {
        guard let favorites = loadFavorites() else { return }
        
        var updatedFavorites: [Route] = []
        
        // Keep all routes except the one with matching name
        for route in favorites {
            if route.name != name {
                updatedFavorites.append(route)
            }
        }
        
        // Save updated favorites list
        saveFavoritesToUserDefaults(updatedFavorites)
        
        // Notify that favorites have changed
        NotificationCenter.default.post(name: Notification.Name("FavoritesUpdated"), object: nil)
    }
    
    // Helper method to load favorites
    private func loadFavorites() -> [Route]? {
        guard let savedData = UserDefaults.standard.object(forKey: "savedFavorites") as? [Data] else {
            return nil
        }
        
        var loadedRoutes: [Route] = []
        for data in savedData {
            if let route = try? JSONDecoder().decode(Route.self, from: data) {
                loadedRoutes.append(route)
            }
        }
        
        return loadedRoutes.isEmpty ? nil : loadedRoutes
    }
    
    // Helper method to save favorites
    private func saveFavoritesToUserDefaults(_ routes: [Route]) {
        var savedData: [Data] = []
        
        for route in routes {
            if let encodedRoute = try? JSONEncoder().encode(route) {
                savedData.append(encodedRoute)
            }
        }
        
        UserDefaults.standard.set(savedData, forKey: "savedFavorites")
    }
    
    // Helper method to calculate route distance
    private func calculateRouteDistance(coordinates: [CLLocationCoordinate2D]) -> Double {
        var totalDistance: CLLocationDistance = 0
        guard coordinates.count > 1 else { return 0 }
        
        for i in 0..<(coordinates.count - 1) {
            let loc1 = CLLocation(latitude: coordinates[i].latitude, longitude: coordinates[i].longitude)
            let loc2 = CLLocation(latitude: coordinates[i + 1].latitude, longitude: coordinates[i + 1].longitude)
            totalDistance += loc1.distance(from: loc2)
        }
        
        return totalDistance / 1609.34 // Convert meters to miles
    }
}

// Make Route conform to Codable if it isn't already
extension Route: Codable {
    enum CodingKeys: String, CodingKey {
        case id, name, runCount, bestTime, bestTimes, distance
        case path
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let id = try container.decode(UUID.self, forKey: .id)
        let name = try container.decode(String.self, forKey: .name)
        let runCount = try container.decode(Int.self, forKey: .runCount)
        let distance = try container.decode(Double.self, forKey: .distance)

        // Newer saves carry the top-three list; older ones just a single time.
        let bestTimes: [TimeInterval]
        if let times = try container.decodeIfPresent([TimeInterval].self, forKey: .bestTimes) {
            bestTimes = times
        } else {
            let legacy = try container.decodeIfPresent(TimeInterval.self, forKey: .bestTime) ?? 0
            bestTimes = legacy > 0 ? [legacy] : []
        }

        // Decode coordinates from custom format
        let coordinateData = try container.decode([String: Double].self, forKey: .path)
        var coords: [CLLocationCoordinate2D] = []

        // Pairs of lat/lng values
        for i in 0..<(coordinateData.count / 2) {
            if let lat = coordinateData["lat_\(i)"],
               let lng = coordinateData["lng_\(i)"] {
                coords.append(CLLocationCoordinate2D(latitude: lat, longitude: lng))
            }
        }

        self.init(id: id, name: name, path: coords, runCount: runCount,
                  bestTimes: bestTimes, distance: distance)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(runCount, forKey: .runCount)
        try container.encode(bestTimes, forKey: .bestTimes)
        try container.encode(distance, forKey: .distance)

        // Encode coordinates in a format that can be stored
        var coordinateData: [String: Double] = [:]
        for (index, coordinate) in path.enumerated() {
            coordinateData["lat_\(index)"] = coordinate.latitude
            coordinateData["lng_\(index)"] = coordinate.longitude
        }
        try container.encode(coordinateData, forKey: .path)
    }
}
