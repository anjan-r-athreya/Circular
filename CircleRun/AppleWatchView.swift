//
//  AppleWatchView.swift
//  CircleRun
//
//  Created by Anjan Athreya on 5/23/25.
//

import SwiftUI
import WatchConnectivity
import CoreLocation

class WatchConnectivityManager: NSObject, ObservableObject, WCSessionDelegate {
    @Published var isWatchConnected = false
    @Published var isWatchAppInstalled = false
    @Published var connectionStatus = "Not Connected"
    @Published var lastSentRouteName: String?

    override init() {
        super.init()
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        session.delegate = self
        session.activate()
    }

    // MARK: - WCSessionDelegate

    func session(_ session: WCSession,
                 activationDidCompleteWith activationState: WCSessionActivationState,
                 error: Error?) {
        DispatchQueue.main.async {
            switch activationState {
            case .activated:
                self.isWatchConnected = session.isPaired && session.isWatchAppInstalled
                self.isWatchAppInstalled = session.isWatchAppInstalled
                self.connectionStatus = session.isPaired
                    ? (session.isWatchAppInstalled ? "Connected" : "App Not Installed")
                    : "Watch Not Paired"
            case .inactive:
                self.connectionStatus = "Inactive"
            case .notActivated:
                self.connectionStatus = "Not Activated"
            @unknown default:
                self.connectionStatus = "Unknown"
            }
        }
    }

    func sessionDidBecomeInactive(_ session: WCSession) {
        DispatchQueue.main.async { self.connectionStatus = "Session Inactive" }
    }

    func sessionDidDeactivate(_ session: WCSession) {
        DispatchQueue.main.async { self.connectionStatus = "Session Deactivated" }
        WCSession.default.activate()  // re-activate after deactivation
    }

    // MARK: - Send Route

    func sendRouteToWatch(_ route: Route) {
        // Serialize the Route into a dictionary
        let routeData: [String: Any] = [
            "id": route.id.uuidString,
            "name": route.name,
            "coordinates": route.path.map { ["lat": $0.latitude, "lng": $0.longitude] },
            "runCount": route.runCount,
            "bestTime": route.bestTime
        ]
        let payload = ["route": routeData]

        // Immediate delivery if frontmost
        if WCSession.default.isReachable {
            WCSession.default.sendMessage(payload, replyHandler: nil) { error in
                print("sendMessage error:", error.localizedDescription)
            }
        }
        // Always queue background transfer
        WCSession.default.transferUserInfo(payload)

        // Update UI feedback
        DispatchQueue.main.async {
            self.lastSentRouteName = route.name
        }
    }
}

struct AppleWatchView: View {
    @StateObject private var watchManager = WatchConnectivityManager()
    @State private var selectedRoute: Route?
    @State private var showingRoutePicker = false

    // Use existing sample data from Route.swift
    private let availableRoutes = Route.samples

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Connection status + last sent feedback
                    VStack(spacing: 16) {
                        Image(systemName: watchManager.isWatchConnected ? "applewatch" : "applewatch.slash")
                            .font(.system(size: 60))
                            .foregroundColor(watchManager.isWatchConnected ? .green : .gray)

                        Text(watchManager.connectionStatus)
                            .font(.headline)
                            .foregroundColor(watchManager.isWatchConnected ? .green : .primary)

                        if let last = watchManager.lastSentRouteName {
                            Text("Sent \"\(last)\"")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding()
                    .background(RoundedRectangle(cornerRadius: 16).fill(.ultraThinMaterial))

                    if watchManager.isWatchConnected {
                        // Route selection and transfer UI
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Send Route to Apple Watch")
                                .font(.title2).fontWeight(.semibold)

                            if let route = selectedRoute {
                                SimpleRouteCardView(route: route)
                                    .onTapGesture { showingRoutePicker = true }

                                Button {
                                    watchManager.sendRouteToWatch(route)
                                } label: {
                                    Label("Send to Watch", systemImage: "arrow.up.circle.fill")
                                        .font(.headline)
                                        .foregroundColor(.white)
                                        .frame(maxWidth: .infinity)
                                        .padding()
                                        .background(Color.blue)
                                        .cornerRadius(12)
                                }
                            } else {
                                Button {
                                    showingRoutePicker = true
                                } label: {
                                    Label("Select Route", systemImage: "plus.circle")
                                        .font(.headline)
                                        .frame(maxWidth: .infinity)
                                        .padding()
                                        .background(Color.blue)
                                        .foregroundColor(.white)
                                        .cornerRadius(12)
                                }
                            }

                            // Reuse FeatureRow from existing file
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Apple Watch Features")
                                    .font(.title2).fontWeight(.semibold)
                                FeatureRow(icon: "map", title: "View Route Maps", description: "See your routes on your watch")
                                FeatureRow(icon: "location", title: "GPS Tracking",    description: "Track runs live")
                                FeatureRow(icon: "heart",    title: "Health Integration", description: "Monitor heart rate")
                                FeatureRow(icon: "stopwatch",title: "Real-time Stats",   description: "Pace, distance, time")
                            }
                        }
                        .padding()
                        .background(RoundedRectangle(cornerRadius: 16).fill(.ultraThinMaterial))
                    } else {
                        // Setup instructions when not connected
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Setup Instructions")
                                .font(.title2).fontWeight(.semibold)
                            SetupStep(number: "1", title: "Pair Your Apple Watch", description: "Ensure it’s paired in the iPhone Watch app")
                            SetupStep(number: "2", title: "Install Watch App",      description: "Build & run using the paired simulator scheme")
                            SetupStep(number: "3", title: "Enable Permissions",     description: "Allow location & health data access")
                        }
                        .padding()
                        .background(RoundedRectangle(cornerRadius: 16).fill(.ultraThinMaterial))
                    }
                    Spacer()
                }
                .padding()
            }
            .navigationTitle("Apple Watch")
            .sheet(isPresented: $showingRoutePicker) {
                NavigationView {
                    List(availableRoutes) { route in
                        SimpleRouteCardView(route: route)
                            .onTapGesture {
                                selectedRoute = route
                                showingRoutePicker = false
                            }
                    }
                    .navigationTitle("Select Route")
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Cancel") { showingRoutePicker = false }
                        }
                    }
                }
            }
        }
    }
}

// Reuse FeatureRow and SetupStep from your existing file
struct FeatureRow: View {
    let icon: String
    let title: String
    let description: String
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.blue)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.headline)
                Text(description).font(.caption).foregroundColor(.secondary)
            }
            Spacer()
        }
    }
}

struct SetupStep: View {
    let number: String, title: String, description: String
    var body: some View {
        HStack(spacing: 12) {
            Text(number)
                .font(.headline).fontWeight(.bold)
                .foregroundColor(.white)
                .frame(width: 24, height: 24)
                .background(Circle().fill(.blue))
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.headline)
                Text(description).font(.caption).foregroundColor(.secondary)
            }
            Spacer()
        }
    }
}

fileprivate struct IdentifiableCoord: Identifiable {
    let id = UUID()
    let coordinate: CLLocationCoordinate2D
}
