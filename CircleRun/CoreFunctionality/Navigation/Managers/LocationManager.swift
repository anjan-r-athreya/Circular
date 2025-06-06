//
//  LocationManager.swift
//  CircleRun
//
//  Created by Anjan Athreya on 6/5/25.
//

import Foundation
import CoreLocation
import MapKit

class LocationManager: NSObject, ObservableObject {
    private var locationManager = CLLocationManager()
    private var currentRoute: Route?
    private var routeSteps: [MKRoute.Step] = []
    private var currentStepIndex = 0
    
    @Published var nextTurnIndex: Int = 0
    
    // Closure to update navigation UI
    var navigationUpdates: ((String, String, Double) -> Void)?
    
    override init() {
        super.init()
        setupLocationManager()
    }
    
    private func setupLocationManager() {
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.allowsBackgroundLocationUpdates = true
        locationManager.activityType = .fitness
        locationManager.showsBackgroundLocationIndicator = true
        locationManager.distanceFilter = 10 // Update every 10 meters
        
        // Request authorization
        locationManager.requestWhenInUseAuthorization()
    }
    
    func startNavigation(for route: Route) {
        currentRoute = route
        calculateRouteSteps(for: route)
        locationManager.startUpdatingLocation()
        locationManager.startUpdatingHeading()
    }
    
    func stopNavigation() {
        locationManager.stopUpdatingLocation()
        locationManager.stopUpdatingHeading()
        currentRoute = nil
        routeSteps.removeAll()
    }
    
    private func calculateRouteSteps(for route: Route) {
        guard route.path.count >= 2 else { return }
        
        // Create route segments and calculate directions
        for i in 0..<(route.path.count - 1) {
            let request = MKDirections.Request()
            request.source = MKMapItem(placemark: MKPlacemark(coordinate: route.path[i]))
            request.destination = MKMapItem(placemark: MKPlacemark(coordinate: route.path[i + 1]))
            request.transportType = .walking
            
            MKDirections(request: request).calculate { [weak self] response, error in
                guard let steps = response?.routes.first?.steps else { return }
                self?.routeSteps.append(contentsOf: steps)
            }
        }
    }
    
    private func updateNavigationInfo(for location: CLLocation) {
        guard let currentRoute = currentRoute,
              !routeSteps.isEmpty,
              currentStepIndex < routeSteps.count else { return }
        
        let currentStep = routeSteps[currentStepIndex]
        let stepLocation = CLLocation(latitude: currentStep.polyline.coordinate.latitude,
                                    longitude: currentStep.polyline.coordinate.longitude)
        
        // Calculate distance to next turn
        let distanceToTurn = location.distance(from: stepLocation)
        let distanceString = formatDistance(distanceToTurn)
        
        // Calculate remaining distance
        let remainingDistance = calculateRemainingDistance(from: location, route: currentRoute)
        
        // Update navigation UI
        navigationUpdates?(currentStep.instructions, distanceString, remainingDistance)
        
        // Check if we've completed the current step
        if distanceToTurn < 20 { // Within 20 meters of the turn
            currentStepIndex += 1
            nextTurnIndex = currentStepIndex
        }
    }
    
    private func calculateRemainingDistance(from location: CLLocation, route: Route) -> Double {
        var remainingDistance = 0.0
        
        // Find the closest point on the route
        var closestPointIndex = 0
        var minDistance = Double.infinity
        
        for (index, coordinate) in route.path.enumerated() {
            let pointLocation = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
            let distance = location.distance(from: pointLocation)
            if distance < minDistance {
                minDistance = distance
                closestPointIndex = index
            }
        }
        
        // Calculate remaining distance from closest point to end
        for i in closestPointIndex..<(route.path.count - 1) {
            let start = CLLocation(latitude: route.path[i].latitude, longitude: route.path[i].longitude)
            let end = CLLocation(latitude: route.path[i + 1].latitude, longitude: route.path[i + 1].longitude)
            remainingDistance += start.distance(from: end)
        }
        
        return remainingDistance / 1609.34 // Convert to miles
    }
    
    private func formatDistance(_ meters: CLLocationDistance) -> String {
        if meters < 1000 {
            return String(format: "%.0f m", meters)
        } else {
            let miles = meters / 1609.34
            return String(format: "%.1f mi", miles)
        }
    }
}

// MARK: - CLLocationManagerDelegate
extension LocationManager: CLLocationManagerDelegate {
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        updateNavigationInfo(for: location)
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Location update failed: \(error.localizedDescription)")
    }
    
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        switch manager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            manager.startUpdatingLocation()
        default:
            manager.stopUpdatingLocation()
        }
    }
}
