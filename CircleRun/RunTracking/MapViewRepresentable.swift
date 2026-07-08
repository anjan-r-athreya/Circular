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

        /// Renderer whose dash phase the display link slides each frame,
        /// making pulses of light travel along the route.
        private var shineRenderer: MKPolylineRenderer?
        private var displayLink: CADisplayLink?

        init(_ parent: MapViewRepresentable) {
            self.parent = parent
        }

        deinit {
            displayLink?.invalidate()
        }

        private func startShineIfNeeded() {
            guard displayLink == nil else { return }
            let link = CADisplayLink(target: self, selector: #selector(tickShine))
            // The pulses read fine at 30fps and cost half the redraws.
            link.preferredFrameRateRange = CAFrameRateRange(minimum: 20, maximum: 30, preferred: 30)
            link.add(to: .main, forMode: .common)
            displayLink = link
        }

        @objc private func tickShine() {
            guard let renderer = shineRenderer else { return }
            renderer.lineDashPhase -= 1.4
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
                // Sparse bright dashes gliding over the base line.
                let renderer = MKPolylineRenderer(polyline: shine)
                renderer.strokeColor = UIColor.white.withAlphaComponent(0.9)
                renderer.lineWidth = 3
                renderer.lineCap = .round
                renderer.lineDashPattern = [10, 90]
                shineRenderer = renderer
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
