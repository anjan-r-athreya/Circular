//
//  ElevationService.swift
//  CircleRun
//
//  Elevation profiles for routes via the Open-Meteo elevation API (free, no
//  key, up to 100 points per request). Powers the elevation gain stat, the
//  terrain and difficulty classifications, and elevation-aware generation.
//

import Foundation
import CoreLocation

final class ElevationService {
    static let shared = ElevationService()

    private let cache = NSCache<NSString, NSNumber>()

    private init() {}

    /// Total climbing over the route, in meters. Uses ~75 evenly spaced
    /// samples and light smoothing so DEM noise doesn't inflate the number.
    func gainMeters(for coordinates: [CLLocationCoordinate2D]) async -> Double? {
        guard coordinates.count > 1 else { return nil }

        let samples = resample(coordinates, maxPoints: 75)
        let key = cacheKey(for: samples)
        if let cached = cache.object(forKey: key) { return cached.doubleValue }

        guard let elevations = await fetchElevations(for: samples),
              elevations.count == samples.count else { return nil }

        // 3-point moving average, then sum the positive deltas.
        var smoothed: [Double] = []
        for i in 0..<elevations.count {
            let lo = max(0, i - 1), hi = min(elevations.count - 1, i + 1)
            smoothed.append(elevations[lo...hi].reduce(0, +) / Double(hi - lo + 1))
        }
        var gain = 0.0
        for i in 0..<(smoothed.count - 1) {
            gain += max(0, smoothed[i + 1] - smoothed[i])
        }

        cache.setObject(NSNumber(value: gain), forKey: key)
        return gain
    }

    // MARK: - Classification

    /// Flat / Rolling / Hilly by climbing per mile.
    static func terrainDescription(gainMeters: Double, miles: Double) -> String {
        let gainPerMile = gainMeters / max(miles, 0.1)
        switch gainPerMile {
        case ..<12: return "Flat"
        case ..<30: return "Rolling"
        default: return "Hilly"
        }
    }

    /// Easy / Moderate / Hard from distance plus climbing (every ~160 m of
    /// gain runs like an extra mile).
    static func difficultyDescription(gainMeters: Double, miles: Double) -> String {
        let effortMiles = miles + gainMeters / 160
        switch effortMiles {
        case ..<4: return "Easy"
        case ..<8: return "Moderate"
        default: return "Hard"
        }
    }

    // MARK: - Fetching

    private func fetchElevations(for coordinates: [CLLocationCoordinate2D]) async -> [Double]? {
        let lats = coordinates.map { String(format: "%.5f", $0.latitude) }.joined(separator: ",")
        let lons = coordinates.map { String(format: "%.5f", $0.longitude) }.joined(separator: ",")

        var components = URLComponents(string: "https://api.open-meteo.com/v1/elevation")
        components?.queryItems = [
            URLQueryItem(name: "latitude", value: lats),
            URLQueryItem(name: "longitude", value: lons),
        ]
        guard let url = components?.url else { return nil }

        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            return try JSONDecoder().decode(ElevationResponse.self, from: data).elevation
        } catch {
            print("Elevation fetch failed: \(error.localizedDescription)")
            return nil
        }
    }

    /// Evenly spaced subset of the polyline, capped for the API's batch limit.
    private func resample(_ coordinates: [CLLocationCoordinate2D],
                          maxPoints: Int) -> [CLLocationCoordinate2D] {
        guard coordinates.count > maxPoints else { return coordinates }
        let stride = Double(coordinates.count - 1) / Double(maxPoints - 1)
        return (0..<maxPoints).map { coordinates[Int(Double($0) * stride)] }
    }

    private func cacheKey(for coordinates: [CLLocationCoordinate2D]) -> NSString {
        guard let first = coordinates.first, let last = coordinates.last else { return "" }
        return String(format: "%.5f,%.5f|%.5f,%.5f|%d",
                      first.latitude, first.longitude,
                      last.latitude, last.longitude,
                      coordinates.count) as NSString
    }

    private struct ElevationResponse: Decodable {
        let elevation: [Double]
    }
}
