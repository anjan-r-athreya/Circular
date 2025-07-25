//
//  MapboxLoopGeneration.swift
//  CircleRun
//
//  Created by Anjan Athreya on 6/5/25.
//

import Foundation
import MapboxMaps
import MapboxDirections
import CoreLocation

class MapboxLoopGenerator {
    static let shared = MapboxLoopGenerator()
    private var isRequestInProgress = false
    private var bestAttemptMileage: Double = 0.0
    
    private init() {}
    
    // Main function to generate circular routes
    func generateCircularRoute(from start: CLLocationCoordinate2D,
                             targetMiles: Double,
                             numPoints: Int = 8,
                             errorMargin: Double = 0.005,
                             completion: @escaping (RouteResponse?, Error?) -> Void) {
        // Make initial guess based on a simple heuristic
        let initialScale = (sqrt(targetMiles / (2 * Double.pi)) * 0.5) // Rough estimate for circular path
        
        createRouteWithScale(from: start,
                           scale: initialScale,
                           numPoints: numPoints,
                           targetMiles: targetMiles,
                           errorMargin: errorMargin,
                           attemptCount: 1,
                           maxAttempts: 5,
                           completion: completion)
    }
    
    private func createRouteWithScale(from start: CLLocationCoordinate2D,
                                    scale: Double,
                                    numPoints: Int,
                                    targetMiles: Double,
                                    errorMargin: Double,
                                    attemptCount: Int,
                                    maxAttempts: Int,
                                    completion: @escaping (RouteResponse?, Error?) -> Void) {
        guard !isRequestInProgress else { return }
        isRequestInProgress = true
        
        print("\n=== Attempt \(attemptCount) of \(maxAttempts) ===")
        print("Target distance: \(String(format: "%.2f", targetMiles)) miles")
        print("Current scale: \(String(format: "%.2f", scale))")
        print("Number of points: \(numPoints)")
        
        // Calculate initial circle properties
        let radiusInMeters = scale * 1609.34
        let estimatedCircumference = 2 * Double.pi * radiusInMeters
        print("Radius: \(String(format: "%.2f", scale)) miles")
        print("Estimated circumference: \(String(format: "%.2f", estimatedCircumference / 1609.34)) miles")
        
        // Create waypoints with precise spacing
        var waypoints: [Waypoint] = []
        waypoints.append(Waypoint(coordinate: start))
        
        // Calculate angular spacing for even distribution
        let angleIncrement = 2.0 * Double.pi / Double(numPoints)
        
        for i in 0..<numPoints {
            let angle = angleIncrement * Double(i)
            let waypointEast = radiusInMeters * cos(angle)
            let waypointNorth = radiusInMeters * sin(angle)
            let waypoint = offsetCoordinate(from: start, metersEast: waypointEast, metersNorth: waypointNorth)
            waypoints.append(Waypoint(coordinate: waypoint))
        }
        
        // Add start point as final waypoint to complete the loop
        waypoints.append(Waypoint(coordinate: start))
        
        // Calculate straight-line distances between waypoints for reference
        print("\nWaypoint Spacing Validation:")
        for i in 0..<waypoints.count - 1 {
            let coord1 = waypoints[i].coordinate
            let coord2 = waypoints[i + 1].coordinate
            let distance = calculateRouteDistance(coordinates: [coord1, coord2])
            print("Waypoint \(i) to \(i + 1): \(String(format: "%.2f", distance)) miles")
        }
        
        // Create Mapbox directions request
        let options = RouteOptions(waypoints: waypoints, profileIdentifier: .automobile)
        options.routeShapeResolution = .full
        options.shapeFormat = .polyline6
        options.includesSteps = true
        options.roadClassesToAvoid = [.ferry, .motorway]
        
        // Request route from Mapbox
        Directions.shared.calculate(options) { [weak self] (session, result) in
            guard let self = self else { return }
            self.isRequestInProgress = false
            
            switch result {
            case .failure(let error):
                print("Failed to generate route: \(error.localizedDescription)")
                if numPoints > 4 {
                    // Try with fewer points if route generation fails
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        self.generateCircularRoute(from: start,
                                                targetMiles: targetMiles,
                                                numPoints: numPoints - 1,
                                                errorMargin: errorMargin,
                                                completion: completion)
                    }
                } else {
                    completion(nil, error)
                }
                
            case .success(let response):
                guard let route = response.routes?.first,
                      let coordinates = route.shape?.coordinates else {
                    completion(nil, NSError(domain: "MapboxLoopGenerator", code: -1, userInfo: [NSLocalizedDescriptionKey: "No route found"]))
                    return
                }
                
                let actualDistance = route.distance / 1609.34 // Convert meters to miles
                let isAcceptableRoute = abs(actualDistance - targetMiles) <= errorMargin
                let isFinalAttempt = attemptCount >= maxAttempts
                
                if isAcceptableRoute || isFinalAttempt {
                    self.bestAttemptMileage = actualDistance
                    print("\nFinal Route Summary (Attempt \(attemptCount)):")
                    print("Target distance: \(String(format: "%.2f", targetMiles)) miles")
                    print("Actual distance: \(String(format: "%.2f", actualDistance)) miles")
                    print("Difference from target: \(String(format: "%.2f", abs(actualDistance - targetMiles))) miles")
                    print("Status: \(isAcceptableRoute ? "Within acceptable error margin" : "Max attempts reached")")
                    print("Number of coordinates: \(coordinates.count)")
                    
                    // Export GPX file for the final route
                    self.exportGPXFile(coordinates: coordinates, distance: actualDistance)
                    
                    completion(response, nil)
                    return
                }
                
                // Adjust scale based on actual distance
                let newScale = scale * sqrt(targetMiles / actualDistance)
                print("\nAdjusting scale:")
                print("Current: \(String(format: "%.2f", scale)) miles")
                print("New: \(String(format: "%.2f", newScale)) miles")
                print("Adjustment factor: \(String(format: "%.2f", sqrt(targetMiles / actualDistance)))")
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    self.createRouteWithScale(from: start,
                                           scale: newScale,
                                           numPoints: numPoints,
                                           targetMiles: targetMiles,
                                           errorMargin: errorMargin,
                                           attemptCount: attemptCount + 1,
                                           maxAttempts: maxAttempts,
                                           completion: completion)
                }
            }
        }
    }
    
    // Helper function to calculate route distance from coordinates
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
    
    // Helper function to offset coordinates
    private func offsetCoordinate(from coordinate: CLLocationCoordinate2D, metersEast: Double, metersNorth: Double) -> CLLocationCoordinate2D {
        let earthRadius = 6371000.0 // Earth's radius in meters
        
        let latChange = (metersNorth / earthRadius) * (180.0 / .pi)
        let lonChange = (metersEast / (earthRadius * cos(coordinate.latitude * .pi / 180.0))) * (180.0 / .pi)
        
        return CLLocationCoordinate2D(
            latitude: coordinate.latitude + latChange,
            longitude: coordinate.longitude + lonChange
        )
    }
    
    // Helper function to generate GPX content
    private func generateGPXContent(coordinates: [CLLocationCoordinate2D], routeName: String) -> String {
        var gpx = """
        <?xml version="1.0" encoding="UTF-8"?>
        <gpx version="1.1" creator="CircleRun Dev"
        xmlns="http://www.topografix.com/GPX/1/1"
        xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
        xsi:schemaLocation="http://www.topografix.com/GPX/1/1 http://www.topografix.com/GPX/1/1/gpx.xsd">
        <trk>
            <name>\(routeName)</name>
            <trkseg>
        """
        
        for coord in coordinates {
            gpx += """
            
                <trkpt lat="\(coord.latitude)" lon="\(coord.longitude)"></trkpt>
            """
        }
        
        gpx += """
            </trkseg>
        </trk>
        </gpx>
        """
        return gpx
    }
    
    // Helper function to get documents directory
    private func getDocumentsDirectory() -> URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }
    
    // Helper function to save GPX file
    private func exportGPXFile(coordinates: [CLLocationCoordinate2D], distance: Double) {
        let routeName = "CircleRoute_\(String(format: "%.1f", distance))mi"
        let timestamp = ISO8601DateFormatter().string(from: Date())
        let docsDir = getDocumentsDirectory()
        
        // Generate GPX file
        let gpxContent = generateGPXContent(coordinates: coordinates, routeName: routeName)
        let gpxPath = docsDir.appendingPathComponent("\(routeName)_\(timestamp).gpx")
        
        do {
            try gpxContent.write(to: gpxPath, atomically: true, encoding: .utf8)
            print("GPX file exported to:")
            print("Path: \(gpxPath.path)")
        } catch {
            print("Error saving GPX file: \(error.localizedDescription)")
        }
    }
}
