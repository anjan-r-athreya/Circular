import SwiftUI
import MapKit

import SwiftUI

struct FavoritesView: View {
    @StateObject private var viewModel = FavoritesViewModel()
    @Environment(\.presentationMode) var presentationMode
    var onRouteSelected: ((Route) -> Void)?
    
    var body: some View {
        NavigationView {
            ZStack {
                // Background
                Color(.systemGroupedBackground)
                    .edgesIgnoringSafeArea(.all)
                
                // Content
                if viewModel.isLoading {
                    ProgressView("Loading your favorites...")
                } else if viewModel.favorites.isEmpty {
                    emptyStateView
                } else {
                    scrollableContentView
                }
            }
            .navigationTitle("Favorites")
            .refreshable {
                viewModel.loadFavorites()
            }
        }
    }
    
    private var scrollableContentView: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(viewModel.favorites) { route in
                    RouteCardView(route: route, viewModel: viewModel, onRouteTapped: { selectedRoute in
                        // Call the closure and dismiss this sheet
                        onRouteSelected?(selectedRoute)
                        presentationMode.wrappedValue.dismiss()
                    })
                }
                .padding(.vertical, 8)
            }
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "star.slash")
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            
            Text("No Favorite Routes")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Star a route to add it to your favorites")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
    }
}

struct FavoritesView_Previews: PreviewProvider {
    static var previews: some View {
        TabView {
            FavoritesView()
                .tabItem {
                    Label("Favorites", systemImage: "star.fill")
                }
        }
        
        // Preview the empty state
        TabView {
            FavoritesView(viewModel: {
                let vm = FavoritesViewModel()
                vm.favorites = []
                vm.isLoading = false
                return vm
            }())
                .tabItem {
                    Label("Favorites", systemImage: "star.fill")
                }
        }
        .preferredColorScheme(.dark)
    }
}

// Extension for preview purposes only
extension FavoritesView {
    init(viewModel: FavoritesViewModel) {
        self._viewModel = StateObject(wrappedValue: viewModel)
    }
}
