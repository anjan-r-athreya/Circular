//
//  MapboxConfig.swift
//  CircleRun
//
//  Created by Anjan Athreya on 6/5/25.
//

import Foundation
import MapboxMaps
import CoreLocation

enum MapboxConfig {
    // IMPORTANT: Replace this with your actual Mapbox public access token
    static let accessToken = "pk.eyJ1IjoiYW5qYW4tci1hdGhyZXlhIiwiYSI6ImNtOWdjanhuNjAyZDQya3B4dDd1OXFpNGQifQ.GJva2IoFhwjXwBRw7nGH2A"
    
    // This method should be called when the app starts
    static func configure() {
        // Set the access token for all Mapbox services
        ResourceOptionsManager.default.resourceOptions.accessToken = accessToken
    }
    
    enum Style {
        static let streets = StyleURI.streets
        static let outdoors = StyleURI.outdoors
        static let satellite = StyleURI.satellite
        static let satelliteStreets = StyleURI.satelliteStreets
        static let light = StyleURI.light
        static let dark = StyleURI.dark
        
        static func styleURI(for style: MapStyle) -> StyleURI {
            switch style {
            case .streets:
                return .streets
            case .outdoors:
                return .outdoors
            case .satellite:
                return .satellite
            case .satelliteStreets:
                return .satelliteStreets
            case .light:
                return .light
            case .dark:
                return .dark
            }
        }
    }
    
    enum MapStyle: String, CaseIterable {
        case streets = "Streets"
        case outdoors = "Outdoors"
        case satellite = "Satellite"
        case satelliteStreets = "Satellite Streets"
        case light = "Light"
        case dark = "Dark"
    }
    
    static let defaultCameraOptions = CameraOptions(
        center: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
        zoom: 15,
        bearing: 0,
        pitch: 0
    )
    
    static let defaultNavigationCameraOptions = CameraOptions(
        zoom: 15,
        bearing: 0,
        pitch: 45
    )
}
