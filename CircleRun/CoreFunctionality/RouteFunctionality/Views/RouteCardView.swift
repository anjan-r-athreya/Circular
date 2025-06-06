//
//  RouteCardView.swift
//  CircleRun
//
//  Created by Anjan Athreya on 5/17/25.
//

import SwiftUI
import MapKit

struct RouteCardView: View {
    let route: Route
    @ObservedObject var viewModel: FavoritesViewModel
    var onRouteTapped: ((Route) -> Void)? = nil
    
    var body: some View {
        NavigationLink(destination: RouteDetailView(route: route)) {
            HStack(spacing: 16) {
                // Map snapshot
                MapSnapshotView(
                    coordinates: route.path,
                    lineColor: Color.blue
                )
                .frame(width: 100, height: 100)
                
                // Route details
                VStack(alignment: .leading, spacing: 4) {
                    Text(route.name)
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Spacer().frame(height: 4)
                    
                    HStack(spacing: 16) {
                        // Run count
                        Label {
                            Text("\(route.runCount)")
                                .foregroundColor(.secondary)
                        } icon: {
                            Image(systemName: "figure.run")
                                .foregroundColor(.blue)
                        }
                        
                        // Best time
                        Label {
                            Text(viewModel.formatTime(route.bestTime))
                                .foregroundColor(.secondary)
                        } icon: {
                            Image(systemName: "stopwatch")
                                .foregroundColor(.blue)
                        }
                    }
                    .font(.subheadline)
                }
                .padding(.vertical, 8)
                
                Spacer()
                
                // Unfavorite button
                Button(action: {
                    // Remove from favorites
                    viewModel.toggleFavorite(route: route)
                }) {
                    Image(systemName: "star.fill")
                        .foregroundColor(.yellow)
                        .font(.system(size: 22))
                        .padding(8)
                }
                .buttonStyle(BorderlessButtonStyle())
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(.systemBackground))
                    .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
            )
            .padding(.horizontal, 16)
            .padding(.vertical, 4)
        }
    }
}

struct RouteCardView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            RouteCardView(route: Route.sample(), viewModel: FavoritesViewModel())
                .previewLayout(.sizeThatFits)
                .padding()
        }
    }
}
