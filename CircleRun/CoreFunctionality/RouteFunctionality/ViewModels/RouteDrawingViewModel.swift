////
////  RouteDrawingViewModel.swift
////  CircleRun
////
////  Created by Anjan Athreya on 6/3/25.
////
//
//import SwiftUI
//import MapKit
//import CoreLocation
//
//@MainActor
//class RouteDrawingViewModel: ObservableObject {
//    @Published var drawnPoints: [CLLocationCoordinate2D] = []
//    @Published var simplifiedPoints: [CLLocationCoordinate2D] = []
//    @Published var snappedRoute: MKPolyline?
//    @Published var isDrawing = false
//    @Published var isProcessing = false
//    @Published var showingSaveSheet = false
//    @Published var routeName = ""
//    
//    private var routeSegments: [MKPolyline] = []
//    private let epsilon: Double = 0.00005 // Approximately 5 meters at the equator
//    private let routeStore: DrawnRouteStore
//    private var totalDistance: Double = 0
//    private var isProcessingRoute = false // Additional flag to prevent concurrent processing
//    
//    init(routeStore: DrawnRouteStore = DrawnRouteStore()) {
//        self.routeStore = routeStore
//    }
//    
//    func clearRoute() {
//        drawnPoints.removeAll()
//        simplifiedPoints.removeAll()
//        snappedRoute = nil
//        routeSegments.removeAll()
//        totalDistance = 0
//        routeName = ""
//        showingSaveSheet = false
//        isProcessing = false
//        isProcessingRoute = false
//    }
//    
//    func saveRoute() {
//        guard let snappedRoute = snappedRoute,
//              !routeName.isEmpty,
//              !snappedRoute.coordinates.isEmpty else { return }
//        
//        let route = DrawnRoute(
//            name: routeName,
//            coordinates: snappedRoute.coordinates,
//            distance: totalDistance
//        )
//        
//        routeStore.addRoute(route)
//        clearRoute()
//    }
//    
//    func processDrawnRoute() {
//        guard !drawnPoints.isEmpty,
//              drawnPoints.count >= 2,
//              !isProcessingRoute else { return }
//        
//        Task {
//            isProcessingRoute = true
//            isProcessing = true
//            
//            do {
//                // 1. Simplify the drawn path
//                simplifiedPoints = simplifyPath(drawnPoints, epsilon: epsilon)
//                
//                // Ensure we have enough points after simplification
//                guard simplifiedPoints.count >= 2 else {
//                    clearRoute()
//                    return
//                }
//                
//                // 2. Break into segments and calculate routes
//                await calculateSnappedRoute()
//                
//                // Show save sheet if route was successfully created
//                if snappedRoute != nil {
//                    showingSaveSheet = true
//                }
//            } catch {
//                print("Error processing route: \(error.localizedDescription)")
//                clearRoute()
//            }
//            
//            isProcessing = false
//            isProcessingRoute = false
//        }
//    }
//    
//    private func simplifyPath(_ points: [CLLocationCoordinate2D], epsilon: Double) -> [CLLocationCoordinate2D] {
//        guard points.count > 2 else { return points }
//        
//        // Validate coordinates
//        let validPoints = points.filter { CLLocationCoordinate2DIsValid($0) }
//        guard validPoints.count > 2 else { return validPoints }
//        
//        var maxDistance = 0.0
//        var index = 0
//        let end = validPoints.count - 1
//        
//        // Find the point with the maximum distance from line between start and end
//        for i in 1..<end {
//            let distance = perpendicularDistance(validPoints[i], lineStart: validPoints[0], lineEnd: validPoints[end])
//            if distance > maxDistance {
//                index = i
//                maxDistance = distance
//            }
//        }
//        
//        // If max distance is greater than epsilon, recursively simplify
//        if maxDistance > epsilon {
//            // Recursive call
//            let results1 = simplifyPath(Array(validPoints[0...index]), epsilon: epsilon)
//            let results2 = simplifyPath(Array(validPoints[index...end]), epsilon: epsilon)
//            
//            // Combine the results
//            return Array(results1.dropLast()) + results2
//        } else {
//            // Distance is less than epsilon, use straight line
//            return [validPoints[0], validPoints[end]]
//        }
//    }
//    
//    private func perpendicularDistance(_ point: CLLocationCoordinate2D, lineStart: CLLocationCoordinate2D, lineEnd: CLLocationCoordinate2D) -> Double {
//        let lat = point.latitude
//        let lon = point.longitude
//        let lat1 = lineStart.latitude
//        let lon1 = lineStart.longitude
//        let lat2 = lineEnd.latitude
//        let lon2 = lineEnd.longitude
//        
//        // Use the Haversine formula for accurate Earth distances
//        let R = 6371000.0 // Earth's radius in meters
//        
//        let φ1 = lat1 * .pi / 180
//        let φ2 = lat2 * .pi / 180
//        let λ1 = lon1 * .pi / 180
//        let λ2 = lon2 * .pi / 180
//        let φ = lat * .pi / 180
//        let λ = lon * .pi / 180
//        
//        // Calculate cross-track distance
//        let δ13 = haversineDistance(lat1: lat1, lon1: lon1, lat2: lat, lon2: lon)
//        let θ13 = bearing(lat1: lat1, lon1: lon1, lat2: lat, lon2: lon)
//        let θ12 = bearing(lat1: lat1, lon1: lon1, lat2: lat2, lon2: lon2)
//        
//        let dxt = asin(sin(δ13/R) * sin(θ13 - θ12)) * R
//        return abs(dxt)
//    }
//    
//    private func haversineDistance(lat1: Double, lon1: Double, lat2: Double, lon2: Double) -> Double {
//        let R = 6371000.0 // Earth's radius in meters
//        let φ1 = lat1 * .pi / 180
//        let φ2 = lat2 * .pi / 180
//        let Δφ = (lat2 - lat1) * .pi / 180
//        let Δλ = (lon2 - lon1) * .pi / 180
//        
//        let a = sin(Δφ/2) * sin(Δφ/2) +
//                cos(φ1) * cos(φ2) *
//                sin(Δλ/2) * sin(Δλ/2)
//        let c = 2 * atan2(sqrt(a), sqrt(1-a))
//        
//        return R * c
//    }
//    
//    private func bearing(lat1: Double, lon1: Double, lat2: Double, lon2: Double) -> Double {
//        let φ1 = lat1 * .pi / 180
//        let φ2 = lat2 * .pi / 180
//        let Δλ = (lon2 - lon1) * .pi / 180
//        
//        let y = sin(Δλ) * cos(φ2)
//        let x = cos(φ1) * sin(φ2) - sin(φ1) * cos(φ2) * cos(Δλ)
//        return atan2(y, x)
//    }
//    
//    private func calculateSnappedRoute() async {
//        guard simplifiedPoints.count >= 2 else { return }
//        
//        routeSegments.removeAll()
//        var allPoints: [CLLocationCoordinate2D] = []
//        totalDistance = 0
//        
//        // Process segments sequentially
//        for i in 0..<(simplifiedPoints.count - 1) {
//            let start = simplifiedPoints[i]
//            let end = simplifiedPoints[i + 1]
//            
//            let request = MKDirections.Request()
//            request.transportType = .walking
//            request.source = MKMapItem(placemark: MKPlacemark(coordinate: start))
//            request.destination = MKMapItem(placemark: MKPlacemark(coordinate: end))
//            
//            do {
//                let directions = MKDirections(request: request)
//                let response = try await directions.calculate()
//                
//                if let route = response.routes.first {
//                    routeSegments.append(route.polyline)
//                    totalDistance += route.distance
//                    
//                    // Extract points from the polyline
//                    var coords = route.polyline.coordinates
//                    if i > 0 {
//                        coords.removeFirst() // Remove duplicate point except for first segment
//                    }
//                    allPoints.append(contentsOf: coords)
//                }
//            } catch {
//                print("Error calculating route segment: \(error.localizedDescription)")
//            }
//            
//            // Add a small delay to avoid hitting rate limits
//            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
//        }
//        
//        // Create final polyline from all points
//        if !allPoints.isEmpty {
//            snappedRoute = MKPolyline(coordinates: allPoints, count: allPoints.count)
//        }
//    }
//}
////
////// MARK: - MKPolyline Extension
////extension MKPolyline {
////    var coordinates: [CLLocationCoordinate2D] {
////        var coords = [CLLocationCoordinate2D](repeating: kCLLocationCoordinate2DInvalid,
////                                            count: pointCount)
////        getCoordinates(&coords, range: NSRange(location: 0, length: pointCount))
////        return coords
////    }
////} 
