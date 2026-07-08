//
//  RouteCardView.swift
//  CircleRun
//
//  A saved route in the Night Circuit language: its own neon loop, name,
//  run count, and best time — gold star to release it.
//

import SwiftUI
import MapKit

struct RouteCardView: View {
    let route: Route
    @ObservedObject var viewModel: FavoritesViewModel

    var body: some View {
        NavigationLink(destination: RouteDetailView(route: route)) {
            GlowCard {
                HStack(spacing: 12) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 14)
                            .fill(Night.panelDeep)
                            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Night.line, lineWidth: 1))
                        NeonTraceView(coordinates: route.path, color: Night.blue, lineWidth: 2)
                            .padding(5)
                    }
                    .frame(width: 58, height: 58)

                    VStack(alignment: .leading, spacing: 3) {
                        Text(route.name)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(Night.text)
                            .lineLimit(1)

                        HStack(spacing: 10) {
                            HStack(spacing: 4) {
                                Image(systemName: "figure.run")
                                    .font(.system(size: 10))
                                    .foregroundColor(Night.cyan)
                                Text("\(route.runCount)")
                                    .font(.system(size: 12, design: .monospaced))
                                    .foregroundColor(Night.dim)
                            }
                            HStack(spacing: 4) {
                                Image(systemName: "stopwatch")
                                    .font(.system(size: 10))
                                    .foregroundColor(Night.cyan)
                                Text(route.bestTime > 0 ? viewModel.formatTime(route.bestTime) : "—")
                                    .font(.system(size: 12, design: .monospaced))
                                    .foregroundColor(Night.dim)
                            }
                        }

                        Text(String(format: "%.2f mi", route.distance))
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundColor(Night.faint)
                    }

                    Spacer()

                    Button(action: {
                        viewModel.toggleFavorite(route: route)
                    }) {
                        Image(systemName: "star.fill")
                            .foregroundColor(Night.gold)
                            .font(.system(size: 19))
                            .shadow(color: Night.gold.opacity(0.6), radius: 6)
                            .padding(6)
                    }
                    .buttonStyle(BorderlessButtonStyle())
                }
            }
        }
    }
}

struct RouteCardView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            RouteCardView(route: Route.sample(), viewModel: FavoritesViewModel())
                .padding()
                .background(Night.ground)
        }
    }
}
