//
//  RouteSharing.swift
//  CircleRun
//
//  GPX export and the share sheet for sending a loop to a friend or
//  another app (watch apps, Strava, etc. all speak GPX).
//

import Foundation
import CoreLocation
import SwiftUI
import UIKit

/// Identifiable wrapper so a share URL can drive a .sheet(item:).
struct ShareItem: Identifiable {
    let id = UUID()
    let url: URL
}

enum RouteSharing {
    static func gpxContent(coordinates: [CLLocationCoordinate2D], routeName: String) -> String {
        var gpx = """
        <?xml version="1.0" encoding="UTF-8"?>
        <gpx version="1.1" creator="CircleRun"
        xmlns="http://www.topografix.com/GPX/1/1"
        xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
        xsi:schemaLocation="http://www.topografix.com/GPX/1/1 http://www.topografix.com/GPX/1/1/gpx.xsd">
        <trk>
            <name>\(routeName)</name>
            <trkseg>
        """

        for coord in coordinates {
            gpx += """

                <trkpt lat="\(coord.latitude)" lon="\(coord.longitude)"></trkpt>
            """
        }

        gpx += """

            </trkseg>
        </trk>
        </gpx>
        """
        return gpx
    }

    /// Writes the route as a GPX file into the temp directory, named after
    /// the route, and returns its URL for the share sheet.
    static func gpxFileURL(coordinates: [CLLocationCoordinate2D],
                           name: String,
                           distanceMiles: Double) -> URL? {
        guard !coordinates.isEmpty else { return nil }

        let safeName = name.replacingOccurrences(of: "[^A-Za-z0-9._-]+",
                                                 with: "_",
                                                 options: .regularExpression)
        let fileName = "\(safeName.isEmpty ? "CircleRun" : safeName)_" +
                       "\(String(format: "%.1f", distanceMiles))mi.gpx"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)

        do {
            try gpxContent(coordinates: coordinates, routeName: name)
                .write(to: url, atomically: true, encoding: .utf8)
            return url
        } catch {
            print("GPX share export failed: \(error.localizedDescription)")
            return nil
        }
    }
}

/// UIKit activity view controller bridged for SwiftUI sheets.
struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}
