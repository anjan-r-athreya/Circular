//
//  ScenicSpotService.swift
//  CircleRun
//
//  Finds scenic points of interest (parks, trails, waterfronts, viewpoints)
//  near the runner that could be woven into a generated loop.
//

import Foundation
import CoreLocation
import MapKit

struct ScenicSpot: Identifiable, Equatable, Hashable {
    let id: String
    let name: String
    let icon: String
    let latitude: Double
    let longitude: Double
    let distanceFromStart: Double

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    var distanceMilesText: String {
        String(format: "%.1f mi", distanceFromStart / 1609.34)
    }
}

final class ScenicSpotService {
    static let shared = ScenicSpotService()

    private init() {}

    private let categories: [(query: String, icon: String)] = [
        ("park", "leaf.fill"),
        ("trail", "figure.hiking"),
        ("garden", "leaf.fill"),
        ("beach", "water.waves"),
        ("waterfront", "water.waves"),
        ("lake", "water.waves"),
        ("viewpoint", "binoculars.fill"),
        ("monument", "building.columns.fill"),
    ]

    func findSpots(near start: CLLocationCoordinate2D,
                   targetMiles: Double) async -> [ScenicSpot] {
        let targetMeters = targetMiles * 1609.34
        let maxDistance = min(0.35 * targetMeters, 12_000)

        let region = MKCoordinateRegion(
            center: start,
            latitudinalMeters: maxDistance * 2,
            longitudinalMeters: maxDistance * 2
        )

        var found: [ScenicSpot] = []
        await withTaskGroup(of: [ScenicSpot].self) { group in
            for category in categories {
                group.addTask {
                    await self.search(query: category.query,
                                      icon: category.icon,
                                      near: start,
                                      region: region,
                                      maxDistance: maxDistance)
                }
            }
            for await spots in group {
                found.append(contentsOf: spots)
            }
        }

        var seenIDs = Set<String>()
        var seenNames = Set<String>()
        let unique = found
            .sorted { $0.distanceFromStart < $1.distanceFromStart }
            .filter { spot in
                guard !seenIDs.contains(spot.id),
                      !seenNames.contains(spot.name.lowercased()) else { return false }
                seenIDs.insert(spot.id)
                seenNames.insert(spot.name.lowercased())
                return true
            }

        return Array(unique.prefix(12))
    }

    private func search(query: String,
                        icon: String,
                        near start: CLLocationCoordinate2D,
                        region: MKCoordinateRegion,
                        maxDistance: Double) async -> [ScenicSpot] {
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = query
        request.region = region
        request.resultTypes = .pointOfInterest

        let startLocation = CLLocation(latitude: start.latitude, longitude: start.longitude)

        do {
            let response = try await MKLocalSearch(request: request).start()
            return response.mapItems.compactMap { item in
                guard let name = item.name, !name.isEmpty else { return nil }
                let loc = item.placemark.coordinate
                let distance = startLocation.distance(
                    from: CLLocation(latitude: loc.latitude, longitude: loc.longitude)
                )
                guard distance <= maxDistance, distance > 200 else { return nil }
                let spotID = "\(loc.latitude),\(loc.longitude)"
                return ScenicSpot(id: spotID,
                                  name: name,
                                  icon: icon,
                                  latitude: loc.latitude,
                                  longitude: loc.longitude,
                                  distanceFromStart: distance)
            }
        } catch {
            print("Scenic spot search failed for \(query): \(error.localizedDescription)")
            return []
        }
    }
}
