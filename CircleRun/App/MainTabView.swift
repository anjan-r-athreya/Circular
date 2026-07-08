//
//  MainTabView.swift
//  CircleRun
//
//  Created by Anjan Athreya on 5/17/25.
//

import SwiftUI

struct MainTabView: View {
    @State private var selectedTab: Int = 0

    init() {
        // Night Circuit chrome: near-black bar, comet-cyan selection.
        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor(red: 0.039, green: 0.055, blue: 0.078, alpha: 1)
        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
    }

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

            // Activity tab: run history, weekly mileage, streaks
            ActivityView()
                .tabItem {
                    Label("Activity", systemImage: "chart.bar.fill")
                }
                .tag(2)

            // Settings tab: pace and route preferences
            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gearshape.fill")
                }
                .tag(3)
        }
        .accentColor(Night.cyan)
        .preferredColorScheme(.dark)
        .onChange(of: selectedTab) { _ in
            Haptics.selection()
        }
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
