//
//  ElevationProfileView.swift
//  CircleRun
//
//  Compact elevation strip for a route: filled area chart of the profile
//  with gain / terrain / difficulty summarized underneath.
//

import SwiftUI

struct ElevationProfileView: View {
    /// Elevation samples in meters, evenly spaced along the route.
    let elevations: [Double]
    /// Route length in miles, for the terrain/difficulty classifications.
    let miles: Double

    private var gainMeters: Double {
        ElevationService.gainMeters(ofProfile: elevations)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            chart
                .frame(height: 44)

            HStack(spacing: 12) {
                Label(String(format: "%.0f ft", gainMeters * 3.28084),
                      systemImage: "arrow.up.right")
                Text(ElevationService.terrainDescription(gainMeters: gainMeters, miles: miles))
                Text(ElevationService.difficultyDescription(gainMeters: gainMeters, miles: miles))
            }
            .font(.caption.weight(.medium))
            .foregroundColor(MapboxMapInterface.Colors.secondaryText)
        }
    }

    private var chart: some View {
        GeometryReader { geo in
            let points = normalizedPoints(in: geo.size)
            ZStack {
                // Filled area under the profile
                Path { p in
                    guard let first = points.first else { return }
                    p.move(to: CGPoint(x: first.x, y: geo.size.height))
                    points.forEach { p.addLine(to: $0) }
                    p.addLine(to: CGPoint(x: points[points.count - 1].x, y: geo.size.height))
                    p.closeSubpath()
                }
                .fill(
                    LinearGradient(
                        colors: [MapboxMapInterface.Colors.primary.opacity(0.35),
                                 MapboxMapInterface.Colors.primary.opacity(0.05)],
                        startPoint: .top, endPoint: .bottom
                    )
                )

                // Profile line on top
                Path { p in
                    guard let first = points.first else { return }
                    p.move(to: first)
                    points.dropFirst().forEach { p.addLine(to: $0) }
                }
                .stroke(MapboxMapInterface.Colors.primary,
                        style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round))
            }
        }
    }

    /// Profile mapped into the view, with a floor on the vertical span so a
    /// pancake-flat route draws as a calm line instead of amplified noise.
    private func normalizedPoints(in size: CGSize) -> [CGPoint] {
        guard elevations.count > 1,
              let lo = elevations.min(), let hi = elevations.max() else { return [] }
        let span = max(hi - lo, 15)
        let inset: CGFloat = 3

        return elevations.enumerated().map { i, elevation in
            let x = size.width * CGFloat(i) / CGFloat(elevations.count - 1)
            let t = (elevation - lo) / span
            let y = inset + (size.height - 2 * inset) * CGFloat(1 - t)
            return CGPoint(x: x, y: y)
        }
    }
}

#Preview {
    ElevationProfileView(
        elevations: [12, 14, 18, 25, 31, 28, 22, 26, 35, 40, 38, 30, 22, 16, 12],
        miles: 5.0
    )
    .padding()
    .background(MapboxMapInterface.Colors.background)
}
