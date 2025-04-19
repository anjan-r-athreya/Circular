import SwiftUI
import MapKit

struct FavoritesView: View {
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            ZStack {
                Color(MapOverlayStyle.polylineColor)
                    .ignoresSafeArea()
                
                Text("Favorites")
                    .foregroundColor(.white)
            }
            .navigationBarItems(leading: Button(action: {
                dismiss()
            }) {
                Image(systemName: "xmark")
                    .foregroundColor(.white)
            })
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

#Preview {
    FavoritesView()
}