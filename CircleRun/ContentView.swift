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
            }
            .onTapGesture {
                if !isLoading {
                    isSearchFieldFocused = false
                }
            }
            .ignoresSafeArea()
            
            // Controls overlay
            VStack {
                // Top menu button with circular background
                HStack {
                    Button(action: {
                        showingFavorites = true
                    }) {
                        Image(systemName: "line.3.horizontal")
                            .foregroundColor(.white)
                            .font(.system(size: 24))
                            .padding(12)
                            .background(Color(uiColor: MapOverlayStyle.polylineColor))
                            .clipShape(Circle())
                    }
                    .padding()
                    Spacer()
                }
                
                Spacer()
                
                // Bottom controls
                VStack(spacing: 12) {
                    if viewModel.routePolyline != nil && !isLoading {
                        Button(action: {
                            viewModel.isFavorited.toggle()
                        }) {
                            Image(systemName: viewModel.isFavorited ? "star.fill" : "star")
                                .foregroundColor(.yellow)
                                .font(.system(size: 24))
                        }
                    }

                    TextField("Route Mileage:", text: $mileage)
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
                        
                        if isCircularRoute {
                            LoopGeneration.shared.generateCircularRoute(from: start, targetMiles: miles, viewModel: viewModel, completion: {
                                isLoading = false
                            })
                        } else {
                            RouteManager.shared.generateRouteWithTargetDistance(from: start, targetMiles: miles, viewModel: viewModel, completion: {
                                isLoading = false
                            })
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
                    
                    VStack {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(2)
                            .offset(y: 70)
                        
                        Text("Loading...")
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
