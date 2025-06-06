//
//  CoordinateUtils.swift
//  CircleRun
//
//  Created by Anjan Athreya on 4/7/25.
//

import SwiftUI
import CoreLocation
import MapKit
import Foundation

func offsetCoordinate(from coord: CLLocationCoordinate2D, metersEast: Double, metersNorth: Double) -> CLLocationCoordinate2D {
    let earthRadius: Double = 6_371_000 // meters

    let deltaLat = metersNorth / earthRadius
    let deltaLon = metersEast / (earthRadius * cos(coord.latitude * .pi / 180))

    let newLat = coord.latitude + deltaLat * 180 / .pi
    let newLon = coord.longitude + deltaLon * 180 / .pi

    return CLLocationCoordinate2D(latitude: newLat, longitude: newLon)
}

extension MKPolyline {
    var coordinates: [CLLocationCoordinate2D] {
        var coords = [CLLocationCoordinate2D](repeating: kCLLocationCoordinate2DInvalid, count: pointCount)
        getCoordinates(&coords, range: NSRange(location: 0, length: pointCount))
        return coords
    }
}
