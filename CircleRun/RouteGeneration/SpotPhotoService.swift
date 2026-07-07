//
//  SpotPhotoService.swift
//  CircleRun
//
//  Resolves an actual photograph of a scenic spot for its suggestion card:
//  Wikipedia's photo of the matching article first, then Apple Look Around
//  street-level imagery, with a satellite tile only as the last resort.
//

import Foundation
import CoreLocation
import MapKit
import UIKit

// An actor so concurrent card loads serialize their claims on photo
// sources — nearby spots share the same Wikipedia geosearch results, and
// without claiming, several cards end up wearing the same closest-article
// photo.
actor SpotPhotoService {
    static let shared = SpotPhotoService()

    private let cache = NSCache<NSString, UIImage>()
    /// Wikipedia image URLs already used by a spot in the current batch.
    private var claimedSources = Set<String>()

    private init() {}

    /// Called when a fresh set of suggestions is fetched, so photo claims
    /// from the previous batch don't starve the new one.
    func beginBatch() {
        claimedSources.removeAll()
    }

    func photo(for spot: ScenicSpot, size: CGSize) async -> UIImage? {
        if let cached = cache.object(forKey: spot.id as NSString) { return cached }

        let image: UIImage?
        if let wiki = await wikipediaPhoto(for: spot) {
            image = wiki
        } else if let street = await lookAroundPhoto(at: spot.coordinate, size: size) {
            image = street
        } else {
            // Location-specific by nature, so inherently unique per spot.
            image = await satellitePhoto(at: spot.coordinate, size: size)
        }

        if let image { cache.setObject(image, forKey: spot.id as NSString) }
        return image
    }

    // MARK: - Wikipedia

    /// Finds Wikipedia articles geotagged near the spot and returns the lead
    /// photo of the one whose title matches the spot's name, falling back to
    /// the closest article that has a photo at all. Skips photos another
    /// spot in this batch already claimed.
    private func wikipediaPhoto(for spot: ScenicSpot) async -> UIImage? {
        var components = URLComponents(string: "https://en.wikipedia.org/w/api.php")
        components?.queryItems = [
            URLQueryItem(name: "action", value: "query"),
            URLQueryItem(name: "generator", value: "geosearch"),
            URLQueryItem(name: "ggscoord", value: "\(spot.latitude)|\(spot.longitude)"),
            URLQueryItem(name: "ggsradius", value: "1000"),
            URLQueryItem(name: "ggslimit", value: "10"),
            URLQueryItem(name: "prop", value: "pageimages"),
            URLQueryItem(name: "piprop", value: "thumbnail"),
            URLQueryItem(name: "pithumbsize", value: "500"),
            URLQueryItem(name: "format", value: "json"),
        ]
        guard let url = components?.url else { return nil }

        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let response = try JSONDecoder().decode(WikiResponse.self, from: data)
            guard let pages = response.query?.pages, !pages.isEmpty else { return nil }

            let spotName = spot.name.lowercased()
            let available = pages.values
                .filter { page in
                    guard let source = page.thumbnail?.source else { return false }
                    return !claimedSources.contains(source)
                }
            let match = available.first { page in
                let title = page.title.lowercased()
                return title.contains(spotName) || spotName.contains(title)
            } ?? available.min { ($0.index ?? .max) < ($1.index ?? .max) }

            guard let source = match?.thumbnail?.source,
                  let imageURL = URL(string: source) else { return nil }
            // Claim before the download await, so an interleaved request for
            // a neighboring spot can't pick the same photo.
            claimedSources.insert(source)
            let (imageData, _) = try await URLSession.shared.data(from: imageURL)
            return UIImage(data: imageData)
        } catch {
            return nil
        }
    }

    // MARK: - Look Around

    /// Street-level imagery of the spot, where Apple has coverage.
    private func lookAroundPhoto(at coordinate: CLLocationCoordinate2D,
                                 size: CGSize) async -> UIImage? {
        guard let scene = try? await MKLookAroundSceneRequest(coordinate: coordinate).scene else {
            return nil
        }
        let options = MKLookAroundSnapshotter.Options()
        options.size = size
        return try? await MKLookAroundSnapshotter(scene: scene, options: options).snapshot.image
    }

    // MARK: - Satellite fallback

    private func satellitePhoto(at coordinate: CLLocationCoordinate2D,
                                size: CGSize) async -> UIImage? {
        let options = MKMapSnapshotter.Options()
        options.region = MKCoordinateRegion(
            center: coordinate,
            latitudinalMeters: 600,
            longitudinalMeters: 600
        )
        options.size = size
        options.preferredConfiguration = MKImageryMapConfiguration()
        return try? await MKMapSnapshotter(options: options).start().image
    }

    // MARK: - Wikipedia response shape

    private struct WikiResponse: Decodable {
        let query: Query?

        struct Query: Decodable {
            let pages: [String: Page]?
        }

        struct Page: Decodable {
            let title: String
            /// Rank in the geosearch results (closest first).
            let index: Int?
            let thumbnail: Thumbnail?
        }

        struct Thumbnail: Decodable {
            let source: String
        }
    }
}
