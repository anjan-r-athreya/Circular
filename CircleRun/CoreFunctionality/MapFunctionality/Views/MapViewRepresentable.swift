//
//  MapViewRepresentable.swift
//  CircleRun
//
//  Created by Anjan Athreya on 5/30/25.
//

import SwiftUI
import MapKit

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
            context.coordinator.lastOverlay = overlay
        }

        return mapView
    }

    func updateUIView(_ mapView: MKMapView, context: Context) {
        // Swap overlays only when the route actually changed.
        if let overlay = navigationManager.routeOverlay,
           overlay !== context.coordinator.lastOverlay {
            mapView.removeOverlays(mapView.overlays)
            mapView.addOverlay(overlay)
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

        init(_ parent: MapViewRepresentable) {
            self.parent = parent
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
