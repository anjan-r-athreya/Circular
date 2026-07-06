//
//  IntroView.swift
//  CircleRun
//
//  First-launch interactive intro. Each page's animation demonstrates one
//  selling point: smart loop generation, loop customization, scenic stops
//  woven into the route, and best-time tracking.
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
                IntroPage(
                    title: "Perfect loops,\nevery time",
                    subtitle: "CircleRun explores every direction from where you stand, then draws the cleanest loop — no dead ends, no retraced streets."
                ) { LoopSearchDemo() }
                .tag(0)

                IntroPage(
                    title: "Make it\nyours",
                    subtitle: "Dial in distance, terrain, and hills — watch the loop reshape itself around what you want from today's run."
                ) { CustomizeDemo() }
                .tag(1)

                IntroPage(
                    title: "Run somewhere\nbeautiful",
                    subtitle: "Parks, waterfronts, and landmarks near you appear as photo cards — pick your favorites and the loop bends to pass them."
                ) { ScenicWeaveDemo() }
                .tag(2)

                IntroPage(
                    title: "Chase your\nbest times",
                    subtitle: "Favorite the loops you love. Every finished run counts, and your three fastest stay on the podium."
                ) { PodiumDemo() }
                .tag(3)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))

            VStack {
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

                VStack(spacing: 24) {
                    HStack(spacing: 8) {
                        ForEach(0...lastPage, id: \.self) { index in
                            Capsule()
                                .fill(index == page
                                      ? MapboxMapInterface.Colors.primary
                                      : Color(white: 0.3))
                                .frame(width: index == page ? 22 : 8, height: 8)
                                .animation(.spring(response: 0.35, dampingFraction: 0.8), value: page)
                        }
                    }

                    if page == lastPage {
                        Button(action: onFinish) {
                            Text("Start Running")
                                .font(.headline)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(
                                    LinearGradient(colors: [MapboxMapInterface.Colors.primary, .cyan],
                                                   startPoint: .leading, endPoint: .trailing)
                                )
                                .cornerRadius(14)
                                .shadow(color: MapboxMapInterface.Colors.primary.opacity(0.5), radius: 14, y: 4)
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
                                .shadow(color: MapboxMapInterface.Colors.primary.opacity(0.5), radius: 12, y: 3)
                        }
                    }
                }
                .padding(.bottom, 40)
            }
        }
    }
}

// MARK: - Page scaffold with entrance motion

private struct IntroPage<Demo: View>: View {
    let title: String
    let subtitle: String
    @ViewBuilder let demo: () -> Demo

    @State private var appeared = false

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 56)

            ZStack {
                DemoBackdrop()
                demo()
            }
            .frame(height: 320)
            .scaleEffect(appeared ? 1 : 0.92)
            .opacity(appeared ? 1 : 0)

            Spacer(minLength: 30)

            VStack(spacing: 14) {
                Text(title)
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .foregroundColor(MapboxMapInterface.Colors.text)
                    .multilineTextAlignment(.center)
                    .offset(y: appeared ? 0 : 16)
                    .opacity(appeared ? 1 : 0)

                Text(subtitle)
                    .font(.body)
                    .foregroundColor(MapboxMapInterface.Colors.secondaryText)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 36)
                    .offset(y: appeared ? 0 : 16)
                    .opacity(appeared ? 1 : 0)
            }
            .animation(.spring(response: 0.7, dampingFraction: 0.85).delay(0.15), value: appeared)

            Spacer(minLength: 150)
        }
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.85)) {
                appeared = true
            }
        }
    }
}

/// Radial glow + vignetted street grid behind every demo, for depth.
private struct DemoBackdrop: View {
    var body: some View {
        ZStack {
            RadialGradient(
                colors: [MapboxMapInterface.Colors.primary.opacity(0.16), .clear],
                center: .center, startRadius: 10, endRadius: 220
            )

            IntroGrid()
                .mask(
                    RadialGradient(colors: [.white, .clear],
                                   center: .center, startRadius: 40, endRadius: 190)
                )
        }
    }
}

// MARK: - Shared loop geometry

private enum IntroGeometry {
    /// Closed smooth curve through the points (Catmull-Rom converted to Bézier).
    static func smoothClosedPath(through pts: [CGPoint]) -> Path {
        var path = Path()
        guard pts.count > 2 else { return path }
        let n = pts.count
        path.move(to: pts[0])
        for i in 0..<n {
            let p0 = pts[(i - 1 + n) % n]
            let p1 = pts[i]
            let p2 = pts[(i + 1) % n]
            let p3 = pts[(i + 2) % n]
            let c1 = CGPoint(x: p1.x + (p2.x - p0.x) / 6, y: p1.y + (p2.y - p0.y) / 6)
            let c2 = CGPoint(x: p2.x - (p3.x - p1.x) / 6, y: p2.y - (p3.y - p1.y) / 6)
            path.addCurve(to: p2, control1: c1, control2: c2)
        }
        path.closeSubpath()
        return path
    }

    static func point(index: Int, of count: Int, radius: CGFloat,
                      rotation: CGFloat, in rect: CGRect) -> CGPoint {
        let base = min(rect.width, rect.height) / 2
        let angle = 2 * .pi * CGFloat(index) / CGFloat(count) - .pi / 2 + rotation * .pi / 180
        return CGPoint(x: rect.midX + radius * base * cos(angle),
                       y: rect.midY + radius * base * sin(angle))
    }
}

/// A loop through polar control points that can morph between two radius
/// sets (and rotations) — the shape of every "route" in the intro.
private struct BlobLoopShape: Shape {
    var fromRadii: [CGFloat]
    var toRadii: [CGFloat]
    var fromRotation: CGFloat = 0
    var toRotation: CGFloat = 0
    var t: CGFloat

    var animatableData: CGFloat {
        get { t }
        set { t = newValue }
    }

    func path(in rect: CGRect) -> Path {
        let n = min(fromRadii.count, toRadii.count)
        let rotation = fromRotation + (toRotation - fromRotation) * t
        let pts = (0..<n).map { i -> CGPoint in
            let r = fromRadii[i] + (toRadii[i] - fromRadii[i]) * t
            return IntroGeometry.point(index: i, of: n, radius: r,
                                       rotation: rotation, in: rect)
        }
        return IntroGeometry.smoothClosedPath(through: pts)
    }
}

/// Neon route stroke: a blurred halo underneath a crisp gradient core.
private struct NeonLoop: View {
    var fromRadii: [CGFloat]
    var toRadii: [CGFloat]
    var fromRotation: CGFloat = 0
    var toRotation: CGFloat = 0
    var t: CGFloat
    var trim: CGFloat = 1
    var glow: CGFloat = 1

    private var gradient: AngularGradient {
        AngularGradient(
            colors: [MapboxMapInterface.Colors.primary, .cyan,
                     MapboxMapInterface.Colors.primary, .cyan,
                     MapboxMapInterface.Colors.primary],
            center: .center
        )
    }

    var body: some View {
        ZStack {
            shape.stroke(gradient, style: StrokeStyle(lineWidth: 11, lineCap: .round))
                .blur(radius: 12)
                .opacity(0.55 * glow)
            shape.stroke(gradient, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                .blur(radius: 3)
                .opacity(0.85 * glow)
            shape.stroke(gradient, style: StrokeStyle(lineWidth: 4.5, lineCap: .round, lineJoin: .round))
        }
    }

    private var shape: some Shape {
        BlobLoopShape(fromRadii: fromRadii, toRadii: toRadii,
                      fromRotation: fromRotation, toRotation: toRotation, t: t)
            .trim(from: 0, to: trim)
    }
}

// MARK: - Demo 1: the engine searching, then the winning loop

private struct LoopSearchDemo: View {
    private static let winner: [CGFloat] = [0.86, 0.66, 0.88, 0.70, 0.84, 0.72, 0.90, 0.64]
    private static let ghostRotations: [CGFloat] = [95, 205, 320]

    @State private var ghostTrims: [CGFloat] = [0, 0, 0]
    @State private var ghostsFaded = false
    @State private var winnerTrim: CGFloat = 0
    @State private var runner: CGFloat = 0.001
    @State private var runnerVisible = false
    @State private var chipShown = false
    @State private var pulse = false

    var body: some View {
        ZStack {
            // Candidate directions the engine "tries" and discards
            ForEach(0..<3, id: \.self) { i in
                BlobLoopShape(fromRadii: Self.winner, toRadii: Self.winner,
                              fromRotation: Self.ghostRotations[i],
                              toRotation: Self.ghostRotations[i], t: 1)
                    .trim(from: 0, to: ghostTrims[i])
                    .stroke(Color(white: 0.55),
                            style: StrokeStyle(lineWidth: 2.5, lineCap: .round, dash: [6, 7]))
                    .opacity(ghostsFaded ? 0.10 : 0.35)
                    .animation(.easeOut(duration: 0.8), value: ghostsFaded)
            }

            // The chosen route, drawn in neon
            NeonLoop(fromRadii: Self.winner, toRadii: Self.winner,
                     t: 1, trim: winnerTrim)

            // Comet: fading tail + bright head orbiting the loop
            comet

            // Pulsing start pin
            GeometryReader { geo in
                let start = IntroGeometry.point(index: 0, of: 8, radius: Self.winner[0],
                                                rotation: 0, in: CGRect(origin: .zero, size: geo.size))
                ZStack {
                    Circle()
                        .stroke(MapboxMapInterface.Colors.primary.opacity(0.7), lineWidth: 2)
                        .frame(width: 14, height: 14)
                        .scaleEffect(pulse ? 2.6 : 1)
                        .opacity(pulse ? 0 : 0.9)
                    Circle()
                        .fill(Color.white)
                        .frame(width: 13, height: 13)
                        .overlay(Circle().stroke(MapboxMapInterface.Colors.primary, lineWidth: 4))
                }
                .position(start)
            }

            // The one input the runner gave
            VStack {
                Spacer()
                Text("5.0 mi")
                    .font(.headline.monospacedDigit())
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 7)
                    .background(
                        Capsule().fill(Color(white: 0.14))
                            .overlay(Capsule().stroke(MapboxMapInterface.Colors.primary.opacity(0.5), lineWidth: 1))
                    )
                    .scaleEffect(chipShown ? 1 : 0.3)
                    .opacity(chipShown ? 1 : 0)
            }
        }
        .padding(.horizontal, 52)
        .padding(.vertical, 24)
        .onAppear(perform: run)
    }

    private var comet: some View {
        ZStack {
            BlobLoopShape(fromRadii: Self.winner, toRadii: Self.winner, t: 1)
                .trim(from: max(0, runner - 0.10), to: runner)
                .stroke(Color.white.opacity(0.25), style: StrokeStyle(lineWidth: 7, lineCap: .round))
            BlobLoopShape(fromRadii: Self.winner, toRadii: Self.winner, t: 1)
                .trim(from: max(0, runner - 0.045), to: runner)
                .stroke(Color.white.opacity(0.6), style: StrokeStyle(lineWidth: 8, lineCap: .round))
            BlobLoopShape(fromRadii: Self.winner, toRadii: Self.winner, t: 1)
                .trim(from: max(0, runner - 0.006), to: runner)
                .stroke(Color.white, style: StrokeStyle(lineWidth: 13, lineCap: .round))
                .shadow(color: .white, radius: 7)
        }
        .opacity(runnerVisible ? 1 : 0)
    }

    private func run() {
        // Ghost candidates sketch out one by one...
        for i in 0..<3 {
            withAnimation(.easeInOut(duration: 0.55).delay(Double(i) * 0.3)) {
                ghostTrims[i] = 1
            }
        }
        // ...the winner draws in neon while the ghosts dim...
        withAnimation(.easeInOut(duration: 1.8).delay(1.15)) { winnerTrim = 1 }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.15) { ghostsFaded = true }
        // ...then the runner takes off and keeps lapping.
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            runnerVisible = true
            withAnimation(.linear(duration: 4.5).repeatForever(autoreverses: false)) {
                runner = 1
            }
            withAnimation(.spring(response: 0.45, dampingFraction: 0.6)) { chipShown = true }
            withAnimation(.easeOut(duration: 1.6).repeatForever(autoreverses: false)) { pulse = true }
        }
    }
}

// MARK: - Demo 2: the loop reshaping to match preferences

private struct CustomizeDemo: View {
    private struct Variant {
        let radii: [CGFloat]
        let rotation: CGFloat
        let distance: String
        let terrain: String
        let terrainIcon: String
    }

    private static let variants: [Variant] = [
        Variant(radii: [0.62, 0.58, 0.63, 0.60, 0.61, 0.59, 0.62, 0.58],
                rotation: 0, distance: "3.0 mi", terrain: "Flat", terrainIcon: "minus"),
        Variant(radii: [0.84, 0.66, 0.88, 0.72, 0.82, 0.68, 0.86, 0.70],
                rotation: 40, distance: "5.0 mi", terrain: "Rolling", terrainIcon: "water.waves"),
        Variant(radii: [0.98, 0.62, 1.00, 0.58, 0.95, 0.74, 0.99, 0.55],
                rotation: -35, distance: "8.0 mi", terrain: "Hilly", terrainIcon: "mountain.2.fill"),
    ]

    @State private var step = 0
    @State private var from = Self.variants[0]
    @State private var to = Self.variants[0]
    @State private var t: CGFloat = 1
    @State private var chipBump = false

    var body: some View {
        VStack(spacing: 26) {
            NeonLoop(fromRadii: from.radii, toRadii: to.radii,
                     fromRotation: from.rotation, toRotation: to.rotation, t: t)
                .padding(.horizontal, 66)
                .padding(.top, 18)

            HStack(spacing: 10) {
                chip(icon: "figure.run", label: Self.variants[step].distance, highlighted: true)
                chip(icon: Self.variants[step].terrainIcon, label: Self.variants[step].terrain, highlighted: false)
                chip(icon: "leaf.fill", label: "Trails", highlighted: false)
            }
            .scaleEffect(chipBump ? 1.06 : 1)
        }
        .task {
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 2_600_000_000)
                guard !Task.isCancelled else { break }

                let next = (step + 1) % Self.variants.count
                from = Self.variants[step]
                to = Self.variants[next]
                t = 0
                await Task.yield()

                withAnimation(.spring(response: 0.9, dampingFraction: 0.75)) {
                    t = 1
                    step = next
                }
                withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) { chipBump = true }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) { chipBump = false }
                }
            }
        }
    }

    private func chip(icon: String, label: String, highlighted: Bool) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .semibold))
            Text(label)
                .font(.caption.weight(.semibold))
                .contentTransition(.numericText())
        }
        .foregroundColor(.white)
        .padding(.horizontal, 13)
        .padding(.vertical, 8)
        .background(
            Capsule()
                .fill(highlighted
                      ? MapboxMapInterface.Colors.primary.opacity(0.85)
                      : Color(white: 0.16))
                .overlay(Capsule().stroke(MapboxMapInterface.Colors.primary.opacity(highlighted ? 0.9 : 0.35), lineWidth: 1))
        )
    }
}

// MARK: - Demo 3: scenic pins landing and the loop bending to reach them

private struct ScenicWeaveDemo: View {
    private static let before: [CGFloat] = [0.68, 0.64, 0.70, 0.66, 0.69, 0.65, 0.68, 0.64]
    private static var after: [CGFloat] {
        var r = before
        r[1] = 0.98   // top-right — park
        r[4] = 0.96   // bottom — waterfront
        r[6] = 0.94   // left — monument
        return r
    }

    private static let pins: [(index: Int, icon: String, delay: Double)] = [
        (1, "leaf.fill", 0.30),
        (4, "water.waves", 0.70),
        (6, "building.columns.fill", 1.10),
    ]

    @State private var morphT: CGFloat = 0
    @State private var pinsShown = [false, false, false]
    @State private var ripples = [false, false, false]
    @State private var glowPulse: CGFloat = 1

    var body: some View {
        ZStack {
            NeonLoop(fromRadii: Self.before, toRadii: Self.after,
                     t: morphT, glow: glowPulse)

            GeometryReader { geo in
                let rect = CGRect(origin: .zero, size: geo.size)
                ForEach(Array(Self.pins.enumerated()), id: \.offset) { i, pin in
                    let target = IntroGeometry.point(index: pin.index, of: 8,
                                                     radius: Self.after[pin.index],
                                                     rotation: 0, in: rect)
                    let rippleScale: CGFloat = ripples[i] ? 2.8 : 0.4
                    let pinScale: CGFloat = pinsShown[i] ? 1 : 0.01
                    ZStack {
                        // Landing ripple
                        Circle()
                            .stroke(MapboxMapInterface.Colors.primary.opacity(0.8), lineWidth: 2)
                            .frame(width: 30, height: 30)
                            .scaleEffect(rippleScale)
                            .opacity(ripples[i] ? 0 : 0.9)
                            .animation(.easeOut(duration: 0.7), value: ripples[i])

                        IntroPhotoPin(icon: pin.icon)
                            .scaleEffect(pinScale, anchor: .bottom)
                            .offset(y: pinsShown[i] ? 0 : -60)
                            .animation(.spring(response: 0.5, dampingFraction: 0.62), value: pinsShown[i])
                    }
                    .position(x: target.x, y: target.y - 4)
                }
            }
        }
        .padding(.horizontal, 54)
        .padding(.vertical, 24)
        .onAppear(perform: run)
    }

    private func run() {
        for (i, pin) in Self.pins.enumerated() {
            DispatchQueue.main.asyncAfter(deadline: .now() + pin.delay) {
                pinsShown[i] = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + pin.delay + 0.28) {
                ripples[i] = true
            }
        }
        // The route bends out to collect the chosen spots, flaring as it goes.
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.9) {
            withAnimation(.spring(response: 1.0, dampingFraction: 0.72)) { morphT = 1 }
            withAnimation(.easeInOut(duration: 0.5)) { glowPulse = 1.8 }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
                withAnimation(.easeInOut(duration: 0.8)) { glowPulse = 1 }
            }
        }
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
                    .fill(
                        LinearGradient(colors: [MapboxMapInterface.Colors.primary.opacity(0.45), .cyan.opacity(0.25)],
                                       startPoint: .topLeading, endPoint: .bottomTrailing)
                    )
                    .frame(width: 44, height: 44)
                Image(systemName: icon)
                    .font(.system(size: 19, weight: .semibold))
                    .foregroundColor(.white)
            }
            Triangle()
                .fill(Color.white)
                .frame(width: 14, height: 9)
        }
        .shadow(color: .black.opacity(0.55), radius: 6, y: 3)
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

// MARK: - Demo 4: the podium, with a shine on gold

private struct PodiumDemo: View {
    @State private var risen = false
    @State private var shine = false

    private let bars: [(rank: String, time: String, height: CGFloat, color: Color, delay: Double, isGold: Bool)] = [
        ("2nd", "26:41", 120, Color(white: 0.75), 0.55, false),
        ("1st", "25:18", 175, .yellow, 0.25, true),
        ("3rd", "27:05", 90, Color(red: 0.8, green: 0.5, blue: 0.2), 0.85, false),
    ]

    var body: some View {
        HStack(alignment: .bottom, spacing: 18) {
            ForEach(bars.indices, id: \.self) { i in
                let bar = bars[i]
                VStack(spacing: 10) {
                    Image(systemName: "trophy.fill")
                        .font(.system(size: bar.isGold ? 28 : 22))
                        .foregroundColor(bar.color)
                        .shadow(color: bar.color.opacity(0.8), radius: bar.isGold ? 10 : 4)
                        .scaleEffect(risen ? 1 : 0.01)
                        .rotationEffect(.degrees(risen ? 0 : -30))
                        .animation(.spring(response: 0.45, dampingFraction: 0.55).delay(bar.delay + 0.4),
                                   value: risen)

                    Text(bar.time)
                        .font(.subheadline.monospacedDigit().weight(.semibold))
                        .foregroundColor(MapboxMapInterface.Colors.text)
                        .opacity(risen ? 1 : 0)
                        .animation(.easeIn(duration: 0.3).delay(bar.delay + 0.45), value: risen)

                    RoundedRectangle(cornerRadius: 10)
                        .fill(
                            LinearGradient(colors: [bar.color.opacity(0.95), bar.color.opacity(0.4)],
                                           startPoint: .top, endPoint: .bottom)
                        )
                        .overlay(alignment: .leading) {
                            if bar.isGold {
                                // Shine sweeping across the gold bar
                                LinearGradient(colors: [.clear, .white.opacity(0.65), .clear],
                                               startPoint: .leading, endPoint: .trailing)
                                    .frame(width: 36)
                                    .offset(x: shine ? 90 : -50)
                                    .blur(radius: 2)
                            }
                        }
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .frame(width: 76, height: risen ? bar.height : 8)
                        .shadow(color: bar.color.opacity(bar.isGold ? 0.5 : 0.25), radius: 12, y: 4)
                        .animation(.spring(response: 0.65, dampingFraction: 0.7).delay(bar.delay),
                                   value: risen)

                    Text(bar.rank)
                        .font(.caption.weight(.bold))
                        .foregroundColor(MapboxMapInterface.Colors.secondaryText)
                }
            }
        }
        .onAppear {
            risen = true
            withAnimation(.easeInOut(duration: 1.8).repeatForever(autoreverses: false).delay(1.4)) {
                shine = true
            }
        }
    }
}

// MARK: - Shared backdrop grid

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
            .stroke(Color(white: 0.24), lineWidth: 1)
        }
        .opacity(0.6)
    }
}

#Preview {
    IntroView(onFinish: {})
}
