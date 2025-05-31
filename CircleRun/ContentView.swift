//  ContentView.swift
//  CircleRun
//
//  Created by Anjan Athreya on 4/3/25.
//

import Foundation
import SwiftUI
import MapKit
import CoreLocation

class MapViewModel: ObservableObject {
    @Published var routePolyline: MKPolyline?
    @Published var position: MapCameraPosition = .userLocation(fallback: .automatic)
    @Published var actualMiles: Double?
    @Published var isFavorited: Bool = false
    @Published var isDirectionsActive: Bool = false
}

struct ContentView: View {
    @StateObject private var viewModel = MapViewModel()
    @State private var mileage: String = ""
    @FocusState private var isSearchFieldFocused: Bool
    @State private var userLocation: CLLocationCoordinate2D?
    @State private var isCircularRoute: Bool = false
    @State private var isLoading: Bool = false
    @State private var logoYOffset: CGFloat = -60
    @State private var logoOpacity: Double = 0.3
    @State private var showingFavorites = false
    @State private var routeCoordinates: [CLLocationCoordinate2D] = []
    @State private var selectedFavoriteRoute: Route?
    
    var body: some View {
        ZStack {
            // Map as full-screen background
            Map(position: $viewModel.position) {
                UserAnnotation()
                
                if let polyline = viewModel.routePolyline {
                    MapPolyline(polyline)
                        .stroke(Color(uiColor: MapOverlayStyle.polylineColor),
                                lineWidth: MapOverlayStyle.polylineWidth)
                }
            }
            .preferredColorScheme(.dark)
            .mapControls {
                MapUserLocationButton()
                    .position(x: UIScreen.main.bounds.width - 50, y: 250)
                MapCompass()
                    .position(x: UIScreen.main.bounds.width - 50, y: 300)
                MapPitchToggle()
                    .position(x: UIScreen.main.bounds.width - 50, y: 350)
            }
            .onAppear() {
                let manager = CLLocationManager()
                manager.requestWhenInUseAuthorization()
                
                manager.startUpdatingLocation()
                if let loc = manager.location?.coordinate {
                    userLocation = loc
                }
                
                // Set up notification observer for loading favorite routes
                NotificationCenter.default.addObserver(forName: Notification.Name("LoadFavoriteRoute"), object: nil, queue: .main) { notification in
                    if let route = notification.object as? Route {
                        loadFavoriteRoute(route)
                    }
                }
            }
            .onChange(of: selectedFavoriteRoute) { newRoute in
                if let route = newRoute {
                    loadFavoriteRoute(route)
                    // Reset after loading
                    DispatchQueue.main.async {
                        selectedFavoriteRoute = nil
                    }
                }
            }
            .onTapGesture {
                if !isLoading {
                    isSearchFieldFocused = false
                }
            }
            .ignoresSafeArea()
            
            // Controls overlay
            VStack {
                Spacer()
                
                // Bottom controls
                VStack(spacing: 12) {
                    if viewModel.routePolyline != nil && !isLoading {
                        HStack(spacing: 20) {
                            // Favorite button
                            Button(action: {
                                viewModel.isFavorited.toggle()
                                
                                if viewModel.isFavorited {
                                    // Save route to favorites
                                    saveRouteToFavorites()
                                } else {
                                    // Remove from favorites if unfavorited
                                    removeRouteFromFavorites()
                                }
                            }) {
                                Image(systemName: viewModel.isFavorited ? "star.fill" : "star")
                                    .foregroundColor(.yellow)
                                    .font(.system(size: 24))
                            }
                        }
                    }

                    TextField("Route Mileage:", text: $mileage)
                        .keyboardType(.numberPad)
                        .textFieldStyle(.roundedBorder)
                        .background(.ultraThinMaterial)
                    
                    Toggle("Circular Route", isOn: $isCircularRoute)
                        .padding(.vertical, 8)
                        .padding(.horizontal, 8)
                        .background(.ultraThinMaterial)
                        .foregroundColor(.white)
                    
                    Button("Generate Route") {
                        guard let start = userLocation,
                              let miles = Double(mileage) else {
                            print("Invalid input or location")
                            return
                        }
                        
                        isLoading = true
                        viewModel.isFavorited = false // Reset favorite state when generating new route
                        viewModel.isDirectionsActive = false // Reset directions state
                        
                        if isCircularRoute {
                            LoopGeneration.shared.generateCircularRoute(from: start, targetMiles: miles, viewModel: viewModel) {
                                // Store route coordinates for favorites
                                if let polyline = viewModel.routePolyline {
                                    storeRouteCoordinates(from: polyline)
                                }
                                isLoading = false
                            }
                        } else {
                            RouteManager.shared.generateRouteWithTargetDistance(from: start, targetMiles: miles, viewModel: viewModel) {
                                // Store route coordinates for favorites
                                if let polyline = viewModel.routePolyline {
                                    storeRouteCoordinates(from: polyline)
                                }
                                isLoading = false
                            }
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    
                    if let miles = viewModel.actualMiles {
                        Text("Actual route: \(String(format: "%.2f", miles)) miles")
                            .font(.subheadline)
                            .foregroundColor(.white)
                            .padding(.vertical, 4)
                            .padding(.horizontal, 8)
                            .background(.ultraThinMaterial)
                    }
                    
                }
                .padding()
            }
            
            // Navigation mode overlay
            if viewModel.isDirectionsActive, let polyline = viewModel.routePolyline {
                VStack {
                    HStack {
                        Spacer()
                        Button(action: {
                            viewModel.isDirectionsActive = false
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.title)
                                .foregroundColor(.white)
                                .padding()
                        }
                    }
                    
                    Spacer()
                    
                    // Navigation instructions card
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "arrow.up")
                                .font(.title)
                                .foregroundColor(.blue)
                                .frame(width: 40, height: 40)
                                .background(Circle().fill(.white))
                            
                            VStack(alignment: .leading) {
                                Text("Start navigation")
                                    .font(.headline)
                                Text("Follow route for \(String(format: "%.2f", totalDistance(of: polyline))) miles")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                        }
                        .padding()
                        .background(RoundedRectangle(cornerRadius: 12).fill(.ultraThinMaterial))
                    }
                    .padding()
                }
            }
            
            // Loading overlay
            if isLoading {
                Rectangle()
                    .fill(.ultraThinMaterial)
                    .ignoresSafeArea()
                    
                ZStack {
                    Image("Logo")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 600, height: 600)
                        .shadow(color: .blue, radius: 10)
                        .offset(y: logoYOffset)
                        .opacity(logoOpacity)
                        .onAppear {
                            withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                                logoOpacity = 1.0
                            }
                        }
                    
                    Color.clear
                        .onAppear {
                            isSearchFieldFocused  = false
                        }
                        .ignoresSafeArea()
                    
                    VStack {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(2)
                            .offset(y: 70)
                        
                        Text("Loading")
                            .foregroundColor(.white)
                            .font(.headline)
                            .padding(.top, 8)
                            .offset(y: 70)
                        Text("This can take up to 1 minute.")
                            .foregroundColor(.white)
                            .font(.headline)
                            .padding(.top, 8)
                            .offset(y: 70)
                    }
                }
            }
        }
        .sheet(isPresented: $showingFavorites) {
            FavoritesView()
        }
    }
    
    // Load a route from favorites
    private func loadFavoriteRoute(_ route: Route) {
        guard !route.path.isEmpty else { return }
        
        isLoading = true
        
        // Create a polyline from the route's path
        let polyline = MKPolyline(coordinates: route.path, count: route.path.count)
        
        // Update the viewModel
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.viewModel.routePolyline = polyline
            self.viewModel.position = .region(MKCoordinateRegion(polyline.boundingMapRect))
            self.viewModel.actualMiles = totalDistance(of: polyline)
            self.viewModel.isFavorited = true // Mark as favorited since it came from favorites
            self.storeRouteCoordinates(from: polyline)
            self.isLoading = false
        }
        
        // Update the mileage text field
        let miles = totalDistance(of: polyline)
        self.mileage = String(format: "%.1f", miles)
    }
    
    // Convert MKPolyline to array of CLLocationCoordinate2D
    private func storeRouteCoordinates(from polyline: MKPolyline) {
        let pointCount = polyline.pointCount
        var coordinates: [CLLocationCoordinate2D] = []
        
        let points = polyline.points()
        for i in 0..<pointCount {
            let mapPoint = points[i]
            coordinates.append(mapPoint.coordinate)
        }
        
        self.routeCoordinates = coordinates
    }
    
    // Save the current route to favorites
    private func saveRouteToFavorites() {
        guard !routeCoordinates.isEmpty, let miles = viewModel.actualMiles else {
            print("No route to save")
            return
        }
        
        let routeName = "Route \(String(format: "%.2f", miles)) miles"
        RouteManager.shared.saveAsFavorite(name: routeName, coordinates: routeCoordinates)
        
        // Show feedback to user
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
    }
    
    // Remove the current route from favorites
    private func removeRouteFromFavorites() {
        guard !routeCoordinates.isEmpty, let miles = viewModel.actualMiles else {
            return
        }
        
        let routeName = "Route \(String(format: "%.2f", miles)) miles"
        RouteManager.shared.removeFromFavorites(name: routeName, coordinates: routeCoordinates)
        
        // Show feedback to user
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
    }
}

func totalDistance(of polyline: MKPolyline) -> Double {
    var distance: Double = 0.0
    let points = polyline.points()
    
    for i in 0..<polyline.pointCount - 1 {
        let start = CLLocation(
            latitude: points[i].coordinate.latitude,
            longitude: points[i].coordinate.longitude
        )
        let end = CLLocation(
            latitude: points[i+1].coordinate.latitude,
            longitude: points[i+1].coordinate.longitude
        )
        distance += start.distance(from: end) // meters
    }
    
    return Double(distance / 1609.34) // convert to miles
}

#Preview {
    ContentView()
}
