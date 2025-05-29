import SwiftUI
import MapKit

struct FavoritesView: View {
    @StateObject private var viewModel = FavoritesViewModel()
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationStack {
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
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(viewModel.favorites) { route in
                                RouteCardView(route: route, viewModel: viewModel)
                            }
                        }
                        .padding(.vertical, 8)
                    }
                }
            }
            .navigationTitle("Favorites")
            .refreshable {
                viewModel.loadFavorites()
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

#Preview {
    FavoritesView()
}

// Extension for preview purposes only
extension FavoritesView {
    init(viewModel: FavoritesViewModel) {
        self._viewModel = StateObject(wrappedValue: viewModel)
    }
}
