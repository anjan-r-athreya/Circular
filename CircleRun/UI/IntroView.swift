//
//  IntroView.swift
//  CircleRun
//
//  First-launch interactive intro. Each page's animation demonstrates one
//  capability of the app: loop generation, scenic stops, 3D/2D run
//  navigation, and best-time tracking.
//

import SwiftUI

struct IntroView: View {
    let onFinish: () -> Void

    @State private var page = 0
    private let lastPage = 3

    var body: some View {
        ZStack {
            MapboxMapInterface.Colors.background
                .ignoresSafeArea()

            TabView(selection: $page) {
                loopPage.tag(0)
                spotsPage.tag(1)
                navigationPage.tag(2)
                bestTimesPage.tag(3)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))

            VStack {
                // Skip — always available until the last page
                HStack {
                    Spacer()
                    if page < lastPage {
                        Button("Skip") { onFinish() }
                            .font(.subheadline.weight(.medium))
                            .foregroundColor(MapboxMapInterface.Colors.secondaryText)
                            .padding()
                    }
                }
                Spacer()

                // Page dots + advance
                VStack(spacing: 24) {
                    HStack(spacing: 8) {
                        ForEach(0...lastPage, id: \.self) { index in
                            Circle()
                                .fill(index == page
                                      ? MapboxMapInterface.Colors.primary
                                      : Color(white: 0.3))
                                .frame(width: 8, height: 8)
                        }
                    }

                    if page == lastPage {
                        Button(action: onFinish) {
                            Text("Start Running")
                                .font(.headline)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(MapboxMapInterface.Colors.primary)
                                .cornerRadius(14)
                        }
                        .padding(.horizontal, 32)
                    } else {
                        Button(action: {
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                                page += 1
                            }
                        }) {
                            Image(systemName: "arrow.right")
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundColor(.white)
                                .frame(width: 56, height: 56)
                                .background(MapboxMapInterface.Colors.primary)
                                .clipShape(Circle())
                        }
                    }
                }
                .padding(.bottom, 40)
            }
        }
    }

    // MARK: - Page 1: loop generation

    private var loopPage: some View {
        IntroPage(
            title: "Perfect loops,\nevery time",
            subtitle: "Pick a distance and get a continuous running loop from right where you stand. No dead ends. No retraced streets."
        ) {
            LoopDrawDemo()
        }
    }

    // MARK: - Page 2: scenic spots

    private var spotsPage: some View {
        IntroPage(
            title: "Run somewhere\nbeautiful",
            subtitle: "Parks, waterfronts, and landmarks near you appear as photo cards — tap the ones you want and they're woven into your route."
        ) {
            ScenicPinsDemo()
        }
    }

    // MARK: - Page 3: 3D navigation

    private var navigationPage: some View {
        IntroPage(
            title: "Navigate in 3D.\nOr 2D.",
            subtitle: "Turn-by-turn guidance with a chase camera you control — pinch, pan, or flatten the view mid-run."
        ) {
            CameraTiltDemo()
        }
    }

    // MARK: - Page 4: best times

    private var bestTimesPage: some View {
        IntroPage(
            title: "Chase your\nbest times",
            subtitle: "Favorite the loops you love. Every finished run counts, and your three fastest stay on the podium."
        ) {
            PodiumDemo()
        }
    }
}

// MARK: - Shared page scaffold

private struct IntroPage<Demo: View>: View {
    let title: String
    let subtitle: String
    @ViewBuilder let demo: () -> Demo

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 60)

            demo()
                .frame(height: 300)

            Spacer(minLength: 32)

            VStack(spacing: 14) {
                Text(title)
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundColor(MapboxMapInterface.Colors.text)
                    .multilineTextAlignment(.center)

                Text(subtitle)
                    .font(.body)
                    .foregroundColor(MapboxMapInterface.Colors.secondaryText)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 36)
            }

            Spacer(minLength: 140)
        }
    }
}

// MARK: - Demo 1: a loop drawing itself with a runner at its head

private struct RouteLoopShape: Shape {
    func path(in rect: CGRect) -> Path {
        let w = rect.width, h = rect.height
        var p = Path()
        p.move(to: CGPoint(x: 0.50 * w, y: 0.92 * h))
        p.addCurve(to: CGPoint(x: 0.10 * w, y: 0.55 * h),
                   control1: CGPoint(x: 0.22 * w, y: 0.92 * h),
                   control2: CGPoint(x: 0.08 * w, y: 0.78 * h))
        p.addCurve(to: CGPoint(x: 0.32 * w, y: 0.12 * h),
                   control1: CGPoint(x: 0.12 * w, y: 0.30 * h),
                   control2: CGPoint(x: 0.18 * w, y: 0.14 * h))
        p.addCurve(to: CGPoint(x: 0.88 * w, y: 0.30 * h),
                   control1: CGPoint(x: 0.52 * w, y: 0.09 * h),
                   control2: CGPoint(x: 0.82 * w, y: 0.12 * h))
        p.addCurve(to: CGPoint(x: 0.50 * w, y: 0.92 * h),
                   control1: CGPoint(x: 0.96 * w, y: 0.55 * h),
                   control2: CGPoint(x: 0.78 * w, y: 0.92 * h))
        p.closeSubpath()
        return p
    }
}

private struct LoopDrawDemo: View {
    @State private var drawn: CGFloat = 0
    @State private var runner: CGFloat = 0.001

    var body: some View {
        ZStack {
            // Faint street grid so the loop reads as a route on a map
            IntroGrid()

            // The traced route
            RouteLoopShape()
                .trim(from: 0, to: drawn)
                .stroke(MapboxMapInterface.Colors.primary,
                        style: StrokeStyle(lineWidth: 5, lineCap: .round, lineJoin: .round))
                .shadow(color: MapboxMapInterface.Colors.primary.opacity(0.6), radius: 8)

            // Runner: a dot orbiting the loop once it's drawn
            RouteLoopShape()
                .trim(from: max(0, runner - 0.004), to: runner)
                .stroke(Color.white, style: StrokeStyle(lineWidth: 14, lineCap: .round))
                .shadow(color: .white.opacity(0.8), radius: 6)
                .opacity(drawn > 0.99 ? 1 : 0)

            // Start pin
            GeometryReader { geo in
                Circle()
                    .fill(Color.white)
                    .frame(width: 14, height: 14)
                    .overlay(Circle().stroke(MapboxMapInterface.Colors.primary, lineWidth: 4))
                    .position(x: 0.50 * geo.size.width, y: 0.92 * geo.size.height)
            }

            // Distance chip, the "ask" the loop answers
            VStack {
                Spacer()
                Text("5.0 mi")
                    .font(.headline.monospacedDigit())
                    .foregroundColor(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 6)
                    .background(Capsule().fill(Color(white: 0.15)))
                    .opacity(drawn > 0.99 ? 1 : 0)
                    .animation(.easeIn(duration: 0.4), value: drawn)
            }
        }
        .padding(.horizontal, 48)
        .onAppear {
            withAnimation(.easeInOut(duration: 2.2)) { drawn = 1 }
            withAnimation(.linear(duration: 5).repeatForever(autoreverses: false).delay(2.2)) {
                runner = 1
            }
        }
    }
}

// MARK: - Demo 2: scenic photo pins popping onto the route

private struct ScenicPinsDemo: View {
    @State private var shown = false

    private let pins: [(icon: String, x: CGFloat, y: CGFloat, delay: Double)] = [
        ("leaf.fill", 0.24, 0.22, 0.4),
        ("water.waves", 0.85, 0.38, 0.8),
        ("building.columns.fill", 0.32, 0.85, 1.2),
    ]

    var body: some View {
        ZStack {
            IntroGrid()

            RouteLoopShape()
                .stroke(MapboxMapInterface.Colors.primary.opacity(0.85),
                        style: StrokeStyle(lineWidth: 4, lineCap: .round, dash: [1, 9]))

            GeometryReader { geo in
                ForEach(pins.indices, id: \.self) { i in
                    let pin = pins[i]
                    IntroPhotoPin(icon: pin.icon)
                        .position(x: pin.x * geo.size.width, y: pin.y * geo.size.height)
                        .scaleEffect(shown ? 1 : 0.01, anchor: .bottom)
                        .animation(.spring(response: 0.45, dampingFraction: 0.6).delay(pin.delay),
                                   value: shown)
                }
            }
        }
        .padding(.horizontal, 48)
        .onAppear { shown = true }
    }
}

/// Miniature of the photo markers the app pins on real routes.
private struct IntroPhotoPin: View {
    let icon: String

    var body: some View {
        VStack(spacing: -2) {
            ZStack {
                Circle()
                    .fill(Color.white)
                    .frame(width: 52, height: 52)
                Circle()
                    .fill(MapboxMapInterface.Colors.primary.opacity(0.25))
                    .frame(width: 44, height: 44)
                Image(systemName: icon)
                    .font(.system(size: 19, weight: .semibold))
                    .foregroundColor(MapboxMapInterface.Colors.primary)
            }
            Triangle()
                .fill(Color.white)
                .frame(width: 14, height: 9)
        }
        .shadow(color: .black.opacity(0.5), radius: 5, y: 2)
    }
}

private struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.minX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
        p.closeSubpath()
        return p
    }
}

// MARK: - Demo 3: the run camera tilting between 3D and 2D

private struct CameraTiltDemo: View {
    @State private var is3D = true

    var body: some View {
        VStack(spacing: 20) {
            ZStack {
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color(white: 0.12))
                    .overlay(IntroGrid().clipShape(RoundedRectangle(cornerRadius: 20)))

                RouteLoopShape()
                    .stroke(MapboxMapInterface.Colors.primary,
                            style: StrokeStyle(lineWidth: 5, lineCap: .round))
                    .padding(28)

                // Runner puck
                Circle()
                    .fill(Color.white)
                    .frame(width: 16, height: 16)
                    .overlay(Circle().stroke(MapboxMapInterface.Colors.primary, lineWidth: 5))
                    .offset(y: 74)
            }
            .frame(width: 250, height: 220)
            .rotation3DEffect(.degrees(is3D ? 55 : 0),
                              axis: (x: 1, y: 0, z: 0),
                              perspective: 0.55)
            .animation(.easeInOut(duration: 1.2), value: is3D)

            // The mode chip mirrors the buttons in the real run view
            HStack(spacing: 8) {
                Image(systemName: is3D ? "view.3d" : "view.2d")
                Text(is3D ? "3D chase camera" : "2D overhead")
            }
            .font(.subheadline.weight(.semibold))
            .foregroundColor(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Capsule().fill(Color(white: 0.15)))
        }
        .task {
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 2_200_000_000)
                is3D.toggle()
            }
        }
    }
}

// MARK: - Demo 4: the best-times podium rising

private struct PodiumDemo: View {
    @State private var risen = false

    private let bars: [(rank: String, time: String, height: CGFloat, color: Color, delay: Double)] = [
        ("2nd", "26:41", 120, Color(white: 0.75), 0.55),
        ("1st", "25:18", 170, .yellow, 0.25),
        ("3rd", "27:05", 90, Color(red: 0.8, green: 0.5, blue: 0.2), 0.85),
    ]

    var body: some View {
        HStack(alignment: .bottom, spacing: 18) {
            ForEach(bars.indices, id: \.self) { i in
                let bar = bars[i]
                VStack(spacing: 10) {
                    Image(systemName: "trophy.fill")
                        .font(.system(size: 22))
                        .foregroundColor(bar.color)
                        .opacity(risen ? 1 : 0)
                        .animation(.easeIn(duration: 0.3).delay(bar.delay + 0.35), value: risen)

                    Text(bar.time)
                        .font(.subheadline.monospacedDigit().weight(.semibold))
                        .foregroundColor(MapboxMapInterface.Colors.text)
                        .opacity(risen ? 1 : 0)
                        .animation(.easeIn(duration: 0.3).delay(bar.delay + 0.35), value: risen)

                    RoundedRectangle(cornerRadius: 10)
                        .fill(
                            LinearGradient(
                                colors: [bar.color.opacity(0.9), bar.color.opacity(0.45)],
                                startPoint: .top, endPoint: .bottom
                            )
                        )
                        .frame(width: 74, height: risen ? bar.height : 8)
                        .animation(.spring(response: 0.6, dampingFraction: 0.75).delay(bar.delay),
                                   value: risen)

                    Text(bar.rank)
                        .font(.caption.weight(.bold))
                        .foregroundColor(MapboxMapInterface.Colors.secondaryText)
                }
            }
        }
        .onAppear { risen = true }
    }
}

// MARK: - Shared backdrop

/// Faint street grid that makes the demos read as maps.
private struct IntroGrid: View {
    var body: some View {
        GeometryReader { geo in
            Path { p in
                let step: CGFloat = 34
                var x: CGFloat = 0
                while x <= geo.size.width {
                    p.move(to: CGPoint(x: x, y: 0))
                    p.addLine(to: CGPoint(x: x, y: geo.size.height))
                    x += step
                }
                var y: CGFloat = 0
                while y <= geo.size.height {
                    p.move(to: CGPoint(x: 0, y: y))
                    p.addLine(to: CGPoint(x: geo.size.width, y: y))
                    y += step
                }
            }
            .stroke(Color(white: 0.22), lineWidth: 1)
        }
        .opacity(0.5)
    }
}

#Preview {
    IntroView(onFinish: {})
}
