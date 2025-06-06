//
//  SettingsView.swift
//  CircleRun
//
//  Created by Anjan Athreya on 6/4/25.
//

import SwiftUI
import MapKit

struct SettingsView: View {
    // Map & Display Settings
    @AppStorage("showsScale") private var showsScale = true
    @AppStorage("mapType") private var mapType = 0
    @AppStorage("preferredMapStyle") private var preferredMapStyle = 0
    @AppStorage("darkMode") private var darkMode = false
    
    // Navigation Settings
    @AppStorage("voiceGuidance") private var voiceGuidance = true
    @AppStorage("distanceUnit") private var distanceUnit = 0 // 0: miles, 1: kilometers
    
    // Route Preferences
    @AppStorage("avoidBusyRoads") private var avoidBusyRoads = true
    @AppStorage("elevationAwareness") private var elevationAwareness = true
    @AppStorage("preferredTerrain") private var preferredTerrain = 0
    
    // Integrations
    @AppStorage("syncStrava") private var syncStrava = false
    @State private var showingStravaAuth = false
    
    @State private var showingResetAlert = false
    
    private let mapTypes = ["Standard", "Satellite", "Hybrid"]
    private let distanceUnits = ["Miles", "Kilometers"]
    private let mapStyles = ["Default", "Running", "Nature", "Urban"]
    private let terrainTypes = ["Mixed", "Flat", "Hills", "Trail"]
    
    var body: some View {
        NavigationStack {
            Form {
                // Route Preferences
                Section(header: Text("Route Preferences")) {
                    Toggle("Avoid Busy Roads", isOn: $avoidBusyRoads)
                        .tint(.blue)
                    
                    Toggle("Elevation Awareness", isOn: $elevationAwareness)
                        .tint(.blue)
                    
                    Picker("Preferred Terrain", selection: $preferredTerrain) {
                        ForEach(0..<terrainTypes.count, id: \.self) { index in
                            Text(terrainTypes[index]).tag(index)
                        }
                    }
                }
                
                // Map Settings
                Section(header: Text("Map Settings")) {
                    Toggle("Show Scale", isOn: $showsScale)
                        .tint(.blue)
                    
                    Picker("Map Type", selection: $mapType) {
                        ForEach(0..<mapTypes.count, id: \.self) { index in
                            Text(mapTypes[index]).tag(index)
                        }
                    }
                    
                    Picker("Map Style", selection: $preferredMapStyle) {
                        ForEach(0..<mapStyles.count, id: \.self) { index in
                            Text(mapStyles[index]).tag(index)
                        }
                    }
                }
                
                // Navigation Settings
                Section(header: Text("Navigation")) {
                    Toggle("Voice Guidance", isOn: $voiceGuidance)
                        .tint(.blue)
                    
                    Picker("Distance Unit", selection: $distanceUnit) {
                        ForEach(0..<distanceUnits.count, id: \.self) { index in
                            Text(distanceUnits[index]).tag(index)
                        }
                    }
                }
                
                // Integrations
                Section(header: Text("Integrations")) {
                    Button(action: {
                        if !syncStrava {
                            showingStravaAuth = true
                        } else {
                            disconnectStrava()
                        }
                    }) {
                        HStack {
                            Text(syncStrava ? "Disconnect Strava" : "Connect Strava")
                            Spacer()
                            if syncStrava {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                            }
                        }
                    }
                }
                
                // App Settings
                Section(header: Text("App Settings")) {
                    Toggle("Dark Mode", isOn: $darkMode)
                        .onChange(of: darkMode) { _, newValue in
                            setAppAppearance(isDark: newValue)
                        }
                        .tint(.blue)
                }
                
                // Data Management
                Section(header: Text("Data Management")) {
                    Button(action: {
                        showingResetAlert = true
                    }) {
                        HStack {
                            Text("Reset All Data")
                            Spacer()
                            Image(systemName: "trash")
                        }
                        .foregroundColor(.red)
                    }
                }
                
                // About
                Section(header: Text("About")) {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0")
                            .foregroundColor(.secondary)
                    }
                    
                    Link(destination: URL(string: "https://www.example.com/privacy")!) {
                        HStack {
                            Text("Privacy Policy")
                            Spacer()
                            Image(systemName: "arrow.up.right.square")
                        }
                    }
                    
                    Link(destination: URL(string: "https://www.example.com/terms")!) {
                        HStack {
                            Text("Terms of Service")
                            Spacer()
                            Image(systemName: "arrow.up.right.square")
                        }
                    }
                }
            }
            .navigationTitle("Settings")
            .alert("Reset All Data", isPresented: $showingResetAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Reset", role: .destructive) {
                    resetAllData()
                }
            } message: {
                Text("This will delete all your routes, favorites, and settings. This action cannot be undone.")
            }
            .sheet(isPresented: $showingStravaAuth) {
                StravaAuthView(isConnected: $syncStrava)
            }
        }
    }
    
    private func setAppAppearance(isDark: Bool) {
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first {
            window.overrideUserInterfaceStyle = isDark ? .dark : .light
        }
    }
    
    private func disconnectStrava() {
        // TODO: Implement Strava disconnect logic
        syncStrava = false
    }
    
    private func resetAllData() {
        // Reset all UserDefaults
        if let bundleID = Bundle.main.bundleIdentifier {
            UserDefaults.standard.removePersistentDomain(forName: bundleID)
        }
        
        // Reset to default values
        showsScale = true
        mapType = 0
        voiceGuidance = true
        distanceUnit = 0
        darkMode = false
        avoidBusyRoads = true
        elevationAwareness = true
        preferredTerrain = 0
        preferredMapStyle = 0
        syncStrava = false
        
        // TODO: Clear any saved routes and favorites
    }
}

// MARK: - Strava Auth View
struct StravaAuthView: View {
    @Binding var isConnected: Bool
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            VStack {
                Image(systemName: "figure.run")
                    .font(.system(size: 60))
                    .foregroundColor(.orange)
                    .padding()
                
                Text("Connect with Strava")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Text("Sync your runs with Strava to share your achievements with friends and join challenges.")
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)
                    .padding()
                
                Button(action: {
                    // TODO: Implement Strava OAuth
                    isConnected = true
                    dismiss()
                }) {
                    HStack {
                        Image(systemName: "link")
                        Text("Connect")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.orange)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }
                .padding()
            }
            .padding()
            .navigationTitle("Strava")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
} 
