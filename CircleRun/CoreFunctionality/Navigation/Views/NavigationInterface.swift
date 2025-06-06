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
        ZStack(alignment: .top) {
            // 3D Map View
            MapViewRepresentable(navigationManager: navigationManager)
                .ignoresSafeArea()
            
            // Top Navigation Banner
            VStack(spacing: 0) {
                if let instruction = navigationManager.currentInstruction {
                    HStack(alignment: .center, spacing: 16) {
                        // Distance to next turn
                        Text(instruction.distance)
                            .font(.system(size: 34, weight: .bold))
                            .foregroundColor(.white)
                        
                        Spacer()
                        
                        // Turn arrows
                        HStack(spacing: 4) {
                            ForEach(0..<5) { index in
                                Image(systemName: getTurnArrowSystemName(for: instruction.maneuverType, at: index))
                                    .font(.system(size: 28, weight: .medium))
                                    .foregroundColor(index < 3 ? .gray : .white)
                            }
                        }
                    }
                    .padding(.horizontal)
                    .padding(.top, 8)
                    
                    // Street name
                    if let streetName = instruction.streetName {
                        Text(streetName)
                            .font(.system(size: 20, weight: .medium))
                            .foregroundColor(.white)
                            .padding(.horizontal)
                            .padding(.bottom, 8)
                    }
                }
            }
            .background(Color.black.opacity(0.75))
            
            // Bottom Stats Banner
            VStack {
                Spacer()
                
                HStack(spacing: 20) {
                    // ETA/Arrival time
                    VStack(alignment: .leading) {
                        Text(navigationManager.runningStats.estimatedFinishTime)
                            .font(.system(size: 24, weight: .bold))
                        Text("arrival")
                            .font(.system(size: 14))
                            .foregroundColor(.gray)
                    }
                    
                    Spacer()
                    
                    // Remaining time
                    VStack(alignment: .center) {
                        Text(navigationManager.runningStats.elapsedTime)
                            .font(.system(size: 24, weight: .bold))
                        Text("min")
                            .font(.system(size: 14))
                            .foregroundColor(.gray)
                    }
                    
                    Spacer()
                    
                    // Remaining distance
                    VStack(alignment: .trailing) {
                        Text(navigationManager.runningStats.remainingDistance)
                            .font(.system(size: 24, weight: .bold))
                        Text("mi")
                            .font(.system(size: 14))
                            .foregroundColor(.gray)
                    }
                }
                .padding()
                .background(Color.black.opacity(0.75))
            }
            
            // End Navigation Button
            VStack {
                HStack {
                    Spacer()
                    Button(action: {
                        navigationManager.stopNavigation()
                        dismiss()
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 32))
                            .foregroundColor(.white)
                            .padding()
                    }
                }
                Spacer()
            }
        }
        .onAppear {
            navigationManager.startNavigation(for: route)
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

// MARK: - Preview
#Preview {
    NavigationInterface(route: Route.sample())
} 
