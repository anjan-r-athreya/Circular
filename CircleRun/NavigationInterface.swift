//
//  NavigationInterface.swift
//  CircleRun
//
//  Created by Anjan Athreya on 5/29/25.
//

import SwiftUI
import MapKit
import CoreLocation

struct NavigationInterface: View {
    let route: Route
    @StateObject private var navigationManager = NavigationManager()
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .top) {
                // Map Layer
                MapLayer(route: route, navigationManager: navigationManager)
                    .ignoresSafeArea()
                
                // Navigation Overlays
                VStack(spacing: 0) {
                    if let currentInstruction = navigationManager.currentInstruction {
                        InstructionBanner(instruction: currentInstruction)
                            .transition(.move(edge: .top))
                    }
                    
                    Spacer()
                    
                    // Stats Panel
                    NavigationStatsPanel(stats: navigationManager.runningStats)
                        .padding(.horizontal)
                        .padding(.bottom, geometry.safeAreaInsets.bottom)
                }
            }
        }
        .onAppear {
            navigationManager.startNavigation(for: route)
        }
        .onDisappear {
            navigationManager.stopNavigation()
        }
    }
}

// MARK: - Map Layer
private struct MapLayer: View {
    let route: Route
    @ObservedObject var navigationManager: NavigationManager
    @State private var region: MKCoordinateRegion
    
    init(route: Route, navigationManager: NavigationManager) {
        self.route = route
        self.navigationManager = navigationManager
        
        // Initialize map region
        _region = State(initialValue: MKCoordinateRegion(
            center: route.path.first ?? CLLocationCoordinate2D(),
            span: MKCoordinateSpan(latitudeDelta: 0.005, longitudeDelta: 0.005)
        ))
    }
    
    var body: some View {
        Map(coordinateRegion: $region,
            showsUserLocation: true,
            userTrackingMode: .constant(.followWithHeading),
            annotationItems: navigationManager.turnPoints.indices.map { TurnPointWrapper(id: $0, turnPoint: navigationManager.turnPoints[$0]) }) { wrapper in
                MapAnnotation(coordinate: wrapper.turnPoint.coordinate) {
                    TurnIndicator(
                        direction: wrapper.turnPoint.direction,
                        distance: wrapper.turnPoint.distance,
                        isNext: wrapper.id == navigationManager.nextTurnIndex
                    )
                }
            }
    }
}

// Helper struct to make turn points identifiable for Map annotations
private struct TurnPointWrapper: Identifiable {
    let id: Int
    let turnPoint: TurnPoint
}

// MARK: - Instruction Banner
private struct InstructionBanner: View {
    let instruction: NavigationInstruction
    
    var body: some View {
        VStack(spacing: 4) {
            HStack {
                Text(instruction.text)
                    .font(.title3)
                    .bold()
                Spacer()
                Text(instruction.distance)
                    .font(.headline)
            }
            .padding()
            .background(.ultraThinMaterial)
        }
        .background(.ultraThinMaterial)
    }
}

// MARK: - Navigation Stats Panel
private struct NavigationStatsPanel: View {
    @State private var stats: RunningStats
    @Environment(\.dismiss) private var dismiss
    
    init(stats: RunningStats) {
        _stats = State(initialValue: stats)
    }
    
    var body: some View {
        VStack(spacing: 16) {
            // Stats Grid
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 16) {
                StatItem(title: "PACE", value: stats.currentPace)
                StatItem(title: "TIME", value: stats.elapsedTime)
                StatItem(title: "DISTANCE", value: stats.distanceCovered)
            }
            
            // Control Buttons
            HStack(spacing: 20) {
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title)
                        .foregroundColor(.gray)
                }
                
                Spacer()
                
                Button(action: { stats.isPaused.toggle() }) {
                    Image(systemName: stats.isPaused ? "play.circle.fill" : "pause.circle.fill")
                        .font(.title)
                        .foregroundColor(.blue)
                }
            }
            .padding(.horizontal)
        }
        .padding()
        .background(.ultraThinMaterial)
        .cornerRadius(16)
    }
}

// MARK: - Supporting Views
private struct StatItem: View {
    let title: String
    let value: String
    
    var body: some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            Text(value)
                .font(.headline)
        }
    }
}

private struct TurnIndicator: View {
    let direction: String
    let distance: String
    let isNext: Bool
    
    var body: some View {
        VStack {
            Image(systemName: "arrow.right.circle.fill")
                .font(.title2)
                .foregroundColor(isNext ? .blue : .gray)
                .rotationEffect(.degrees(direction == "right" ? 0 : 180))
            if isNext {
                Text(distance)
                    .font(.caption)
                    .padding(4)
                    .background(.ultraThinMaterial)
                    .cornerRadius(4)
            }
        }
    }
}

// MARK: - Preview
#Preview {
    NavigationInterface(route: Route.sample())
}
