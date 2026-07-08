import SwiftUI
import MapKit

struct FavoritesView: View {
    @StateObject private var viewModel = FavoritesViewModel()
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Background
                Night.ground
                    .edgesIgnoringSafeArea(.all)
                
                // Content
                if viewModel.isLoading {
                    ProgressView("Loading your favorites...")
                } else if viewModel.favorites.isEmpty {
                    emptyStateView
                } else {
                    ScrollView {
                        LazyVStack(spacing: 10) {
                            ForEach(Array(viewModel.favorites.enumerated()), id: \.element.id) { index, route in
                                RouteCardView(route: route, viewModel: viewModel)
                                    .staggeredAppear(index: index)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                    }
                }
            }
            .navigationTitle("Favorites")
            .toolbarBackground(Night.ground, for: .navigationBar)
            .preferredColorScheme(.dark)
            .refreshable {
                viewModel.loadFavorites()
            }
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 18) {
            NeonTraceView(coordinates: Route.sample().path, color: Night.gold, lineWidth: 2.4)
                .frame(width: 110, height: 110)
                .opacity(0.9)

            Text("No Favorite Routes")
                .font(.system(size: 22, weight: .heavy, design: .rounded))
                .foregroundColor(Night.text)

            Text("Star a loop you love and it lives here, keeping your best times.")
                .font(.system(size: 14))
                .foregroundColor(Night.dim)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 44)
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
