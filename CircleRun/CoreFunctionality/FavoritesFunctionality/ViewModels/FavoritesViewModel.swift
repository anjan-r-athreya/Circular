//
//  FavoritesViewModel.swift
//  CircleRun
//
//  Created by Anjan Athreya on 5/17/25.
//

import Foundation
import Combine
import MapKit

class FavoritesViewModel: ObservableObject {
    @Published var favorites: [Route] = []
    @Published var isLoading = true
    @Published var errorMessage: String?
    
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        loadFavorites()
        
        // Listen for changes to favorites
        NotificationCenter.default.publisher(for: Notification.Name("FavoritesUpdated"))
            .sink { [weak self] _ in
                self?.loadFavorites()
            }
            .store(in: &cancellables)
    }
    
    func loadFavorites() {
        isLoading = true
        
        // Load favorites from UserDefaults
        if let savedData = UserDefaults.standard.object(forKey: "savedFavorites") as? [Data] {
            var loadedFavorites: [Route] = []
            
            for data in savedData {
                if let route = try? JSONDecoder().decode(Route.self, from: data) {
                    loadedFavorites.append(route)
                }
            }
            
            DispatchQueue.main.async {
                self.favorites = loadedFavorites
                self.isLoading = false
            }
        } else {
            // If no saved favorites, use sample data in development
            #if DEBUG
            DispatchQueue.main.async {
                self.favorites = Route.samples
                self.isLoading = false
            }
            #else
            DispatchQueue.main.async {
                self.favorites = []
                self.isLoading = false
            }
            #endif
        }
    }
    
    func formatTime(_ timeInterval: TimeInterval) -> String {
        let minutes = Int(timeInterval) / 60
        let seconds = Int(timeInterval) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
    
    func toggleFavorite(route: Route) {
        if let index = favorites.firstIndex(where: { $0.id == route.id }) {
            // Remove from favorites
            favorites.remove(at: index)
            
            // Update UserDefaults
            var savedData: [Data] = []
            for route in favorites {
                if let encoded = try? JSONEncoder().encode(route) {
                    savedData.append(encoded)
                }
            }
            UserDefaults.standard.set(savedData, forKey: "savedFavorites")
            NotificationCenter.default.post(name: Notification.Name("FavoritesUpdated"), object: nil)
        }
    }
}


//import Foundation
//import Combine
//import MapKit
//
//class FavoritesViewModel: ObservableObject {
//    static let shared = FavoritesViewModel() // <-- Singleton instance
//    
//    @Published var favorites: [Route] = []
//    @Published var isLoading = true
//    @Published var errorMessage: String?
//    
//    private var cancellables = Set<AnyCancellable>()
//    
//    init() {
//        loadFavorites()
//    }
//    
//    func loadFavorites() {
//        // In a real app, this would fetch from CoreData, UserDefaults, or a network API
//        // For now, we'll just simulate a delay and load sample data
//        isLoading = true
//        
//        // Simulate network delay
//        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
//            guard let self = self else { return }
//            
//            // In a real app, replace this with actual data fetching code
//            self.favorites = Route.samples
//            self.isLoading = false
//        }
//    }
//    
//    func formatTime(_ timeInterval: TimeInterval) -> String {
//        let minutes = Int(timeInterval) / 60
//        let seconds = Int(timeInterval) % 60
//        return String(format: "%d:%02d", minutes, seconds)
//    }
//    
//    // In a real app, you might have methods to add/remove favorites
//    func toggleFavorite(route: Route) {
//        if favorites.contains(where: { $0.id == route.id }) {
//            favorites.removeAll(where: { $0.id == route.id })
//        } else {
//            favorites.append(route)
//        }
//        // In a real app, you would save this change to persistent storage
//    }
//}
