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
    
    weak var mapViewController: MapboxViewController?
    private var currentLocation: CLLocation?
    private var routeAnnotation: PolylineAnnotation?
    
    // MARK: - Route Generation
    
    func generateLoop(targetMiles: Double) {
        guard let location = mapViewController?.mapView.location.latestLocation?.coordinate else {
            errorMessage = "Current location not available"
            return
        }
        
        // Clear all existing route data first
        routeCoordinates = []
        routeDistance = 0.0
        isFavorited = false // Reset favorite state
        if let mapView = mapViewController?.mapView {
            try? mapView.mapboxMap.style.removeLayer(withId: "route-layer")
            try? mapView.mapboxMap.style.removeSource(withId: "route-source")
        }
        
        isGeneratingRoute = true
        errorMessage = nil
        
        MapboxLoopGenerator.shared.generateCircularRoute(
            from: location,
            targetMiles: targetMiles
        ) { [weak self] response, error in
            DispatchQueue.main.async {
                self?.isGeneratingRoute = false
                
                if let error = error {
                    self?.errorMessage = error.localizedDescription
                    return
                }
                
                guard let route = response?.routes?.first,
                      let coordinates = route.shape?.coordinates else {
                    self?.errorMessage = "No route found"
                    return
                }
                
                self?.routeCoordinates = coordinates
                self?.routeDistance = route.distance / 1609.34 // Convert to miles
                self?.displayRoute(coordinates: coordinates)
                
                // Calculate bounds from coordinates and center map
                let bbox = self?.calculateBounds(from: coordinates)
                if let bounds = bbox {
                    self?.centerMap(on: bounds)
                }
            }
        }
    }
    
    // MARK: - Favorites Management
    
    func loadFavoriteRoute(_ route: Route) {
        // Clear existing route
        routeCoordinates = []
        routeDistance = 0.0
        if let mapView = mapViewController?.mapView {
            try? mapView.mapboxMap.style.removeLayer(withId: "route-layer")
            try? mapView.mapboxMap.style.removeSource(withId: "route-source")
        }
        
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
