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
            // Map tab
            MapboxMapView()
                .tabItem {
                    Label("Map", systemImage: "map.fill")
                }
                .tag(0)

            // Favorites tab with the complete FavoritesView
            FavoritesView()
                .tabItem {
                    Label("Favorites", systemImage: "star.fill")
                }
                .tag(1)

            // Settings tab: pace and route preferences
            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gearshape.fill")
                }
                .tag(2)
        }
        .accentColor(.blue)
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("LoadFavoriteRoute"))) { _ in
            // "Load in Map" needs the map on screen to mean anything.
            selectedTab = 0
        }
    }
}

struct MainTabView_Previews: PreviewProvider {
    static var previews: some View {
        MainTabView()
    }
}
