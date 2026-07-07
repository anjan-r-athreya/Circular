import SwiftUI
import MapKit

struct MapSnapshotView: View {
    let coordinates: [CLLocationCoordinate2D]
    let size: CGSize
    let lineColor: Color
    
    @State private var snapshot: UIImage?
    
    init(coordinates: [CLLocationCoordinate2D],
         size: CGSize = CGSize(width: 120, height: 120),
         lineColor: Color = .blue) {
        self.coordinates = coordinates
        self.size = size
        self.lineColor = lineColor
    }
    
    var body: some View {
        ZStack {
            if let snapshot = snapshot {
                Image(uiImage: snapshot)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                Rectangle()
                    .fill(Color(.systemGray6))
                    .overlay {
                        ProgressView()
                    }
            }
        }
        .frame(width: size.width, height: size.height)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .onAppear {
            createSnapshot()
        }
    }
    
    private func createSnapshot() {
        guard !coordinates.isEmpty else { return }
        
        // Create a polyline from coordinates
        let polyline = MKPolyline(coordinates: coordinates, count: coordinates.count)
        
        // Calculate region that fits all coordinates with padding
        let mapRect = polyline.boundingMapRect
        let region = MKCoordinateRegion(mapRect.insetBy(dx: -mapRect.width * 0.2, dy: -mapRect.height * 0.2))
        
        // Create snapshot options
        let options = MKMapSnapshotter.Options()
        options.region = region
        options.size = size
        options.showsBuildings = true
        
        if UITraitCollection.current.userInterfaceStyle == .dark {
            options.mapType = .mutedStandard
        } else {
            options.mapType = .standard
        }
        
        // Create snapshotter
        let snapshotter = MKMapSnapshotter(options: options)
        
        // Take snapshot
        snapshotter.start { result, error in
            guard error == nil else {
                return
            }
            
            guard let mapSnapshot = result else {
                return
            }
            
            // Draw route line on snapshot
            UIGraphicsBeginImageContextWithOptions(size, true, 0)
            mapSnapshot.image.draw(at: .zero)
            
            let context = UIGraphicsGetCurrentContext()!
            context.setLineWidth(3.0)
            context.setStrokeColor(UIColor(lineColor).cgColor)
            
            // Convert map coordinates to points on the snapshot image
            let points = coordinates.map { coordinate -> CGPoint in
                return mapSnapshot.point(for: coordinate)
            }
            
            if !points.isEmpty {
                context.move(to: points[0])
                for point in points.dropFirst() {
                    context.addLine(to: point)
                }
                context.strokePath()
            }
            
            let finalImage = UIGraphicsGetImageFromCurrentImageContext()
            UIGraphicsEndImageContext()
            
            DispatchQueue.main.async {
                self.snapshot = finalImage
            }
        }
    }
}

struct MapSnapshotView_Previews: PreviewProvider {
    static var previews: some View {
        MapSnapshotView(coordinates: Route.sample().path)
            .frame(width: 150, height: 150)
            .padding()
            .previewLayout(.sizeThatFits)
    }
}
