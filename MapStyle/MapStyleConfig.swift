//
//  MapStyleConfig.swift
//  CircleRun
//
//  Created by Anjan Athreya on 4/5/25.
//

import SwiftUI
import MapKit

struct MapStyleConfig {
    enum BaseMapStyle: CaseIterable {
        case standard, hybrid, imagery
        var label: String {
            switch self {
            case .standard:
                "Standard"
            case .hybrid:
                "Satelite with Roads"
            case .imagery:
                "Satelite Only"
            }
        }
    }
    
    enum MapElevaton {
        case flat, realistic
        var selection: MapStyle.Elevation {
            switch self {
            case .flat:
                    .flat
            case .realistic:
                    .realistic
            }
        }
    }
    
    enum MapPOI {
        case all, excludingAll
        var selection: PointOfInterestCategories {
            switch self {
            case .all:
                    .all
            case .excludingAll:
                    .excludingAll
            }
        }
    }
    
    var baseStyle = BaseMapStyle.standard
    var elevation = MapElevaton.flat
    var pointsOfInterest = MapPOI.excludingAll
    
    var showTraffic = false
    
    var mapStyle: MapStyle {
        switch baseStyle {
        case .standard:
            MapStyle.standard(elevation: elevation.selection, pointsOfInterest: pointsOfInterest.selection, showsTraffic: showTraffic)
        case .hybrid:
            MapStyle.hybrid(elevation: elevation.selection, pointsOfInterest: pointsOfInterest.selection, showsTraffic: showTraffic)
        case .imagery:
            MapStyle.imagery(elevation: elevation.selection)
        }
    }
}

extension MKMapConfiguration {
    static var grayscaleStyle: MKMapConfiguration {
        let config = MKStandardMapConfiguration()
        config.pointOfInterestFilter = .excludingAll
        config.elevationStyle = .flat
        
        // Make map grayscale
        config.emphasisStyle = .muted
        
        return config
    }
}

struct MapOverlayStyle {
    static let polylineColor = UIColor(red: 0/255, green: 0/255, blue: 128/255, alpha: 1.0) // Navy blue
    static let polylineWidth: CGFloat = 4.0
}
