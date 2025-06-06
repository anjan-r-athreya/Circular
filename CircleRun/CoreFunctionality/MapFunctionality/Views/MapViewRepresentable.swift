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
        mapView.userTrackingMode = .followWithHeading
        mapView.showsScale = navigationManager.showsScale
        mapView.mapType = navigationManager.mapType
        
        if let overlay = navigationManager.routeOverlay {
            mapView.addOverlay(overlay)
        }
        
        return mapView
    }
    
    func updateUIView(_ mapView: MKMapView, context: Context) {
        // Update overlays
        if let overlay = navigationManager.routeOverlay {
            mapView.removeOverlays(mapView.overlays)
            mapView.addOverlay(overlay)
        }
        
        // Update camera if available
        if let camera = navigationManager.camera {
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
        
        init(_ parent: MapViewRepresentable) {
            self.parent = parent
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
