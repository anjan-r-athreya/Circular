//
//  MapboxViewModel.swift
//  CircleRun
//
//  Created by Anjan Athreya on 6/5/25.
//

import Foundation
import MapboxMaps
import MapboxDirections
import CoreLocation
import UIKit

class MapboxViewModel: ObservableObject {
    @Published var is3DEnabled: Bool = false
    @Published var isTrackingLocation: Bool = false
    @Published var isGeneratingRoute: Bool = false
    @Published var routeCoordinates: [CLLocationCoordinate2D] = []
    @Published var routeDistance: Double = 0.0
    @Published var errorMessage: String?
    @Published var isFavorited: Bool = false
    
    @Published var scenicSpots: [ScenicSpot] = []
    @Published var selectedSpotIDs: Set<String> = []
    @Published var isLoadingSpots = false
    @Published var showingSuggestions = false

    weak var mapViewController: MapboxViewController?
    private var currentLocation: CLLocation?
    private var routeAnnotation: PolylineAnnotation?
    private var spotAnnotationManager: PointAnnotationManager?
    @Published private(set) var lastTargetMiles: Double?

    // MARK: - Route Generation

    func generateLoop(targetMiles: Double) {
        guard let location = mapViewController?.mapView.location.latestLocation?.coordinate else {
            errorMessage = "Current location not available"
            return
        }

        lastTargetMiles = targetMiles

        // Clear all existing route data first
        routeCoordinates = []
        routeDistance = 0.0
        isFavorited = false // Reset favorite state
        clearRouteLayers()

        isGeneratingRoute = true
        errorMessage = nil

        let includedSpots = scenicSpots.filter { selectedSpotIDs.contains($0.id) }

        MapboxLoopGenerator.shared.generateCircularRoute(
            from: location,
            targetMiles: targetMiles,
            preferences: .fromUserDefaults(),
            viaSpots: includedSpots.map { $0.coordinate }
        ) { [weak self] result in
            guard let self = self else { return }
            self.isGeneratingRoute = false

            switch result {
            case .failure(let error):
                var message = error.localizedDescription
                if case LoopGenerationError.distanceNotAchievable = error, !includedSpots.isEmpty {
                    message += " Removing a scenic stop may also help."
                }
                self.errorMessage = message

            case .success(let loop):
                self.routeCoordinates = loop.coordinates
                self.routeDistance = loop.distanceMiles
                self.displayRoute(coordinates: loop.coordinates)
                self.displaySpotMarkers(for: includedSpots)

                if let bounds = self.calculateBounds(from: loop.coordinates) {
                    self.centerMap(on: bounds)
                }
            }
        }
    }

    /// Generates a fresh loop of the same distance in a new direction.
    func regenerateLoop() {
        guard let miles = lastTargetMiles else { return }
        generateLoop(targetMiles: miles)
    }

    // MARK: - Scenic Spots

    /// Step one of generation: look for scenic spots near the runner and, if
    /// any are found, show them as suggestion cards before building the route.
    /// Falls straight through to generation when nothing interesting is nearby.
    func beginGenerationFlow(targetMiles: Double) {
        guard let location = mapViewController?.mapView.location.latestLocation?.coordinate else {
            errorMessage = "Current location not available"
            return
        }

        lastTargetMiles = targetMiles
        selectedSpotIDs = []
        isLoadingSpots = true

        Task {
            let spots = await ScenicSpotService.shared.findSpots(near: location, targetMiles: targetMiles)
            await MainActor.run {
                self.isLoadingSpots = false
                self.scenicSpots = spots
                if spots.isEmpty {
                    self.generateLoop(targetMiles: targetMiles)
                } else {
                    self.showingSuggestions = true
                }
            }
        }
    }

    /// Shortest plausible loop, in miles, that visits every selected spot:
    /// the straight-line ring through them (in the same angular order the
    /// generator uses) inflated for street winding. Lets the UI warn and
    /// auto-extend BEFORE generation instead of erroring after it.
    func minimumMilesForSelection() -> Double? {
        guard let start = mapViewController?.mapView.location.latestLocation?.coordinate else {
            return nil
        }
        let coords = scenicSpots.filter { selectedSpotIDs.contains($0.id) }.map { $0.coordinate }
        guard !coords.isEmpty else { return nil }

        let all = [start] + coords
        let centroid = CLLocationCoordinate2D(
            latitude: all.map(\.latitude).reduce(0, +) / Double(all.count),
            longitude: all.map(\.longitude).reduce(0, +) / Double(all.count)
        )
        func angle(_ c: CLLocationCoordinate2D) -> Double {
            let east = (c.longitude - centroid.longitude) * cos(centroid.latitude * .pi / 180)
            let north = c.latitude - centroid.latitude
            return atan2(east, north)
        }
        let startAngle = angle(start)
        func travel(_ a: Double) -> Double {
            (a - startAngle + 4 * .pi).truncatingRemainder(dividingBy: 2 * .pi)
        }

        let ring = [start] + coords.sorted { travel(angle($0)) < travel(angle($1)) } + [start]
        var meters = 0.0
        for i in 0..<(ring.count - 1) {
            meters += CLLocation(latitude: ring[i].latitude, longitude: ring[i].longitude)
                .distance(from: CLLocation(latitude: ring[i + 1].latitude, longitude: ring[i + 1].longitude))
        }
        // Streets never run straight between points; 1.3 matches what routed
        // spot loops actually come out to versus their ring distance.
        return meters * 1.3 / 1609.34
    }

    /// The distance the route will actually be generated at: the chosen
    /// distance, or the selection's minimum when the spots don't fit in it.
    var effectiveTargetMiles: Double? {
        guard let target = lastTargetMiles else { return nil }
        if let minimum = minimumMilesForSelection(), minimum > target {
            return (minimum * 2).rounded(.up) / 2
        }
        return target
    }

    /// Builds the loop through whichever suggestion cards are selected,
    /// extending the target distance if the selection needs more room.
    func confirmSuggestions() {
        showingSuggestions = false
        guard let miles = effectiveTargetMiles else { return }
        generateLoop(targetMiles: miles)
    }

    /// Builds a plain loop with no scenic stops.
    func skipSuggestions() {
        selectedSpotIDs = []
        confirmSuggestions()
    }

    func toggleSpot(_ spot: ScenicSpot) {
        if selectedSpotIDs.contains(spot.id) {
            selectedSpotIDs.remove(spot.id)
        } else {
            selectedSpotIDs.insert(spot.id)
        }
    }
    
    // MARK: - Favorites Management
    
    func loadFavoriteRoute(_ route: Route) {
        // Clear existing route
        routeCoordinates = []
        routeDistance = 0.0
        clearRouteLayers()
        
        // Load the route
        routeCoordinates = route.path
        routeDistance = route.distance
        displayRoute(coordinates: route.path)
        isFavorited = true
        
        // Center map on route
        if let bounds = calculateBounds(from: route.path) {
            centerMap(on: bounds)
        }
    }
    
    func toggleFavorite() {
        if isFavorited {
            removeFromFavorites()
        } else {
            saveAsFavorite()
        }
        isFavorited.toggle()
        
        // Provide haptic feedback
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
    }
    
    private func saveAsFavorite() {
        guard !routeCoordinates.isEmpty else { return }
        
        let routeName = "Route \(String(format: "%.2f", routeDistance)) miles"
        RouteManager.shared.saveAsFavorite(
            name: routeName,
            coordinates: routeCoordinates,
            runTime: 0
        )
    }
    
    private func removeFromFavorites() {
        guard !routeCoordinates.isEmpty else { return }
        
        let routeName = "Route \(String(format: "%.2f", routeDistance)) miles"
        RouteManager.shared.removeFromFavorites(
            name: routeName,
            coordinates: routeCoordinates
        )
    }
    
    // MARK: - Map Interaction
    
    func centerOnUser() {
        guard let mapView = mapViewController?.mapView else { return }
        isTrackingLocation.toggle()
        
        if isTrackingLocation {
            if let location = mapView.location.latestLocation?.coordinate {
                let camera = CameraOptions(
                    center: location,
                    zoom: 15,
                    bearing: 0,
                    pitch: is3DEnabled ? 45 : 0
                )
                mapView.camera.fly(to: camera, duration: 0.5)
            }
            
            // Enable continuous tracking
            mapView.location.options.puckBearingEnabled = true
        } else {
            // Disable continuous tracking
            mapView.location.options.puckBearingEnabled = false
        }
    }
    
    func resetBearing() {
        guard let mapView = mapViewController?.mapView else { return }
        let camera = CameraOptions(bearing: 0)
        mapView.camera.fly(to: camera, duration: 0.5)
    }
    
    func toggle3D() {
        guard let mapView = mapViewController?.mapView else { return }
        is3DEnabled.toggle()
        let camera = CameraOptions(pitch: is3DEnabled ? 45 : 0)
        mapView.camera.fly(to: camera, duration: 0.5)
    }
    
    // MARK: - Route Display
    
    private func displayRoute(coordinates: [CLLocationCoordinate2D]) {
        guard let mapView = mapViewController?.mapView else { return }
        
        // Remove existing route if any
        if let _ = routeAnnotation {
            try? mapView.mapboxMap.style.removeLayer(withId: "route-layer")
            try? mapView.mapboxMap.style.removeSource(withId: "route-source")
        }
        
        // Create a linestring from the coordinates
        let lineString = LineString(coordinates)
        
        // Create a feature for the route
        var feature = Feature(geometry: .lineString(lineString))
        feature.properties = [
            "stroke": .string("#007AFF"),
            "stroke-width": .number(4),
            "stroke-opacity": .number(0.8)
        ]
        
        // Create and add the source
        var source = GeoJSONSource()
        source.data = .feature(feature)
        try? mapView.mapboxMap.style.addSource(source, id: "route-source")
        
        // Create and add the layer
        var layer = LineLayer(id: "route-layer")
        layer.source = "route-source"
        layer.lineColor = .constant(.init(UIColor.systemBlue))
        layer.lineWidth = .constant(4)
        layer.lineCap = .constant(.round)
        layer.lineJoin = .constant(.round)
        
        try? mapView.mapboxMap.style.addLayer(layer)
    }

    /// Pins each scenic spot on the route with its photo — a circular
    /// photo thumbnail whose pointer touches the spot's location.
    private func displaySpotMarkers(for spots: [ScenicSpot]) {
        guard let mapView = mapViewController?.mapView else { return }
        spotAnnotationManager?.annotations = []
        guard !spots.isEmpty else { return }

        let manager = spotAnnotationManager
            ?? mapView.annotations.makePointAnnotationManager(id: "spot-photo-markers")
        spotAnnotationManager = manager

        Task { [weak self] in
            var annotations: [PointAnnotation] = []
            for spot in spots {
                // Photos were already fetched for the suggestion cards, so
                // these come straight from the cache.
                let photo = await SpotPhotoService.shared.photo(
                    for: spot,
                    size: CGSize(width: 200, height: 200)
                )
                var annotation = PointAnnotation(coordinate: spot.coordinate)
                annotation.image = .init(image: Self.makeMarkerImage(photo: photo),
                                         name: "spot-marker-\(spot.id)")
                annotation.iconAnchor = .bottom
                annotations.append(annotation)
            }
            await MainActor.run {
                self?.spotAnnotationManager?.annotations = annotations
            }
        }
    }

    /// Composes a map pin: circular photo in a white ring with a pointer
    /// triangle whose tip sits on the annotated coordinate.
    private static func makeMarkerImage(photo: UIImage?) -> UIImage {
        let diameter: CGFloat = 54
        let pointerHeight: CGFloat = 10
        let size = CGSize(width: diameter, height: diameter + pointerHeight)

        return UIGraphicsImageRenderer(size: size).image { context in
            let pointer = UIBezierPath()
            pointer.move(to: CGPoint(x: diameter / 2 - 7, y: diameter - 2))
            pointer.addLine(to: CGPoint(x: diameter / 2 + 7, y: diameter - 2))
            pointer.addLine(to: CGPoint(x: diameter / 2, y: diameter + pointerHeight))
            pointer.close()
            UIColor.white.setFill()
            pointer.fill()

            let circleRect = CGRect(x: 0, y: 0, width: diameter, height: diameter)
            UIBezierPath(ovalIn: circleRect).fill()

            let inset = circleRect.insetBy(dx: 3, dy: 3)
            context.cgContext.saveGState()
            UIBezierPath(ovalIn: inset).addClip()
            if let photo {
                let scale = max(inset.width / photo.size.width, inset.height / photo.size.height)
                let drawSize = CGSize(width: photo.size.width * scale, height: photo.size.height * scale)
                photo.draw(in: CGRect(x: inset.midX - drawSize.width / 2,
                                      y: inset.midY - drawSize.height / 2,
                                      width: drawSize.width,
                                      height: drawSize.height))
            } else {
                UIColor.systemYellow.setFill()
                UIBezierPath(rect: inset).fill()
            }
            context.cgContext.restoreGState()
        }
    }

    private func clearRouteLayers() {
        guard let mapView = mapViewController?.mapView else { return }
        spotAnnotationManager?.annotations = []
        try? mapView.mapboxMap.style.removeLayer(withId: "route-layer")
        try? mapView.mapboxMap.style.removeSource(withId: "route-source")
    }

    private func calculateBounds(from coordinates: [CLLocationCoordinate2D]) -> CoordinateBounds? {
        guard !coordinates.isEmpty else { return nil }
        
        var minLat = coordinates[0].latitude
        var maxLat = coordinates[0].latitude
        var minLon = coordinates[0].longitude
        var maxLon = coordinates[0].longitude
        
        for coordinate in coordinates {
            minLat = min(minLat, coordinate.latitude)
            maxLat = max(maxLat, coordinate.latitude)
            minLon = min(minLon, coordinate.longitude)
            maxLon = max(maxLon, coordinate.longitude)
        }
        
        return CoordinateBounds(
            southwest: CLLocationCoordinate2D(latitude: minLat, longitude: minLon),
            northeast: CLLocationCoordinate2D(latitude: maxLat, longitude: maxLon)
        )
    }
    
    private func centerMap(on bounds: CoordinateBounds) {
        guard let mapView = mapViewController?.mapView else { return }
        
        let camera = mapView.mapboxMap.camera(for: bounds, padding: UIEdgeInsets(top: 50, left: 50, bottom: 50, right: 50), bearing: 0, pitch: 0)
        mapView.camera.fly(to: camera, duration: 1.0)
    }
}

// MARK: - MapboxViewControllerDelegate
extension MapboxViewModel: MapboxViewControllerDelegate {
    func didUpdateLocation(_ location: CLLocation) {
        currentLocation = location
        if isTrackingLocation {
            centerOnUser()
        }
    }
}
