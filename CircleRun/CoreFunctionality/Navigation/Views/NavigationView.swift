//
//  NavigationView.swift
//  CircleRun
//
//  Created by Anjan Athreya on 5/30/25.
//

import SwiftUI
import MapKit
import CoreLocation
import MapboxNavigation

struct NavigationView: View {
    @StateObject var navigationManager: NavigationManager
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        ZStack {
            // Map View
            MapViewRepresentable(navigationManager: navigationManager)
                .edgesIgnoringSafeArea(.all)
            
            VStack {
                // Top Navigation Banner
                NavigationBanner(instruction: navigationManager.currentInstruction)
                    .background(Color(.systemBackground).opacity(0.9))
                
                Spacer()
                
                // Bottom Stats Banner
                StatsBanner(stats: navigationManager.runningStats)
                    .background(Color(.systemBackground).opacity(0.9))
            }
        }
        .overlay(
            // End Run Button
            VStack {
                HStack {
                    Spacer()
                    Button(action: {
                        navigationManager.stopNavigation()
                        dismiss()
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title)
                            .foregroundColor(.red)
                            .padding()
                    }
                }
                Spacer()
            }
        )
    }
}

// MARK: - Supporting Views
struct NavigationBanner: View {
    let instruction: NavigationInstruction?
    
    var body: some View {
        VStack(spacing: 0) {
            if let instruction = instruction {
                HStack(alignment: .center, spacing: 16) {
                    // Distance to next turn
                    Text(instruction.distance)
                        .font(.system(size: 34, weight: .bold))
                    
                    Spacer()
                    
                    // Turn arrows
                    HStack(spacing: 4) {
                        ForEach(0..<5) { index in
                            Image(systemName: getTurnArrowSystemName(for: instruction.maneuverType, at: index))
                                .font(.system(size: 28, weight: .medium))
                                .foregroundColor(index < 3 ? .gray : .primary)
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.top, 8)
                
                // Street name
                if let streetName = instruction.streetName {
                    Text(streetName)
                        .font(.system(size: 20, weight: .medium))
                        .padding(.horizontal)
                        .padding(.bottom, 8)
                }
            }
        }
    }
    
    private func getTurnArrowSystemName(for maneuverType: String, at index: Int) -> String {
        if index < 3 {
            return "arrow.up.circle.fill"
        } else if index == 3 {
            switch maneuverType {
            case "turn.right":
                return "arrow.turn.up.right.circle.fill"
            case "turn.left":
                return "arrow.turn.up.left.circle.fill"
            default:
                return "arrow.up.circle.fill"
            }
        } else {
            return maneuverType == "turn.right" ? "arrow.right.circle.fill" : "arrow.left.circle.fill"
        }
    }
}

struct StatsBanner: View {
    let stats: RunningStats
    
    var body: some View {
        HStack(spacing: 20) {
            // ETA/Arrival time
            VStack(alignment: .leading) {
                Text(stats.estimatedFinishTime)
                    .font(.system(size: 24, weight: .bold))
                Text("arrival")
                    .font(.system(size: 14))
                    .foregroundColor(.gray)
            }
            
            Spacer()
            
            // Remaining time
            VStack(alignment: .center) {
                Text(stats.elapsedTime)
                    .font(.system(size: 24, weight: .bold))
                Text("min")
                    .font(.system(size: 14))
                    .foregroundColor(.gray)
            }
            
            Spacer()
            
            // Remaining distance
            VStack(alignment: .trailing) {
                Text(stats.remainingDistance)
                    .font(.system(size: 24, weight: .bold))
                Text("mi")
                    .font(.system(size: 14))
                    .foregroundColor(.gray)
            }
        }
        .padding()
    }
}

// MARK: - Preview
#Preview {
    NavigationView(navigationManager: NavigationManager())
} 
