//
//  RouteDetailView.swift
//  CircleRun
//
//  Created by Anjan Athreya on 5/29/25.
//

import SwiftUI
import MapKit

struct RouteDetailView: View {
    let route: Route
    @Environment(\.dismiss) private var dismiss
    @State private var showingNavigation = false
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Map Preview
                MapSnapshotView(
                    coordinates: route.path,
                    size: CGSize(width: UIScreen.main.bounds.width - 32, height: 200),
                    lineColor: .blue
                )
                .clipShape(RoundedRectangle(cornerRadius: 16))
                
                // Route Stats
                VStack(spacing: 16) {
                    Text(route.name)
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    HStack(spacing: 40) {
                        StatItem(icon: "figure.run", title: "Runs", value: "\(route.runCount)")
                        StatItem(icon: "stopwatch", title: "Best Time", value: formatTime(route.bestTime))
                        StatItem(icon: "map", title: "Distance", value: "2.5 mi") // TODO: Calculate actual distance
                    }
                }
                .padding()
                .background(RoundedRectangle(cornerRadius: 16).fill(.ultraThinMaterial))
                
                // Action Buttons
                HStack(spacing: 12) {
                    // Load in Map Button
                    Button(action: {
                        NotificationCenter.default.post(name: Notification.Name("LoadFavoriteRoute"), object: route)
                        presentationMode.wrappedValue.dismiss()
                    }) {
                        HStack {
                            Image(systemName: "map.fill")
                            Text("Load in Map")
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue.opacity(0.8))
                        .foregroundColor(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                    }
                    
                    // Start Run Button
                    Button(action: {
                        showingNavigation = true
                    }) {
                        HStack {
                            Image(systemName: "location.fill")
                            Text("Start Run")
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                    }
                }
                .padding(.horizontal)
                
                // Additional route information
                VStack(alignment: .leading, spacing: 12) {
                    Text("Route Information")
                        .font(.headline)
                        .padding(.bottom, 4)
                    
                    InfoRow(icon: "map", title: "Starting Point", value: "Marina Green")
                    InfoRow(icon: "figure.walk", title: "Difficulty", value: "Moderate")
                    InfoRow(icon: "tree", title: "Terrain", value: "Mixed")
                    InfoRow(icon: "arrow.up.right", title: "Elevation Gain", value: "125 ft")
                }
                .padding()
                .background(RoundedRectangle(cornerRadius: 16).fill(.ultraThinMaterial))
            }
            .padding()
        }
        .navigationBarTitleDisplayMode(.inline)
        .fullScreenCover(isPresented: $showingNavigation) {
            NavigationInterface(route: route)
        }
    }
    
    private func formatTime(_ timeInterval: TimeInterval) -> String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute, .second]
        formatter.unitsStyle = .abbreviated
        return formatter.string(from: timeInterval) ?? "0s"
    }
}

// MARK: - Supporting Views
private struct StatItem: View {
    let icon: String
    let title: String
    let value: String
    
    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.blue)
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            Text(value)
                .font(.headline)
        }
    }
}

private struct InfoRow: View {
    let icon: String
    let title: String
    let value: String
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(.blue)
                .frame(width: 24)
            Text(title)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .fontWeight(.medium)
        }
    }
}

#Preview {
    NavigationStack {
        RouteDetailView(route: Route.sample())
    }
}
