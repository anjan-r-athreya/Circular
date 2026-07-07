//
//  ScenicSpotCardView.swift
//  CircleRun
//
//  Suggestion card shown while generating a loop: a satellite image of a
//  nearby scenic spot the runner can add as a stop, styled after the
//  favorites route cards.
//

import SwiftUI
import MapKit

struct ScenicSpotCardView: View {
    let spot: ScenicSpot
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 16) {
                SpotImageView(spot: spot)
                    .frame(width: 100, height: 100)
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                VStack(alignment: .leading, spacing: 6) {
                    Text(spot.name)
                        .font(.headline)
                        .foregroundColor(MapboxMapInterface.Colors.text)
                        .multilineTextAlignment(.leading)
                        .lineLimit(2)

                    Label {
                        Text("\(spot.distanceMilesText) away")
                            .foregroundColor(MapboxMapInterface.Colors.secondaryText)
                    } icon: {
                        Image(systemName: spot.icon)
                            .foregroundColor(MapboxMapInterface.Colors.primary)
                    }
                    .font(.subheadline)
                }

                Spacer()

                Image(systemName: isSelected ? "checkmark.circle.fill" : "plus.circle")
                    .font(.system(size: 26))
                    .foregroundColor(isSelected
                        ? MapboxMapInterface.Colors.primary
                        : MapboxMapInterface.Colors.secondaryText)
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(MapboxMapInterface.Colors.controlBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(isSelected ? MapboxMapInterface.Colors.primary : .clear, lineWidth: 2)
                    )
            )
        }
        .buttonStyle(.plain)
    }
}

/// A real photograph of the spot (Wikipedia, then Look Around street imagery,
/// then satellite), resolved asynchronously and cached by SpotPhotoService.
struct SpotImageView: View {
    let spot: ScenicSpot

    @State private var image: UIImage?

    var body: some View {
        ZStack {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                Rectangle()
                    .fill(Color(white: 0.2))
                    .overlay { ProgressView() }
            }
        }
        .task {
            image = await SpotPhotoService.shared.photo(
                for: spot,
                size: CGSize(width: 200, height: 200)
            )
        }
    }
}

#Preview {
    VStack {
        ScenicSpotCardView(
            spot: ScenicSpot(id: "1", name: "Golden Gate Park", icon: "leaf.fill",
                             latitude: 37.7694, longitude: -122.4862,
                             distanceFromStart: 1800),
            isSelected: true
        ) {}
        ScenicSpotCardView(
            spot: ScenicSpot(id: "2", name: "Ocean Beach", icon: "water.waves",
                             latitude: 37.7594, longitude: -122.5107,
                             distanceFromStart: 3300),
            isSelected: false
        ) {}
    }
    .padding()
    .background(Color.black)
}
