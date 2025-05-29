//
//  NavigationManager.swift
//  CircleRun
//
//  Created by Anjan Athreya on 5/29/25.
//

import Foundation
import CoreLocation
import MapKit

// MARK: - Models
struct NavigationInstruction {
    let text: String
    let distance: String
}

struct TurnPoint {
    let coordinate: CLLocationCoordinate2D
    let direction: String
    let distance: String
}

struct RunningStats {
    var currentPace: String = "0'00\""
    var elapsedTime: String = "00:00"
    var distanceCovered: String = "0.0 mi"
    var isPaused: Bool = false
}

// MARK: - Navigation Manager
class NavigationManager: NSObject, ObservableObject {
    // Published Properties
    @Published var currentInstruction: NavigationInstruction?
    @Published var turnPoints: [TurnPoint] = []
    @Published var nextTurnIndex: Int = 0
    @Published var routeOverlay: MKPolyline?
    @Published var runningStats = RunningStats()
    
    // Private Properties
    private var locationManager = CLLocationManager()
    private var currentRoute: Route?
    private var routeSteps: [MKRoute.Step] = []
    private var startTime: Date?
    private var distanceTraveled: CLLocationDistance = 0
    private var lastLocation: CLLocation?
    private var timer: Timer?
    
    override init() {
        super.init()
        setupLocationManager()
    }
    
    // MARK: - Public Methods
    func startNavigation(for route: Route) {
        currentRoute = route
        routeOverlay = MKPolyline(coordinates: route.path, count: route.path.count)
        calculateRouteSteps(for: route)
        
        // Ensure background updates are enabled when starting navigation
        locationManager.allowsBackgroundLocationUpdates = true
        startLocationUpdates()
        startTimer()
    }
    
    func stopNavigation() {
        // Disable background updates when stopping navigation
        locationManager.allowsBackgroundLocationUpdates = false
        stopLocationUpdates()
        stopTimer()
        resetStats()
    }
    
    // MARK: - Private Methods
    private func setupLocationManager() {
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.allowsBackgroundLocationUpdates = true
        locationManager.showsBackgroundLocationIndicator = true
        locationManager.pausesLocationUpdatesAutomatically = false
        locationManager.activityType = .fitness
        locationManager.distanceFilter = 5 // Update every 5 meters
        
        // Request "Always" authorization for background updates
        if locationManager.authorizationStatus == .notDetermined {
            locationManager.requestWhenInUseAuthorization()
        } else if locationManager.authorizationStatus == .authorizedWhenInUse {
            locationManager.requestAlwaysAuthorization()
        }
    }
    
    private func startLocationUpdates() {
        locationManager.startUpdatingLocation()
        locationManager.startUpdatingHeading()
    }
    
    private func stopLocationUpdates() {
        locationManager.stopUpdatingLocation()
        locationManager.stopUpdatingHeading()
    }
    
    private func startTimer() {
        startTime = Date()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            self?.updateStats()
        }
    }
    
    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
    
    private func resetStats() {
        runningStats = RunningStats()
        distanceTraveled = 0
        startTime = nil
        lastLocation = nil
    }
    
    private func updateStats() {
        guard let startTime = startTime, !runningStats.isPaused else { return }
        
        // Update elapsed time
        let elapsed = Date().timeIntervalSince(startTime)
        runningStats.elapsedTime = formatDuration(elapsed)
        
        // Update pace
        if distanceTraveled > 0 {
            let paceSeconds = elapsed / (distanceTraveled / 1609.34) // seconds per mile
            runningStats.currentPace = formatPace(paceSeconds)
        }
        
        // Update distance
        runningStats.distanceCovered = String(format: "%.1f mi", distanceTraveled / 1609.34)
    }
    
    private func calculateRouteSteps(for route: Route) {
        guard route.path.count >= 2 else { return }
        
        var points: [TurnPoint] = []
        
        for i in 0..<(route.path.count - 1) {
            let request = MKDirections.Request()
            request.source = MKMapItem(placemark: MKPlacemark(coordinate: route.path[i]))
            request.destination = MKMapItem(placemark: MKPlacemark(coordinate: route.path[i + 1]))
            request.transportType = .walking
            
            MKDirections(request: request).calculate { [weak self] response, error in
                guard let steps = response?.routes.first?.steps else { return }
                
                // Add turn points
                for step in steps where step.instructions.contains("turn") {
                    let distance = self?.formatDistance(step.distance) ?? ""
                    let direction = step.instructions.lowercased().contains("right") ? "right" : "left"
                    points.append(TurnPoint(
                        coordinate: step.polyline.coordinate,
                        direction: direction,
                        distance: distance
                    ))
                }
                
                DispatchQueue.main.async {
                    self?.turnPoints = points
                }
            }
        }
    }
    
    private func formatDistance(_ meters: CLLocationDistance) -> String {
        if meters < 1000 {
            return String(format: "%.0f m", meters)
        } else {
            let miles = meters / 1609.34
            return String(format: "%.1f mi", miles)
        }
    }
    
    private func formatDuration(_ seconds: TimeInterval) -> String {
        let minutes = Int(seconds) / 60
        let remainingSeconds = Int(seconds) % 60
        return String(format: "%02d:%02d", minutes, remainingSeconds)
    }
    
    private func formatPace(_ secondsPerMile: Double) -> String {
        let minutes = Int(secondsPerMile) / 60
        let seconds = Int(secondsPerMile) % 60
        return String(format: "%d'%02d\"", minutes, seconds)
    }
}

// MARK: - CLLocationManagerDelegate
extension NavigationManager: CLLocationManagerDelegate {
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last,
              !runningStats.isPaused else { return }
        
        // Update distance traveled
        if let lastLocation = lastLocation {
            distanceTraveled += location.distance(from: lastLocation)
        }
        lastLocation = location
        
        // Update next turn
        updateNextTurn(for: location)
    }
    
    private func updateNextTurn(for location: CLLocation) {
        guard !turnPoints.isEmpty else { return }
        
        // Find the closest upcoming turn point
        var closestDistance = Double.infinity
        var closestIndex = 0
        
        for (index, point) in turnPoints.enumerated() {
            let turnLocation = CLLocation(
                latitude: point.coordinate.latitude,
                longitude: point.coordinate.longitude
            )
            let distance = location.distance(from: turnLocation)
            
            if distance < closestDistance {
                closestDistance = distance
                closestIndex = index
            }
        }
        
        // Update next turn if it's changed
        if closestIndex != nextTurnIndex {
            nextTurnIndex = closestIndex
            let point = turnPoints[closestIndex]
            currentInstruction = NavigationInstruction(
                text: "Turn \(point.direction) ahead",
                distance: point.distance
            )
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Location update failed: \(error.localizedDescription)")
    }
    
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        switch manager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            startLocationUpdates()
        default:
            stopLocationUpdates()
        }
    }
}
