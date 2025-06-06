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
    private var viewModel: MapViewModel
    private var isRequestInProgress = false
    static let shared = RouteManager(viewModel: MapViewModel())
    
    init(viewModel: MapViewModel) {
        self.viewModel = viewModel
    }
    
    func requestRoute(from: CLLocationCoordinate2D, to: CLLocationCoordinate2D, viewModel: MapViewModel) {
        let request = MKDirections.Request()
        request.source = MKMapItem(placemark: MKPlacemark(coordinate: from))
        request.destination = MKMapItem(placemark: MKPlacemark(coordinate: to))
        request.transportType = .walking

        MKDirections(request: request).calculate { [self] response, error in
            if let route = response?.routes.first {
                let polyline = route.polyline
                viewModel.routePolyline = route.polyline
                viewModel.position = .region(MKCoordinateRegion(route.polyline.boundingMapRect))
                
                self.viewModel.actualMiles = totalDistance(of: polyline)
            } else {
                print("Routing error: \(error?.localizedDescription ?? "Unknown error")")
            }
        }
    }
    
    // New function that implements binary search to generate a route with target distance
    func generateRouteWithTargetDistance(from start: CLLocationCoordinate2D, targetMiles: Double,
                                         errorMargin: Double = 0.01, viewModel: MapViewModel, completion: @escaping () -> Void) {
        // Start with a guess that's slightly shorter than needed since routes are typically longer
        var minDistance = 0.0
        var maxDistance = targetMiles * 1.5 // Start with 150% of target distance
        var currentDistance = targetMiles * 0.8 // Initial guess is 80% of target
        
        // Track attempts to prevent infinite loops
        var attempts = 0
        let maxAttempts = 15
        
        func tryDistance() {
            attempts += 1
            print("Attempt \(attempts): Trying distance of \(currentDistance) miles")
            
            let distanceInMeters = currentDistance * 1609.34
            let end = offsetCoordinate(from: start, metersEast: distanceInMeters, metersNorth: 0)
            
            let request = MKDirections.Request()
            request.source = MKMapItem(placemark: MKPlacemark(coordinate: start))
            request.destination = MKMapItem(placemark: MKPlacemark(coordinate: end))
            request.transportType = .walking
            
            MKDirections(request: request).calculate { response, error in
                if let route = response?.routes.first {
                    let actualDistance = totalDistance(of: route.polyline)
                    print("Generated route of \(actualDistance) miles")
                    
                    // Check if we're within acceptable range
                    if ((actualDistance - targetMiles <= errorMargin) && (actualDistance - targetMiles > 0)) || attempts >= maxAttempts {
                        // We found a suitable route or maxed out attempts
                        viewModel.routePolyline = route.polyline
                        viewModel.position = .region(MKCoordinateRegion(route.polyline.boundingMapRect))
                        viewModel.actualMiles = actualDistance
                        completion()
                        print("Final route: \(actualDistance) miles (target: \(targetMiles))")
                        return
                    }
                    
                    // Binary search adjustment
                    if actualDistance > targetMiles {
                        // Route too long, decrease distance
                        maxDistance = currentDistance
                        currentDistance = (minDistance + currentDistance) / 2
                        print("Route too long, adjusting to \(currentDistance) miles")
                    } else {
                        // Route too short, increase distance
                        minDistance = currentDistance
                        currentDistance = (currentDistance + maxDistance) / 2
                        print("Route too short, adjusting to \(currentDistance) miles")
                    }
                    
                    // Try again with new distance
                    DispatchQueue.main.async {
                        tryDistance()
                    }
                } else {
                    print("Routing error: \(error?.localizedDescription ?? "Unknown error")")
                    completion()
                }
            }
        }
        
        // Start the process
        tryDistance()
    }
    
//    func generateLoop(from start: CLLocationCoordinate2D, polygonSides: Int = 6, targetMiles: Double, viewModel: MapViewModel) {
//        // Initial distance estimate (will be adjusted by binary search)
//        let radiusEstimate = targetMiles * 0.3 // Start with radius ~30% of total desired distance
//
//        // Create waypoints in a rough circle
//        var waypoints: [CLLocationCoordinate2D] = []
//        for i in 0..<polygonSides {
//            let angle = 2.0 * Double.pi * Double(i) / Double(polygonSides)
//            let waypointEast = radiusEstimate * 1609.34 * cos(angle)
//            let waypointNorth = radiusEstimate * 1609.34 * sin(angle)
//            let waypoint = offsetCoordinate(from: start, metersEast: waypointEast, metersNorth: waypointNorth)
//            waypoints.append(waypoint)
//        }
//
//        // Now implement binary search to adjust the radius until the total route matches target distance
//        // [Binary search implementation would go here]
//    }
//
    // Add a method to save a route as favorite
    func saveAsFavorite(name: String, coordinates: [CLLocationCoordinate2D], runTime: TimeInterval = 0) {
        // Create a new Route object
        let newRoute = Route(
            id: UUID(),
            name: name,
            path: coordinates,
            runCount: 1,
            bestTime: runTime,
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
        case id, name, runCount, bestTime, distance
        case path
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        runCount = try container.decode(Int.self, forKey: .runCount)
        bestTime = try container.decode(TimeInterval.self, forKey: .bestTime)
        distance = try container.decode(Double.self, forKey: .distance)
        
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
        path = coords
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(runCount, forKey: .runCount)
        try container.encode(bestTime, forKey: .bestTime)
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
