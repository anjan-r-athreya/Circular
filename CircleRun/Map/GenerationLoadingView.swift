//
//  GenerationLoadingView.swift
//  CircleRun
//
//  The loading overlay for route generation and spot discovery: a neon
//  arc sweeping around a pulsing runner — the same visual language as the
//  intro's loop scenes — with the generator's live stage messages
//  animating through underneath.
//

import SwiftUI

struct GenerationLoadingView: View {
    let message: String

    @State private var sweeping = false
    @State private var pulsing = false

    var body: some View {
        ZStack {
            MapboxMapInterface.Colors.overlay

            VStack(spacing: MapboxMapInterface.Layout.spacing.large) {
                ZStack {
                    // Track the arc runs on
                    Circle()
                        .stroke(MapboxMapInterface.Colors.primary.opacity(0.15), lineWidth: 5)
                        .frame(width: 68, height: 68)

                    // Neon arc, always lapping
                    Circle()
                        .trim(from: 0, to: 0.38)
                        .stroke(
                            AngularGradient(colors: [MapboxMapInterface.Colors.primary, .cyan],
                                            center: .center),
                            style: StrokeStyle(lineWidth: 5, lineCap: .round)
                        )
                        .frame(width: 68, height: 68)
                        .rotationEffect(.degrees(sweeping ? 360 : 0))
                        .shadow(color: MapboxMapInterface.Colors.primary.opacity(0.6), radius: 6)
                        .animation(.linear(duration: 1.1).repeatForever(autoreverses: false),
                                   value: sweeping)

                    Image(systemName: "figure.run")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundColor(.white)
                        .scaleEffect(pulsing ? 1.1 : 0.92)
                        .animation(.easeInOut(duration: 0.7).repeatForever(autoreverses: true),
                                   value: pulsing)
                }

                // Stage messages slide up through a fixed window as the
                // generator reports progress.
                Text(message)
                    .font(MapboxMapInterface.Typography.headline)
                    .foregroundColor(MapboxMapInterface.Colors.text)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .frame(minHeight: 44)
                    .id(message)
                    .transition(.asymmetric(
                        insertion: .move(edge: .bottom).combined(with: .opacity),
                        removal: .move(edge: .top).combined(with: .opacity)
                    ))
            }
            .padding(28)
            .frame(maxWidth: 300)
            .background(
                MapboxMapInterface.Colors.controlBackground
                    .overlay(
                        RoundedRectangle(cornerRadius: MapboxMapInterface.Layout.cornerRadius.medium)
                            .stroke(MapboxMapInterface.Colors.primary.opacity(0.3), lineWidth: 1)
                    )
            )
            .cornerRadius(MapboxMapInterface.Layout.cornerRadius.medium)
            .shadow(
                color: MapboxMapInterface.Shadows.glow.color,
                radius: MapboxMapInterface.Shadows.glow.radius,
                x: MapboxMapInterface.Shadows.glow.x,
                y: MapboxMapInterface.Shadows.glow.y
            )
            .animation(.themeEntrance, value: message)
        }
        .ignoresSafeArea()
        .onAppear {
            sweeping = true
            pulsing = true
        }
    }
}

#Preview {
    GenerationLoadingView(message: "Exploring northeast…")
}
