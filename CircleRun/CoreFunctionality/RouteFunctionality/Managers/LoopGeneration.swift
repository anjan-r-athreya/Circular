//
//  LoopGeneration.swift
//  CircleRun
//
//  Created by Anjan Athreya on 4/11/25.
//
//  Current issue: tipping scale problem where one side is number of attempts and the other side is the accuracy of the algorithm
//  If I can optimize the searching equation and function then I can make fewer attempts thus reducing my api calls
//  With that extra room I can generate more waypoints for a smoother loop.
//  Create constraint of only 2 edges per waypoint, not just per waypoint but 2 edges per every point on the loop.

import Foundation
import SwiftUI
import MapboxDirections
import CoreLocation
import MapKit

/// Generates circular routes using MapboxDirections and saves to your Route model.
class LoopGeneration {
    static let shared = LoopGeneration()
    private var isRequestInProgress = false
    private var bestAttemptMileage: Double = 0.0
    private var targetDistance: Double = 0.0

    private init() {}

    func generateCircularRoute(
        from start: CLLocationCoordinate2D,
        targetMiles: Double,
        numPoints: Int = 12,
        errorMargin: Double = 0.01, // Reduced error margin to 1% of target distance
        retryDelay: TimeInterval = 2.0,
        viewModel: MapViewModel,
        completion: @escaping () -> Void
    ) {
        let initialScale = min(calculateOptimalInitialScale(targetMiles: targetMiles), 2.0)
        self.targetDistance = targetMiles

        Task {
            await createRouteWithScale(
                from: start,
                initialScale: initialScale,
                numPoints: numPoints,
                targetMiles: targetMiles,
                errorMargin: errorMargin,
                maxAttempts: 5,
                retryDelay: retryDelay,
                viewModel: viewModel,
                completion: completion
            )
        }
    }

    private func calculateOptimalInitialScale(targetMiles: Double) -> Double {
        let baseScale = sqrt(targetMiles / (2 * Double.pi))
        let adjustmentFactor = 1.0 + (targetMiles / 5.0)
        return baseScale * adjustmentFactor
    }

    private func calculateRouteDistance(coordinates: [CLLocationCoordinate2D]) -> Double {
        var totalDistance: CLLocationDistance = 0
        guard coordinates.count > 1 else { return 0 }
        
        for i in 0..<(coordinates.count - 1) {
            let loc1 = CLLocation(latitude: coordinates[i].latitude, longitude: coordinates[i].longitude)
            let loc2 = CLLocation(latitude: coordinates[i + 1].latitude, longitude: coordinates[i + 1].longitude)
            totalDistance += loc1.distance(from: loc2)
        }
        return totalDistance / 1609.34 // meters to miles
    }

    private func calculateEdgeConstraints(coordinates: [CLLocationCoordinate2D]) -> Bool {
        guard coordinates.count > 2 else { return false }
        for i in 0..<coordinates.count {
            var edgeCount = 0
            if i > 0 {
                let prevDist = calculateRouteDistance(coordinates: [coordinates[i-1], coordinates[i]])
                if prevDist > 0.01 {
                    edgeCount += 1
                }
            }
            if i < coordinates.count - 1 {
                let nextDist = calculateRouteDistance(coordinates: [coordinates[i], coordinates[i+1]])
                if nextDist > 0.01 {
                    edgeCount += 1
                }
            }
            if i == 0 || i == coordinates.count - 1 {
                edgeCount += 1
            }
            if edgeCount != 2 {
                return false
            }
        }
        return true
    }

    private func smoothRoute(
        coordinates: [CLLocationCoordinate2D],
        smoothingFactor: Double = 0.3
    ) -> [CLLocationCoordinate2D] {
        guard coordinates.count > 2 else { return coordinates }
        var smoothed: [CLLocationCoordinate2D] = []
        for i in 0..<coordinates.count {
            let prev = coordinates[max(0, i-1)]
            let current = coordinates[i]
            let next = coordinates[min(coordinates.count-1, i+1)]
            let lat = (1 - smoothingFactor) * current.latitude +
                (smoothingFactor/2) * (prev.latitude + next.latitude)
            let lon = (1 - smoothingFactor) * current.longitude +
                (smoothingFactor/2) * (prev.longitude + next.longitude)
            smoothed.append(CLLocationCoordinate2D(latitude: lat, longitude: lon))
        }
        return smoothed
    }

    private func validateRouteQuality(route: MapboxDirections.Route) -> Bool {
        guard let coordinates = route.legs.first?.shape.coordinates else { return false }
        if !calculateEdgeConstraints(coordinates: coordinates) {
            return false
        }
        for i in 0..<coordinates.count - 1 {
            let distance = calculateRouteDistance(coordinates: [coordinates[i], coordinates[i + 1]])
            if distance > 1.0 {
                return false
            }
        }
        let actualDistance = route.distance / 1609.34
        if abs(actualDistance - targetDistance) > targetDistance * 0.01 { // Reduced error margin from 10% to 1%
            return false
        }
        return true
    }

    private func offsetCoordinate(
        from coordinate: CLLocationCoordinate2D,
        metersEast: Double,
        metersNorth: Double
    ) -> CLLocationCoordinate2D {
        let earthRadius = 6378137.0
        let lat = coordinate.latitude
        let lon = coordinate.longitude
        let newLat = lat + (metersNorth / earthRadius) * (180.0 / Double.pi)
        let newLon = lon + (metersEast / (earthRadius * cos(Double.pi * lat / 180.0))) * (180.0 / Double.pi)
        return CLLocationCoordinate2D(latitude: newLat, longitude: newLon)
    }

    private func createRouteWithScale(
        from start: CLLocationCoordinate2D,
        initialScale: Double,
        numPoints: Int,
        targetMiles: Double,
        errorMargin: Double,
        maxAttempts: Int = 10, // Increased max attempts from 5 to 10
        retryDelay: TimeInterval,
        viewModel: MapViewModel,
        completion: @escaping () -> Void
    ) async {
        guard !isRequestInProgress else { return }
        isRequestInProgress = true

        var currentScale = initialScale
        var currentNumPoints = numPoints
        var attemptCount = 1
        var bestRoute: (route: MapboxDirections.Route, distance: Double)? = nil
        var previousDistance: Double? = nil
        var bestPolyline: MKPolyline?
        var allAttempts: [(attempt: Int, distance: Double)] = []

        while attemptCount <= maxAttempts {
            print("\n=== Attempt \(attemptCount) of \(maxAttempts) ===")
            print("Target distance: \(String(format: "%.2f", targetMiles)) miles")
            print("Current scale: \(String(format: "%.2f", currentScale))")
            print("Number of points: \(currentNumPoints)")
            print("Current error margin: \(String(format: "%.2f%%", errorMargin * 100))")

            let radiusInMeters = currentScale * 1609.34
            let estimatedCircumference = 2 * Double.pi * radiusInMeters / 1609.34
            print("Radius: \(String(format: "%.2f", currentScale)) miles")
            print("Estimated circumference: \(String(format: "%.2f", estimatedCircumference)) miles")

            var waypoints: [Waypoint] = [
                Waypoint(coordinate: start, coordinateAccuracy: 5.0, name: "Start")
            ]

            let angleIncrement = 2.0 * Double.pi / Double(currentNumPoints)
            for i in 0..<currentNumPoints {
                let angle = angleIncrement * Double(i)
                let waypointEast = radiusInMeters * cos(angle)
                let waypointNorth = radiusInMeters * sin(angle)
                let waypointCoord = offsetCoordinate(from: start, metersEast: waypointEast, metersNorth: waypointNorth)
                let waypoint = Waypoint(coordinate: waypointCoord, coordinateAccuracy: 5.0, name: "Point \(i + 1)")
                waypoints.append(waypoint)
            }

            let finalWaypoint = Waypoint(coordinate: start, coordinateAccuracy: 5.0, name: "Start")
            waypoints.append(finalWaypoint)

            print("\nWaypoint Spacing Validation:")
            for i in 0..<waypoints.count - 1 {
                let coord1 = waypoints[i].coordinate
                let coord2 = waypoints[i + 1].coordinate
                let distance = calculateRouteDistance(coordinates: [coord1, coord2])
                print("Waypoint \(i) to \(i + 1): \(String(format: "%.2f", distance)) miles")
            }

            let options = RouteOptions(waypoints: waypoints, profileIdentifier: .automobile)
            options.includesSteps = true
            options.routeShapeResolution = .full
            options.attributeOptions = [.distance, .expectedTravelTime]
            // Only .ferry is valid for Mapbox Directions; .motorway will cause errors
            options.roadClassesToAvoid = [.ferry]

            do {
                let response = try await withCheckedThrowingContinuation { continuation in
                    Directions.shared.calculate(options) { (_, result) in
                        switch result {
                        case .success(let response):
                            continuation.resume(returning: response)
                        case .failure(let error):
                            continuation.resume(throwing: error)
                        }
                    }
                }

                isRequestInProgress = false

                guard let route = response.routes?.first else {
                    print("No routes returned")
                    if currentNumPoints > 4 && attemptCount < maxAttempts {
                        currentNumPoints -= 1
                        attemptCount += 1
                        try? await Task.sleep(nanoseconds: UInt64(retryDelay * 1_000_000_000))
                        continue
                    } else {
                        print("Failed to generate route after \(attemptCount) attempts")
                        completion()
                        return
                    }
                }

                if !validateRouteQuality(route: route) {
                    print("Route failed quality check")
                    if currentNumPoints > 4 && attemptCount < maxAttempts {
                        currentNumPoints -= 1
                        attemptCount += 1
                        try? await Task.sleep(nanoseconds: UInt64(retryDelay * 1_000_000_000))
                        continue
                    } else {
                        print("Failed quality check after \(attemptCount) attempts")
                        completion()
                        return
                    }
                }

                let actualDistance = route.distance / 1609.34
                self.bestAttemptMileage = actualDistance

                let smoothedCoordinates = smoothRoute(
                    coordinates: route.legs.first?.shape.coordinates ?? [],
                    smoothingFactor: 0.3
                )
                // Convert Mapbox route shape to MKPolyline
                guard let coordinates = route.legs.first?.shape.coordinates else {
                    print("Failed to get route coordinates")
                    completion()
                    return
                }
                let polyline = MKPolyline(coordinates: coordinates, count: coordinates.count)

                if let route = response.routes?.first {
                    let actualDistance = calculateRouteDistance(coordinates: coordinates)
                    print("Generated route of \(actualDistance) miles")
                    
                    // Track all attempts
                    allAttempts.append((attempt: attemptCount, distance: actualDistance))
                    
                    // Track the best route so far
                    if bestRoute == nil || abs(actualDistance - targetMiles) < abs(bestRoute!.distance - targetMiles) {
                        bestRoute = (route, actualDistance)
                        // Create polyline for the best route
                        bestPolyline = MKPolyline(coordinates: coordinates, count: coordinates.count)
                    }

                    // Check for convergence
                    if let prev = previousDistance,
                       abs(actualDistance - prev) < errorMargin * 0.01 { // If we're converging very slowly
                        print("Convergence detected after \(attemptCount) attempts")
                        if let best = bestRoute, let bestPoly = bestPolyline {
                            viewModel.routePolyline = bestPoly
                            viewModel.position = .region(MKCoordinateRegion(bestPoly.boundingMapRect))
                            viewModel.actualMiles = best.distance
                            
                            print("\nFinal Route Summary (Converged after \(attemptCount) attempts)")
                            print("Target distance: \(String(format: "%.2f", targetMiles)) miles")
                            print("Actual distance: \(String(format: "%.2f", best.distance)) miles")
                            print("Difference from target: \(String(format: "%.2f", abs(best.distance - targetMiles))) miles")
                            print("Number of coordinates: \(coordinates.count)")
                            
                            completion()
                            return
                        }
                    }
                    
                    previousDistance = actualDistance
                    
                    // Check if we're within acceptable range
                    if abs(actualDistance - targetMiles) <= errorMargin {
                        // Only update if this is the best route so far
                        if bestRoute == nil || abs(actualDistance - targetMiles) < abs(bestRoute!.distance - targetMiles) {
                            bestRoute = (route, actualDistance)
                            bestPolyline = MKPolyline(coordinates: coordinates, count: coordinates.count)
                        }

                        print("\nFinal Route Summary (Within error margin after \(attemptCount) attempts)")
                        print("Target distance: \(String(format: "%.2f", targetMiles)) miles")
                        print("Actual distance: \(String(format: "%.2f", actualDistance)) miles")
                        print("Difference from target: \(String(format: "%.2f", abs(actualDistance - targetMiles))) miles")
                        print("Number of coordinates: \(coordinates.count)")
                        
                        completion()
                        return
                    }
                }

                attemptCount += 1
                try? await Task.sleep(nanoseconds: UInt64(retryDelay * 1_000_000_000))
            } catch {
                print("Routing error: \(error.localizedDescription)")
                isRequestInProgress = false
                if currentNumPoints > 4 && attemptCount < maxAttempts {
                    currentNumPoints -= 1
                    attemptCount += 1
                    try? await Task.sleep(nanoseconds: UInt64(retryDelay * 1_000_000_000))
                    continue
                } else {
                    // Print summary of all attempts
                    print("\nRoute Generation Summary:")
                    print("Target distance: \(String(format: "%.2f", targetMiles)) miles")
                    print("Attempts:")
                    for attempt in allAttempts {
                        print("Attempt \(attempt.attempt): \(String(format: "%.2f", attempt.distance)) miles")
                    }
                    
                    // If we've exhausted all attempts, use the best route we found
                    if let best = bestRoute, let bestPoly = bestPolyline {
                        viewModel.routePolyline = bestPoly
                        viewModel.position = .region(MKCoordinateRegion(bestPoly.boundingMapRect))
                        viewModel.actualMiles = best.distance
                    }
                    
                    completion()
                    return
                }
            }
        }

        // Print summary of all attempts
        print("\nRoute Generation Summary:")
        print("Target distance: \(String(format: "%.2f", targetMiles)) miles")
        print("Attempts:")
        for attempt in allAttempts {
            print("Attempt \(attempt.attempt): \(String(format: "%.2f", attempt.distance)) miles")
        }
        
        // If we've exhausted all attempts, use the best route we found
        if let best = bestRoute, let bestPoly = bestPolyline {
            viewModel.routePolyline = bestPoly
            viewModel.position = .region(MKCoordinateRegion(bestPoly.boundingMapRect))
            viewModel.actualMiles = best.distance
        }

        isRequestInProgress = false
        completion()
    }

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

    private func getDocumentsDirectory() -> URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }

    private func exportGPXFile(coordinates: [CLLocationCoordinate2D], distance: Double) {
        let routeName = "CircleRoute_\(String(format: "%.1f", distance))mi"
        let timestamp = ISO8601DateFormatter().string(from: Date())
        let docsDir = getDocumentsDirectory()
        let gpxContent = generateGPXContent(coordinates: coordinates, routeName: routeName)
        let gpxPath = docsDir.appendingPathComponent("\(routeName)_\(timestamp).gpx")
        do {
            try gpxContent.write(to: gpxPath, atomically: true, encoding: .utf8)
            print("GPX file exported to: \(gpxPath.path)")
        } catch {
            print("Error saving GPX file: \(error.localizedDescription)")
        }
    }
}
