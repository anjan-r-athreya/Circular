//
//  MainTabView.swift
//  CircleRun
//
//  Created by Anjan Athreya on 5/17/25.
//

import SwiftUI

struct MainTabView: View {
    @State private var selectedTab: Int = 0
    
    var body: some View {
        TabView(selection: $selectedTab) {
            // Home tab with ContentView
            ContentView()
                .tabItem {
                    Label("Home", systemImage: "house.fill")
                }
                .tag(0)
            
            // Map tab
            MapboxMapView()
                .tabItem {
                    Label("Map", systemImage: "map.fill")
                }
                .tag(1)
            
            // Apple Watch tab
            AppleWatchView()
                .tabItem {
                    Label("Watch", systemImage: "applewatch")
                }
                .tag(2)
            
            // Favorites tab with the complete FavoritesView
            FavoritesView()
                .tabItem {
                    Label("Favorites", systemImage: "star.fill")
                }
                .tag(3)
            
            // Settings tab
            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gear")
                }
                .tag(4)
        }
        .accentColor(.blue)
    }
}

struct MainTabView_Previews: PreviewProvider {
    static var previews: some View {
        MainTabView()
    }
}
