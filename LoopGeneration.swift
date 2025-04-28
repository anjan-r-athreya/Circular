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
    
    private func createRouteWithScale(from start: CLLocationCoordinate2D, scale: Double,
                                      numPoints: Int, targetMiles: Double, errorMargin: Double,
                                      attemptCount: Int, maxAttempts: Int, viewModel: MapViewModel, completion: @escaping () -> Void) {
        guard !isRequestInProgress else { return }
        isRequestInProgress = true
        
        print("Circular route attempt \(attemptCount): Using radius scale of \(scale) miles")
        
        // Create waypoints in a more natural circular pattern
        // Add slight randomness to make it more natural
        var waypoints: [MKMapItem] = []
        waypoints.append(MKMapItem(placemark: MKPlacemark(coordinate: start))) // Start point
        
        for i in 0..<numPoints {
            // Add slight variation to the angle to make more natural paths
            let baseAngle = 2.0 * Double.pi * Double(i) / Double(numPoints)
//            let jitter = Double.random(in: -0.1...0.1) // Small random variation
            let angle = baseAngle /*+ jitter*/
            
//            let scaleFactor = Double.random(in: 0.9...1.1) // Slight variation in distance
            let waypointEast = scale * 1609.34 * cos(angle)
            let waypointNorth = scale * 1609.34 * sin(angle) //multiply by scale factor
            let waypoint = offsetCoordinate(from: start, metersEast: waypointEast, metersNorth: waypointNorth)
            waypoints.append(MKMapItem(placemark: MKPlacemark(coordinate: waypoint)))
        }
        
        waypoints.append(MKMapItem(placemark: MKPlacemark(coordinate: start))) // Return to start
        
        // Request directions with multiple waypoints
        getRouteSegments(waypoints: waypoints, index: 0, segments: [], totalDistanceValue: 0.0) { combinedPolyline, totalDistance in
            self.isRequestInProgress = false
            
            //keep track of best attempt:
            self.bestAttemptMileage = totalDistance
            
            if let polyline = combinedPolyline {
                print("Generated circular route of \(totalDistance) miles")
                
                
                // Check if we're within acceptable range
                if abs(totalDistance - targetMiles) <= errorMargin || attemptCount >= maxAttempts {
                    // We found a suitable route or maxed out attempts
                    viewModel.routePolyline = polyline
                    viewModel.position = .region(MKCoordinateRegion(polyline.boundingMapRect))
                    viewModel.actualMiles = totalDistance
                    completion()
                    print("Final circular route: \(totalDistance) miles (target: \(targetMiles))")
                    return
                }
                
                // Calculate better scale for next attempt
                let newScale = scale * sqrt(targetMiles / totalDistance)
                
                // Add delay to avoid rate limiting
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    self.createRouteWithScale(from: start, scale: newScale, numPoints: numPoints,
                                              targetMiles: targetMiles, errorMargin: errorMargin,
                                              attemptCount: attemptCount + 1, maxAttempts: maxAttempts,
                                              viewModel: viewModel, completion: completion)
                }
            } else {
                print("Failed to generate circular route")
                // If we fail to generate a route, try with fewer waypoints
                if numPoints > 4 {
                    print("Trying with fewer waypoints...")
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        self.generateCircularRoute(from: start, targetMiles: targetMiles,
                                                   numPoints: numPoints - 1, errorMargin: errorMargin,
                                                   viewModel: viewModel, completion: completion)
                    }
                } else {
                    completion() // Call completion even if unsuccessful
                }
            }
        }
    }
    
    // Modified helper function to get route segments with delay between segments
    private func getRouteSegments(waypoints: [MKMapItem], index: Int, segments: [MKPolyline],
                                  totalDistanceValue: Double, completion: @escaping (MKPolyline?, Double) -> Void) {
        // Base case: if we've processed all waypoints, combine the segments
        if index >= waypoints.count - 1 {
            if segments.isEmpty {
                completion(nil, 0.0)
                return
            }
            
            // Combine all segments into a single polyline
            let combinedPolyline = combinePolylines(segments)
            completion(combinedPolyline, totalDistanceValue)
            return
        }
        
        // Get route from current waypoint to next waypoint
        let request = MKDirections.Request()
        request.source = waypoints[index]
        request.destination = waypoints[index + 1]
        request.transportType = .walking
        
        // Try to get most direct paths
        request.requestsAlternateRoutes = true

        MKDirections(request: request).calculate { response, error in
            if let routes = response?.routes, !routes.isEmpty {
                // Try to select the most direct route from alternatives
                let mostDirectRoute = routes.min(by: {
                    $0.distance < $1.distance
                }) ?? routes.first!
                
                // Add this segment
                var updatedSegments = segments
                updatedSegments.append(mostDirectRoute.polyline)
                
                // Calculate distance of this segment
                let segmentDistance = totalDistance(of: mostDirectRoute.polyline)
                let updatedTotalDistance = totalDistanceValue + segmentDistance
                
                // Add delay between requests to avoid rate limiting
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    // Process next segment after delay
                    self.getRouteSegments(waypoints: waypoints, index: index + 1,
                                          segments: updatedSegments, totalDistanceValue: updatedTotalDistance,
                                          completion: completion)
                }
            } else {
                print("Routing error for segment \(index): \(error?.localizedDescription ?? "Unknown error")")
                completion(nil, 0.0)
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
}
