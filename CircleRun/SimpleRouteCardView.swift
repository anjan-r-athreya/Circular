//
//  SimpleRouteCardView.swift
//  CircleRun
//
//  Created by Anjan Athreya on 5/23/25.
//

import SwiftUI
import MapKit

struct SimpleRouteCardView: View {
    let route: Route
    
    var body: some View {
        HStack(spacing: 16) {
            // Map snapshot
            MapSnapshotView(
                coordinates: route.path,
                lineColor: Color.blue
            )
            .frame(width: 80, height: 80)
            
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
                        Text(formatTime(route.bestTime))
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
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemBackground))
                .shadow(color: Color.black.opacity(0.1), radius: 3, x: 0, y: 1)
        )
        .contentShape(Rectangle())
    }
    
    private func formatTime(_ timeInterval: TimeInterval) -> String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute, .second]
        formatter.unitsStyle = .abbreviated
        return formatter.string(from: timeInterval) ?? "0s"
    }
}

struct SimpleRouteCardView_Previews: PreviewProvider {
    static var previews: some View {
        SimpleRouteCardView(route: Route.sample())
            .previewLayout(.sizeThatFits)
            .padding()
    }
}
