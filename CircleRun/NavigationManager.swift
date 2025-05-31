import Foundation
import CoreLocation
import MapKit
import AVFoundation

// MARK: - Models
struct NavigationInstruction {
    let text: String
    let distance: String
    let maneuverType: String  // e.g. "turn.right", "turn.left", "straight"
    let streetName: String?
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
    var remainingDistance: String = "0.0 mi"
    var estimatedFinishTime: String = "--:--"
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
    @Published var camera: MKMapCamera?
    @Published var showsScale: Bool = true
    @Published var mapType: MKMapType = .standard
    
    // Private Properties
    private var locationManager = CLLocationManager()
    private var currentRoute: Route?
    private var routeSteps: [MKRoute.Step] = []
    private var startTime: Date?
    private var distanceTraveled: CLLocationDistance = 0
    private var lastLocation: CLLocation?
    private var timer: Timer?
    private var isNavigating: Bool = false
    private var estimatedTotalTime: TimeInterval = 0
    private var averagePace: TimeInterval = 0  // seconds per mile
    
    // Constants for navigation
    private let CAMERA_DISTANCE: CLLocationDistance = 500  // meters
    private let CAMERA_PITCH: CGFloat = 60  // degrees
    private let CAMERA_HEADING_OFFSET: CLLocationDirection = 5  // degrees ahead of user heading
    private let TURN_ANNOUNCEMENT_DISTANCE: Double = 100  // meters
    private let REROUTE_DISTANCE: Double = 50  // meters
    
    override init() {
        super.init()
        setupLocationManager()
    }
    
    // MARK: - Public Methods
    func startNavigation(for route: Route) {
        var backgroundTaskID: UIBackgroundTaskIdentifier = .invalid
        backgroundTaskID = UIApplication.shared.beginBackgroundTask {
            if backgroundTaskID != .invalid {
                UIApplication.shared.endBackgroundTask(backgroundTaskID)
                backgroundTaskID = .invalid
            }
        }
        
        isNavigating = true
        currentRoute = route
        routeOverlay = MKPolyline(coordinates: route.path, count: route.path.count)
        
        // Calculate estimated time based on target pace (default 10:00/mile)
        let targetPaceSeconds: TimeInterval = 600 // 10 minutes per mile
        estimatedTotalTime = targetPaceSeconds * route.distance
        
        // Initialize running stats
        runningStats.remainingDistance = String(format: "%.1f mi", route.distance)
        updateEstimatedFinishTime()
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.calculateRouteSteps(for: route)
            
            DispatchQueue.main.async {
                self?.locationManager.allowsBackgroundLocationUpdates = true
                self?.startLocationUpdates()
                self?.startTimer()
                
                if backgroundTaskID != .invalid {
                    UIApplication.shared.endBackgroundTask(backgroundTaskID)
                    backgroundTaskID = .invalid
                }
            }
        }
    }
    
    func stopNavigation() {
        // Disable background updates when stopping navigation
        locationManager.allowsBackgroundLocationUpdates = false
        stopLocationUpdates()
        stopTimer()
        resetStats()
        isNavigating = false
    }
    
    // MARK: - Private Methods
    private func setupLocationManager() {
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBestForNavigation
        locationManager.allowsBackgroundLocationUpdates = true
        locationManager.activityType = .fitness
        locationManager.showsBackgroundLocationIndicator = true
        locationManager.distanceFilter = 5
        
        if locationManager.authorizationStatus == .notDetermined {
            locationManager.requestWhenInUseAuthorization()
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
            averagePace = paceSeconds
        }
        
        // Update distance
        runningStats.distanceCovered = String(format: "%.1f mi", distanceTraveled / 1609.34)
        
        // Update remaining distance
        if let route = currentRoute {
            let remainingMiles = route.distance - (distanceTraveled / 1609.34)
            runningStats.remainingDistance = String(format: "%.1f mi", max(0, remainingMiles))
        }
        
        updateEstimatedFinishTime()
    }
    
    private func calculateRouteSteps(for route: Route) {
        guard route.path.count >= 2 else { return }
        
        // Calculate significant turns
        var significantPoints: [CLLocationCoordinate2D] = []
        
        for i in 1..<(route.path.count - 1) {
            let prev = route.path[i - 1]
            let curr = route.path[i]
            let next = route.path[i + 1]
            
            let bearing1 = calculateBearing(from: prev, to: curr)
            let bearing2 = calculateBearing(from: curr, to: next)
            let bearingDiff = abs(bearing2 - bearing1)
            
            if bearingDiff > 30 {
                significantPoints.append(curr)
            }
        }
        
        significantPoints.insert(route.path.first!, at: 0)
        significantPoints.append(route.path.last!)
        
        // Get turn instructions for significant points
        var points: [TurnPoint] = []
        for i in 0..<(significantPoints.count - 1) {
            let request = MKDirections.Request()
            request.source = MKMapItem(placemark: MKPlacemark(coordinate: significantPoints[i]))
            request.destination = MKMapItem(placemark: MKPlacemark(coordinate: significantPoints[i + 1]))
            request.transportType = .walking
            
            let semaphore = DispatchSemaphore(value: 0)
            MKDirections(request: request).calculate { [weak self] response, error in
                defer { semaphore.signal() }
                
                guard let steps = response?.routes.first?.steps else { return }
                
                for step in steps where step.instructions.contains("turn") {
                    let distance = self?.formatDistance(step.distance) ?? ""
                    let direction = step.instructions.lowercased().contains("right") ? "right" : "left"
                    points.append(TurnPoint(
                        coordinate: step.polyline.coordinate,
                        direction: direction,
                        distance: distance
                    ))
                }
            }
            semaphore.wait()
        }
        
        DispatchQueue.main.async { [weak self] in
            self?.turnPoints = points
        }
    }
    
    private func calculateBearing(from start: CLLocationCoordinate2D, to end: CLLocationCoordinate2D) -> Double {
        let lat1 = start.latitude * .pi / 180
        let lon1 = start.longitude * .pi / 180
        let lat2 = end.latitude * .pi / 180
        let lon2 = end.longitude * .pi / 180
        
        let dLon = lon2 - lon1
        let y = sin(dLon) * cos(lat2)
        let x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(dLon)
        let bearing = atan2(y, x)
        
        return (bearing * 180 / .pi + 360).truncatingRemainder(dividingBy: 360)
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
    
    private func updateEstimatedFinishTime() {
        guard let startTime = startTime else { return }
        
        let remainingDistance = (currentRoute?.distance ?? 0) - (distanceTraveled / 1609.34)
        if remainingDistance > 0 {
            // Calculate based on current pace if available, otherwise use target pace
            let timeRemaining = (averagePace > 0 ? averagePace : 600) * remainingDistance
            let estimatedFinish = Date(timeInterval: timeRemaining, since: startTime)
            
            let formatter = DateFormatter()
            formatter.dateFormat = "HH:mm"
            runningStats.estimatedFinishTime = formatter.string(from: estimatedFinish)
        }
    }
    
    private func updateCamera(for location: CLLocation) {
        guard isNavigating else { return }
        
        // Calculate position slightly ahead of user
        let bearing = location.course
        let latitude = location.coordinate.latitude
        let longitude = location.coordinate.longitude
        
        // Position camera ahead of user
        let metersAhead: Double = 50
        let earthRadius: Double = 6371000
        let bearingRadians = bearing * .pi / 180
        
        let lat1 = latitude * .pi / 180
        let lon1 = longitude * .pi / 180
        
        let lat2 = asin(sin(lat1) * cos(metersAhead/earthRadius) +
                       cos(lat1) * sin(metersAhead/earthRadius) * cos(bearingRadians))
        let lon2 = lon1 + atan2(sin(bearingRadians) * sin(metersAhead/earthRadius) * cos(lat1),
                               cos(metersAhead/earthRadius) - sin(lat1) * sin(lat2))
        
        let cameraCenter = CLLocationCoordinate2D(
            latitude: lat2 * 180 / .pi,
            longitude: lon2 * 180 / .pi
        )
        
        camera = MKMapCamera(
            lookingAtCenter: cameraCenter,
            fromDistance: CAMERA_DISTANCE,
            pitch: CAMERA_PITCH,
            heading: bearing + CAMERA_HEADING_OFFSET
        )
    }
    
    private func updateNextTurn(for location: CLLocation) {
        guard !turnPoints.isEmpty else { return }
        
        for (index, point) in turnPoints.enumerated() {
            let turnLocation = CLLocation(latitude: point.coordinate.latitude,
                                        longitude: point.coordinate.longitude)
            let distance = location.distance(from: turnLocation)
            
            if distance < TURN_ANNOUNCEMENT_DISTANCE && index > nextTurnIndex {
                nextTurnIndex = index
                
                let streetName = lookupStreetName(at: point.coordinate)
                currentInstruction = NavigationInstruction(
                    text: "Turn \(point.direction) ahead",
                    distance: String(format: "%.1f mi", distance / 1609.34),
                    maneuverType: "turn.\(point.direction)",
                    streetName: streetName
                )
                
                announceNextTurn()
                break
            }
        }
    }
    
    private func lookupStreetName(at coordinate: CLLocationCoordinate2D) -> String? {
        let semaphore = DispatchSemaphore(value: 0)
        var streetName: String?
        
        let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        CLGeocoder().reverseGeocodeLocation(location) { placemarks, error in
            defer { semaphore.signal() }
            streetName = placemarks?.first?.thoroughfare
        }
        
        semaphore.wait()
        return streetName
    }
    
    private func announceNextTurn() {
        guard let instruction = currentInstruction else { return }
        let synthesizer = AVSpeechSynthesizer()
        let utterance = AVSpeechUtterance(string: instruction.text)
        utterance.rate = 0.5
        utterance.volume = 1.0
        synthesizer.speak(utterance)
    }
}

// MARK: - CLLocationManagerDelegate
extension NavigationManager: CLLocationManagerDelegate {
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last,
              !runningStats.isPaused,
              isNavigating else { return }
        
        // Update distance traveled
        if let lastLocation = lastLocation {
            distanceTraveled += location.distance(from: lastLocation)
            
            // Update remaining distance
            if let route = currentRoute {
                let remainingMiles = route.distance - (distanceTraveled / 1609.34)
                runningStats.remainingDistance = String(format: "%.1f mi", max(0, remainingMiles))
            }
        }
        lastLocation = location
        
        // Update camera and next turn
        updateCamera(for: location)
        updateNextTurn(for: location)
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
