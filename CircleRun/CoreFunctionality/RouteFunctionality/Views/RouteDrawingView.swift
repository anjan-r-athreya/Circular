////
////  RouteDrawingView.swift
////  CircleRun
////
////  Created by Anjan Athreya on 6/3/25.
////
//
//import SwiftUI
//import MapKit
//import CoreLocation
//
//struct RouteDrawingView: View {
//    @StateObject private var viewModel = RouteDrawingViewModel()
//    @Environment(\.dismiss) private var dismiss
//    @Environment(\.colorScheme) private var colorScheme
//    
//    var body: some View {
//        ZStack {
//            // Map with drawing overlay
//            DrawableMapView(
//                drawnPoints: $viewModel.drawnPoints,
//                simplifiedPoints: $viewModel.simplifiedPoints,
//                snappedRoute: $viewModel.snappedRoute,
//                isDrawing: $viewModel.isDrawing,
//                onDrawingFinished: viewModel.processDrawnRoute
//            )
//            .edgesIgnoringSafeArea(.all)
//            
//            // Controls overlay
//            VStack {
//                // Close button
//                HStack {
//                    Button(action: { dismiss() }) {
//                        Image(systemName: "xmark")
//                            .font(.title2)
//                            .foregroundColor(.primary)
//                            .padding()
//                            .background(Color(.systemBackground))
//                            .clipShape(Circle())
//                            .shadow(radius: 3)
//                    }
//                    .padding()
//                    
//                    Spacer()
//                }
//                
//                Spacer()
//                
//                // Bottom controls
//                HStack {
//                    // Clear button (only show when there are points)
//                    if !viewModel.drawnPoints.isEmpty || viewModel.snappedRoute != nil {
//                        Button(action: viewModel.clearRoute) {
//                            Image(systemName: "trash")
//                                .font(.title2)
//                                .foregroundColor(.red)
//                                .padding()
//                                .background(Color(.systemBackground))
//                                .clipShape(Circle())
//                                .shadow(radius: 3)
//                        }
//                    }
//                    
//                    Spacer()
//                    
//                    // Save button (only show when route is complete)
//                    if viewModel.snappedRoute != nil && !viewModel.isProcessing {
//                        Button(action: { viewModel.showingSaveSheet = true }) {
//                            Image(systemName: "checkmark")
//                                .font(.title2)
//                                .foregroundColor(.green)
//                                .padding()
//                                .background(Color(.systemBackground))
//                                .clipShape(Circle())
//                                .shadow(radius: 3)
//                        }
//                    }
//                }
//                .padding()
//            }
//            
//            // Loading overlay
//            if viewModel.isProcessing {
//                Color.black.opacity(0.3)
//                    .edgesIgnoringSafeArea(.all)
//                
//                VStack(spacing: 16) {
//                    ProgressView()
//                        .scaleEffect(1.5)
//                    Text("Processing route...")
//                        .font(.headline)
//                        .foregroundColor(.white)
//                }
//                .frame(maxWidth: .infinity, maxHeight: .infinity)
//            }
//            
//            // Instructions overlay (show when no points)
//            if viewModel.drawnPoints.isEmpty && !viewModel.isProcessing {
//                VStack {
//                    Spacer()
//                    Text("Draw a route by dragging your finger on the map")
//                        .font(.subheadline)
//                        .foregroundColor(.secondary)
//                        .padding()
//                        .background(Color(.systemBackground).opacity(0.8))
//                        .cornerRadius(8)
//                        .padding(.bottom, 100)
//                }
//            }
//        }
//        .sheet(isPresented: $viewModel.showingSaveSheet) {
//            NavigationStack {
//                Form {
//                    Section {
//                        TextField("Route Name", text: $viewModel.routeName)
//                            .autocapitalization(.words)
//                            .disableAutocorrection(true)
//                    }
//                }
//                .navigationTitle("Save Route")
//                .toolbar {
//                    ToolbarItem(placement: .cancellationAction) {
//                        Button("Cancel") {
//                            viewModel.showingSaveSheet = false
//                        }
//                    }
//                    ToolbarItem(placement: .confirmationAction) {
//                        Button("Save") {
//                            viewModel.saveRoute()
//                        }
//                        .disabled(viewModel.routeName.isEmpty)
//                    }
//                }
//            }
//        }
//    }
//}
//
//// MARK: - DrawableMapView
//struct DrawableMapView: UIViewRepresentable {
//    @Binding var drawnPoints: [CLLocationCoordinate2D]
//    @Binding var simplifiedPoints: [CLLocationCoordinate2D]
//    @Binding var snappedRoute: MKPolyline?
//    @Binding var isDrawing: Bool
//    let onDrawingFinished: () -> Void
//    
//    func makeUIView(context: Context) -> MKMapView {
//        let mapView = MKMapView()
//        mapView.delegate = context.coordinator
//        mapView.showsUserLocation = true
//        mapView.showsCompass = true
//        mapView.showsScale = true
//        
//        // Configure initial region to user's location or default
//        if let userLocation = mapView.userLocation.location {
//            let region = MKCoordinateRegion(
//                center: userLocation.coordinate,
//                latitudinalMeters: 1000,
//                longitudinalMeters: 1000
//            )
//            mapView.setRegion(region, animated: false)
//        }
//        
//        // Add gesture recognizer for drawing
//        let panGesture = UIPanGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handlePanGesture(_:)))
//        panGesture.delegate = context.coordinator // Set the delegate
//        mapView.addGestureRecognizer(panGesture)
//        
//        return mapView
//    }
//    
//    func updateUIView(_ mapView: MKMapView, context: Context) {
//        // Remove existing overlays
//        mapView.removeOverlays(mapView.overlays)
//        
//        // Add drawn route overlay
//        if !drawnPoints.isEmpty {
//            let drawnLine = MKPolyline(coordinates: drawnPoints, count: drawnPoints.count)
//            mapView.addOverlay(drawnLine)
//        }
//        
//        // Add simplified points overlay
//        if !simplifiedPoints.isEmpty {
//            let simplifiedLine = MKPolyline(coordinates: simplifiedPoints, count: simplifiedPoints.count)
//            mapView.addOverlay(simplifiedLine)
//        }
//        
//        // Add snapped route overlay
//        if let snappedRoute = snappedRoute {
//            mapView.addOverlay(snappedRoute)
//            
//            // Fit the map to show the entire route with padding
//            let insets = UIEdgeInsets(top: 100, left: 50, bottom: 100, right: 50)
//            mapView.setVisibleMapRect(snappedRoute.boundingMapRect, edgePadding: insets, animated: true)
//        }
//    }
//    
//    func makeCoordinator() -> Coordinator {
//        Coordinator(self)
//    }
//    
//    class Coordinator: NSObject, MKMapViewDelegate, UIGestureRecognizerDelegate {
//        var parent: DrawableMapView
//        private var lastPoint: CGPoint?
//        private var lastUpdateTime: TimeInterval = 0
//        private let minimumUpdateInterval: TimeInterval = 0.05 // 50ms
//        
//        init(_ parent: DrawableMapView) {
//            self.parent = parent
//        }
//        
//        // Add gesture delegate method to handle simultaneous gestures
//        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
//            // Only allow simultaneous recognition when not in drawing mode
//            return !parent.isDrawing
//        }
//        
//        @objc func handlePanGesture(_ gesture: UIPanGestureRecognizer) {
//            guard let mapView = gesture.view as? MKMapView else { return }
//            
//            let currentTime = CACurrentMediaTime()
//            
//            switch gesture.state {
//            case .began:
//                // Start drawing mode
//                parent.isDrawing = true
//                parent.drawnPoints.removeAll()
//                parent.simplifiedPoints.removeAll()
//                parent.snappedRoute = nil
//                lastPoint = nil
//                lastUpdateTime = 0
//                
//                // Disable map scrolling while drawing
//                mapView.isScrollEnabled = false
//                
//            case .changed:
//                guard parent.isDrawing else { return }
//                
//                // Throttle updates
//                guard currentTime - lastUpdateTime >= minimumUpdateInterval else { return }
//                
//                let point = gesture.location(in: mapView)
//                
//                // Only add points if they're far enough from the last point
//                if let lastPoint = lastPoint {
//                    let distance = hypot(point.x - lastPoint.x, point.y - lastPoint.y)
//                    if distance < 10 { // Minimum distance threshold
//                        return
//                    }
//                }
//                
//                lastPoint = point
//                lastUpdateTime = currentTime
//                
//                let coordinate = mapView.convert(point, toCoordinateFrom: mapView)
//                if CLLocationCoordinate2DIsValid(coordinate) {
//                    parent.drawnPoints.append(coordinate)
//                }
//                
//            case .ended, .cancelled:
//                // Re-enable map scrolling
//                mapView.isScrollEnabled = true
//                
//                // Only process if we were actually drawing
//                if parent.isDrawing {
//                    parent.isDrawing = false
//                    if parent.drawnPoints.count >= 2 {
//                        parent.onDrawingFinished()
//                    }
//                }
//                
//            default:
//                break
//            }
//        }
//        
//        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
//            let renderer = MKPolylineRenderer(overlay: overlay)
//            
//            if overlay === parent.snappedRoute {
//                // Snapped route style
//                renderer.strokeColor = .systemBlue
//                renderer.lineWidth = 5
//                renderer.lineCap = .round
//                renderer.lineJoin = .round
//            } else if parent.simplifiedPoints.isEmpty {
//                // Drawing in progress style
//                renderer.strokeColor = .gray
//                renderer.lineWidth = 3
//                renderer.lineCap = .round
//                renderer.lineJoin = .round
//            } else {
//                // Simplified route style
//                renderer.strokeColor = .lightGray
//                renderer.lineWidth = 2
//                renderer.lineCap = .round
//                renderer.lineJoin = .round
//            }
//            
//            return renderer
//        }
//    }
//} 
