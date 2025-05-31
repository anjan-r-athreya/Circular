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
import MapKit
import CoreLocation

class LoopGeneration {
    static let shared = LoopGeneration()
    private var isRequestInProgress = false
    private var bestAttemptMileage: Double = 0.0
    
    private init() {}
    
    // Main function to generate circular routes
    func generateCircularRoute(from start: CLLocationCoordinate2D, targetMiles: Double,
                               numPoints: Int = 8, errorMargin: Double = 0.1, viewModel: MapViewModel, completion: @escaping () -> Void) {
        // Make initial guess based on a simple heuristic
        let initialScale = (sqrt(targetMiles / (2 * Double.pi)) * 0.5) // Rough estimate for circular path
        
        createRouteWithScale(from: start, scale: initialScale, numPoints: numPoints,
                             targetMiles: targetMiles, errorMargin: errorMargin,
                             attemptCount: 1, maxAttempts: 5, viewModel: viewModel, completion: completion)
    }
    
    // Helper function to calculate actual route distance from coordinates
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
    
    // Helper function to calculate distance of MKRoute
    private func calculateRouteDistance(route: MKRoute) -> Double {
        return calculateRouteDistance(coordinates: route.polyline.coordinates)
    }
    
    // Helper function to validate segment distances
    private func validateSegmentDistances(segments: [MKPolyline], reportedTotal: Double) {
        print("\n=== Segment Distance Validation ===")
        var calculatedTotal: Double = 0
        
        for (index, segment) in segments.enumerated() {
            let segmentDistance = calculateRouteDistance(coordinates: segment.coordinates)
            calculatedTotal += segmentDistance
            print("Segment \(index + 1): \(String(format: "%.2f", segmentDistance)) miles")
        }
        
        print("Total from segments: \(String(format: "%.2f", calculatedTotal)) miles")
        print("Reported total: \(String(format: "%.2f", reportedTotal)) miles")
        print("Difference: \(String(format: "%.2f", abs(calculatedTotal - reportedTotal))) miles")
        print("================================\n")
    }
    
    // Helper function to validate route distance
    private func validateRouteDistance(polyline: MKPolyline, reportedDistance: Double) {
        let coordinates = polyline.coordinates
        let calculatedDistance = calculateRouteDistance(coordinates: coordinates)
        
        print("\n=== Route Distance Validation ===")
        print("Reported distance: \(String(format: "%.2f", reportedDistance)) miles")
        print("Calculated distance: \(String(format: "%.2f", calculatedDistance)) miles")
        print("Difference: \(String(format: "%.2f", abs(reportedDistance - calculatedDistance))) miles")
        print("==============================\n")
        
        // If there's a significant discrepancy, log it
        if abs(reportedDistance - calculatedDistance) > 0.1 {
            print("⚠️ WARNING: Significant distance discrepancy detected!")
        }
        
        // Update the actual distance to use the calculated value
        bestAttemptMileage = calculatedDistance
    }

    // Modified getRouteSegments to properly calculate segment distances
    private func getRouteSegments(waypoints: [MKMapItem], index: Int, segments: [MKPolyline],
                                  totalDistanceValue: Double, attemptCount: Int, maxAttempts: Int,
                                  completion: @escaping (MKPolyline?, Double) -> Void) {
        if index >= waypoints.count - 1 {
            if segments.isEmpty {
                completion(nil, 0.0)
                return
            }
            
            let combinedPolyline = combinePolylines(segments)
            let actualDistance = calculateRouteDistance(coordinates: combinedPolyline.coordinates)
            
            // Validate individual segments and total distance
            validateSegmentDistances(segments: segments, reportedTotal: totalDistanceValue)
            
            print("\n=== Final Route Details ===")
            print("Number of segments: \(segments.count)")
            print("Total coordinates: \(combinedPolyline.coordinates.count)")
            print("Distance from combined polyline: \(String(format: "%.2f", actualDistance)) miles")
            print("Distance from segment sum: \(String(format: "%.2f", totalDistanceValue)) miles")
            print("==========================\n")
            
            completion(combinedPolyline, actualDistance)
            return
        }

        let request = MKDirections.Request()
        request.source = waypoints[index]
        request.destination = waypoints[index + 1]
        request.transportType = .walking
        request.requestsAlternateRoutes = true

        MKDirections(request: request).calculate { [weak self] response, error in
            guard let self = self else { return }
            
            if let routes = response?.routes, !routes.isEmpty {
                // Select the most direct route and validate its distance
                let mostDirectRoute = routes.min(by: { $0.distance < $1.distance }) ?? routes.first!
                let reportedDistance = mostDirectRoute.distance / 1609.34 // Convert to miles
                let calculatedDistance = self.calculateRouteDistance(route: mostDirectRoute)
                
                print("\nSegment \(index + 1) Distance Comparison:")
                print("MapKit reported: \(String(format: "%.2f", reportedDistance)) miles")
                print("Actually calculated: \(String(format: "%.2f", calculatedDistance)) miles")
                
                var updatedSegments = segments
                updatedSegments.append(mostDirectRoute.polyline)
                
                let updatedTotalDistance = totalDistanceValue + calculatedDistance
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    self.getRouteSegments(waypoints: waypoints, index: index + 1,
                                          segments: updatedSegments,
                                          totalDistanceValue: updatedTotalDistance,
                                          attemptCount: attemptCount,
                                          maxAttempts: maxAttempts,
                                          completion: completion)
                }
            } else {
                print("Routing error for segment \(index): \(error?.localizedDescription ?? "Unknown error")")
                completion(nil, 0.0)
            }
        }
    }
    
    private func createRouteWithScale(from start: CLLocationCoordinate2D, scale: Double,
                                      numPoints: Int, targetMiles: Double, errorMargin: Double,
                                      attemptCount: Int, maxAttempts: Int, viewModel: MapViewModel, completion: @escaping () -> Void) {
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
        
        // Create waypoints with more precise spacing
        var waypoints: [MKMapItem] = []
        waypoints.append(MKMapItem(placemark: MKPlacemark(coordinate: start)))
        
        // Calculate angular spacing for even distribution
        let angleIncrement = 2.0 * Double.pi / Double(numPoints)
        
        for i in 0..<numPoints {
            let angle = angleIncrement * Double(i)
            let waypointEast = radiusInMeters * cos(angle)
            let waypointNorth = radiusInMeters * sin(angle)
            let waypoint = offsetCoordinate(from: start, metersEast: waypointEast, metersNorth: waypointNorth)
            waypoints.append(MKMapItem(placemark: MKPlacemark(coordinate: waypoint)))
        }
        
        waypoints.append(MKMapItem(placemark: MKPlacemark(coordinate: start)))
        
        // Calculate straight-line distances between waypoints for reference
        print("\nWaypoint Spacing Validation:")
        for i in 0..<waypoints.count - 1 {
            let coord1 = waypoints[i].placemark.coordinate
            let coord2 = waypoints[i + 1].placemark.coordinate
            let distance = calculateRouteDistance(coordinates: [coord1, coord2])
            print("Waypoint \(i) to \(i + 1): \(String(format: "%.2f", distance)) miles")
        }
        
        getRouteSegments(waypoints: waypoints, index: 0, segments: [], totalDistanceValue: 0.0, attemptCount: attemptCount, maxAttempts: maxAttempts) { [weak self] combinedPolyline, totalDistance in
            guard let self = self else { return }
            self.isRequestInProgress = false
            
            if let polyline = combinedPolyline {
                let actualDistance = self.calculateRouteDistance(coordinates: polyline.coordinates)
                
                let isAcceptableRoute = abs(actualDistance - targetMiles) <= errorMargin
                let isFinalAttempt = attemptCount >= maxAttempts
                
                if isAcceptableRoute || isFinalAttempt {
                    viewModel.routePolyline = polyline
                    viewModel.position = .region(MKCoordinateRegion(polyline.boundingMapRect))
                    viewModel.actualMiles = actualDistance
                    
                    // Export GPX file for the final route
                    self.exportGPXFile(coordinates: polyline.coordinates, distance: actualDistance)
                    
                    print("\nFinal Route Summary (Attempt \(attemptCount)):")
                    print("Target distance: \(String(format: "%.2f", targetMiles)) miles")
                    print("Actual distance: \(String(format: "%.2f", actualDistance)) miles")
                    print("Difference from target: \(String(format: "%.2f", abs(actualDistance - targetMiles))) miles")
                    print("Status: \(isAcceptableRoute ? "Within acceptable error margin" : "Max attempts reached")")
                    print("Number of coordinates: \(polyline.coordinates.count)")
                    
                    completion()
                    return
                }
                
                // Adjust scale based on actual distance
                let newScale = scale * sqrt(targetMiles / actualDistance)
                print("\nAdjusting scale:")
                print("Current: \(String(format: "%.2f", scale)) miles")
                print("New: \(String(format: "%.2f", newScale)) miles")
                print("Adjustment factor: \(String(format: "%.2f", sqrt(targetMiles / actualDistance)))")
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    self.createRouteWithScale(from: start, scale: newScale, numPoints: numPoints,
                                              targetMiles: targetMiles, errorMargin: errorMargin,
                                              attemptCount: attemptCount + 1, maxAttempts: maxAttempts,
                                              viewModel: viewModel, completion: completion)
                }
            } else {
                print("Failed to generate route")
                if numPoints > 4 {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        self.generateCircularRoute(from: start, targetMiles: targetMiles,
                                                   numPoints: numPoints - 1, errorMargin: errorMargin,
                                                   viewModel: viewModel, completion: completion)
                    }
                } else {
                    completion()
                }
            }
        }
    }
    
    // Helper function to combine multiple polylines into one
    private func combinePolylines(_ polylines: [MKPolyline]) -> MKPolyline {
        var allCoordinates: [CLLocationCoordinate2D] = []
        
        for polyline in polylines {
            let coords = polyline.coordinates
            
            // Skip the first point of each segment except the first to avoid duplicates
            if !allCoordinates.isEmpty && !coords.isEmpty {
                allCoordinates.append(contentsOf: coords.dropFirst())
            } else {
                allCoordinates.append(contentsOf: coords)
            }
        }
        
        return MKPolyline(coordinates: allCoordinates, count: allCoordinates.count)
    }
    
    // Helper function to get documents directory
    private func getDocumentsDirectory() -> URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
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
