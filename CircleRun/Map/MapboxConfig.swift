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
    /// Read from Info.plist (MBXAccessToken), which the build fills in from
    /// the gitignored Config/Secrets.xcconfig — the token never lives in
    /// source control. Missing token: copy Config/Secrets.example.xcconfig
    /// to Config/Secrets.xcconfig and add yours.
    static let accessToken: String = {
        guard let token = Bundle.main.object(forInfoDictionaryKey: "MBXAccessToken") as? String,
              token.hasPrefix("pk.") else {
            assertionFailure("""
                Missing Mapbox token. Copy Config/Secrets.example.xcconfig to \
                Config/Secrets.xcconfig and set MAPBOX_ACCESS_TOKEN.
                """)
            return ""
        }
        return token
    }()
    
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
