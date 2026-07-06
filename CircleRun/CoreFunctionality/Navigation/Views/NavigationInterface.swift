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
            
            // Map controls: end run, 2D/3D toggle, re-center
            VStack {
                HStack {
                    Spacer()
                    VStack(spacing: 12) {
                        Button(action: {
                            endRun()
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 32))
                                .foregroundColor(.white)
                        }

                        // Toggle between the 3D chase camera and a flat 2D view
                        Button(action: {
                            navigationManager.toggle3DMode()
                        }) {
                            Image(systemName: navigationManager.is3DMode ? "view.3d" : "view.2d")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(.white)
                                .frame(width: 40, height: 40)
                                .background(Color.black.opacity(0.6))
                                .clipShape(Circle())
                        }

                        // Shown once the user pans/zooms away from the runner
                        if !navigationManager.isFollowingUser {
                            Button(action: {
                                navigationManager.resumeFollowing()
                            }) {
                                Image(systemName: "location.fill")
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundColor(.white)
                                    .frame(width: 40, height: 40)
                                    .background(Color.blue.opacity(0.9))
                                    .clipShape(Circle())
                            }
                        }
                    }
                    .padding()
                }
                Spacer()
            }
            .padding(.top, 60)
        }
        .onAppear {
            navigationManager.startNavigation(for: route)
        }
    }

    /// Stops navigation, and if the runner actually covered the route (90%+
    /// of its distance), records the time toward the route's best times.
    private func endRun() {
        let elapsed = navigationManager.elapsedSeconds
        let milesCovered = navigationManager.metersTraveled / 1609.34
        if milesCovered >= route.distance * 0.9 {
            RouteManager.shared.recordRun(routeID: route.id, time: elapsed)
        }
        navigationManager.stopNavigation()
        dismiss()
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
