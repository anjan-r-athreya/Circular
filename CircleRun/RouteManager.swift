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
    
    func generateLoop(from start: CLLocationCoordinate2D, polygonSides: Int = 6, targetMiles: Double, viewModel: MapViewModel) {
        // Initial distance estimate (will be adjusted by binary search)
        let radiusEstimate = targetMiles * 0.3 // Start with radius ~30% of total desired distance
        
        // Create waypoints in a rough circle
        var waypoints: [CLLocationCoordinate2D] = []
        for i in 0..<polygonSides {
            let angle = 2.0 * Double.pi * Double(i) / Double(polygonSides)
            let waypointEast = radiusEstimate * 1609.34 * cos(angle)
            let waypointNorth = radiusEstimate * 1609.34 * sin(angle)
            let waypoint = offsetCoordinate(from: start, metersEast: waypointEast, metersNorth: waypointNorth)
            waypoints.append(waypoint)
        }
        
        // Now implement binary search to adjust the radius until the total route matches target distance
        // [Binary search implementation would go here]
    }
}
