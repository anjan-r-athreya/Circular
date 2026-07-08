//
//  MapViewRepresentable.swift
//  CircleRun
//
//  Created by Anjan Athreya on 5/30/25.
//

import SwiftUI
import MapKit

/// Marker subclass so the renderer can tell the shine overlay apart from
/// the base route line.
final class ShinePolyline: MKPolyline {}

/// Draws a glowing comet segment that laps the route. The display link
/// advances `progress`; each draw strokes just the trail behind the head —
/// real geometry, so it renders wherever MapKit does.
final class CometRenderer: MKOverlayRenderer {
    private let mapPoints: [MKMapPoint]
    private let cumulative: [Double]
    private let total: Double

    /// 0…1 position of the comet head along the route.
    var progress: Double = 0

    init(shine: ShinePolyline) {
        let buffer = shine.points()
        var points: [MKMapPoint] = []
        points.reserveCapacity(shine.pointCount)
        for i in 0..<shine.pointCount { points.append(buffer[i]) }
        mapPoints = points

        var distances: [Double] = [0]
        distances.reserveCapacity(points.count)
        for i in 1..<max(points.count, 1) {
            distances.append(distances[i - 1] + points[i - 1].distance(to: points[i]))
        }
        cumulative = distances
        total = distances.last ?? 0

        super.init(overlay: shine)
    }

    override func draw(_ mapRect: MKMapRect, zoomScale: MKZoomScale, in context: CGContext) {
        guard total > 0, mapPoints.count > 2 else { return }

        let head = progress * total
        let tail = head - total * 0.10

        // Sample the trail; the loop is closed, so wrapping through the
        // seam is seamless.
        let samples = 20
        let path = CGMutablePath()
        for s in 0...samples {
            var d = tail + (head - tail) * Double(s) / Double(samples)
            if d < 0 { d += total }
            let point = self.point(for: mapPoint(at: d))
            if s == 0 { path.move(to: point) } else { path.addLine(to: point) }
        }

        let width = 5 / zoomScale
        context.setLineCap(.round)
        context.setLineJoin(.round)

        // Soft glow under a bright core.
        context.setStrokeColor(UIColor.white.withAlphaComponent(0.35).cgColor)
        context.setLineWidth(width * 2.4)
        context.addPath(path)
        context.strokePath()

        context.setStrokeColor(UIColor.white.withAlphaComponent(0.95).cgColor)
        context.setLineWidth(width)
        context.addPath(path)
        context.strokePath()
    }

    private func mapPoint(at distance: Double) -> MKMapPoint {
        let d = min(max(distance, 0), total)
        var low = 0, high = cumulative.count - 1
        while low + 1 < high {
            let mid = (low + high) / 2
            if cumulative[mid] < d { low = mid } else { high = mid }
        }
        let segment = cumulative[high] - cumulative[low]
        let t = segment > 0 ? (d - cumulative[low]) / segment : 0
        return MKMapPoint(x: mapPoints[low].x + (mapPoints[high].x - mapPoints[low].x) * t,
                          y: mapPoints[low].y + (mapPoints[high].y - mapPoints[low].y) * t)
    }
}

struct MapViewRepresentable: UIViewRepresentable {
    @ObservedObject var navigationManager: NavigationManager

    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.delegate = context.coordinator
        mapView.showsUserLocation = true
        // The navigation camera is driven by NavigationManager; MapKit's own
        // tracking mode would fight both it and the user's gestures.
        mapView.userTrackingMode = .none
        mapView.showsScale = navigationManager.showsScale
        mapView.mapType = navigationManager.mapType

        if let overlay = navigationManager.routeOverlay {
            mapView.addOverlay(overlay)
            mapView.addOverlay(Self.shineOverlay(matching: overlay))
            context.coordinator.lastOverlay = overlay
        }

        return mapView
    }

    /// A second polyline over the same points that carries the moving shine.
    private static func shineOverlay(matching polyline: MKPolyline) -> ShinePolyline {
        let points = polyline.points()
        var coordinates = (0..<polyline.pointCount).map { points[$0].coordinate }
        return ShinePolyline(coordinates: &coordinates, count: coordinates.count)
    }

    func updateUIView(_ mapView: MKMapView, context: Context) {
        // Swap overlays only when the route actually changed.
        if let overlay = navigationManager.routeOverlay,
           overlay !== context.coordinator.lastOverlay {
            mapView.removeOverlays(mapView.overlays)
            mapView.addOverlay(overlay)
            mapView.addOverlay(Self.shineOverlay(matching: overlay))
            context.coordinator.lastOverlay = overlay
        }

        // Apply each navigation camera exactly once — re-applying it on every
        // SwiftUI refresh is what froze the map against pinches and pans.
        if let camera = navigationManager.camera,
           camera !== context.coordinator.lastAppliedCamera {
            context.coordinator.lastAppliedCamera = camera
            mapView.setCamera(camera, animated: true)
        }

        // Update map settings
        mapView.showsScale = navigationManager.showsScale
        mapView.mapType = navigationManager.mapType
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, MKMapViewDelegate {
        var parent: MapViewRepresentable
        var lastAppliedCamera: MKMapCamera?
        var lastOverlay: MKOverlay?

        /// The comet renderer whose progress the display link advances.
        private var cometRenderer: CometRenderer?
        private var displayLink: CADisplayLink?
        private var lastTick: CFTimeInterval = 0

        init(_ parent: MapViewRepresentable) {
            self.parent = parent
        }

        deinit {
            displayLink?.invalidate()
        }

        private func startShineIfNeeded() {
            guard displayLink == nil else { return }
            let link = CADisplayLink(target: self, selector: #selector(tickShine))
            // The comet reads fine at 30fps and costs half the redraws.
            link.preferredFrameRateRange = CAFrameRateRange(minimum: 20, maximum: 30, preferred: 30)
            link.add(to: .main, forMode: .common)
            displayLink = link
        }

        @objc private func tickShine(_ link: CADisplayLink) {
            guard let renderer = cometRenderer else { return }
            let delta = lastTick == 0 ? 1.0 / 30.0 : link.timestamp - lastTick
            lastTick = link.timestamp
            // One lap every ~3.4 seconds, matching the main map's comet.
            renderer.progress = (renderer.progress + delta / 3.4)
                .truncatingRemainder(dividingBy: 1)
            renderer.setNeedsDisplay()
        }

        func mapView(_ mapView: MKMapView, regionWillChangeAnimated animated: Bool) {
            // A camera change driven by an active gesture means the user is
            // panning or zooming — stop chasing them until they re-center.
            let isUserGesture = mapView.subviews.first?.gestureRecognizers?.contains {
                $0.state == .began || $0.state == .changed || $0.state == .ended
            } ?? false
            if isUserGesture, parent.navigationManager.isFollowingUser {
                DispatchQueue.main.async {
                    self.parent.navigationManager.isFollowingUser = false
                }
            }
        }

        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            if let shine = overlay as? ShinePolyline {
                let renderer = CometRenderer(shine: shine)
                cometRenderer = renderer
                startShineIfNeeded()
                return renderer
            }
            if let polyline = overlay as? MKPolyline {
                let renderer = MKPolylineRenderer(polyline: polyline)
                renderer.strokeColor = .systemBlue
                renderer.lineWidth = 5
                return renderer
            }
            return MKOverlayRenderer(overlay: overlay)
        }
    }
} 
