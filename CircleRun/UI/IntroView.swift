//
//  IntroView.swift
//  CircleRun
//
//  First-launch interactive intro. Slides 1–3 are full-screen pseudo-3D
//  scenes (extruded buildings, terrain, an orbiting/breathing camera)
//  rendered procedurally in Canvas; every animation is a pure function of
//  elapsed time. Slide 4 is the best-times podium.
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
                    subtitle: "CircleRun explores every direction from where you stand, then draws the cleanest loop — no dead ends, no retraced streets.",
                    fullBleed: true
                ) { CityLoopScene() }
                .tag(0)

                IntroPage(
                    title: "Make it\nyours",
                    subtitle: "Dial in distance, terrain, and hills — watch the loop reshape itself around what you want from today's run.",
                    fullBleed: true
                ) { TerrainScene() }
                .tag(1)

                IntroPage(
                    title: "Run somewhere\nbeautiful",
                    subtitle: "Parks, waterfronts, and landmarks near you appear as photo cards — pick your favorites and the loop bends to pass them.",
                    fullBleed: true
                ) { ScenicScene() }
                .tag(2)

                IntroPage(
                    title: "Chase your\nbest times",
                    subtitle: "Favorite the loops you love. Every finished run counts, and your three fastest stay on the podium.",
                    fullBleed: false
                ) { PodiumDemo() }
                .tag(3)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .ignoresSafeArea()

            VStack {
                HStack {
                    Spacer()
                    if page < lastPage {
                        Button("Skip") {
                            Haptics.selection()
                            onFinish()
                        }
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
                        Button(action: {
                            Haptics.success()
                            onFinish()
                        }) {
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
                            Haptics.selection()
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

// MARK: - Page scaffold

private struct IntroPage<Demo: View>: View {
    let title: String
    let subtitle: String
    let fullBleed: Bool
    @ViewBuilder let demo: () -> Demo

    @State private var appeared = false

    var body: some View {
        Group {
            if fullBleed {
                fullBleedLayout
            } else {
                cardLayout
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.7, dampingFraction: 0.85).delay(0.1)) {
                appeared = true
            }
        }
    }

    /// Scene fills the screen; the copy sits over a scrim at the bottom.
    private var fullBleedLayout: some View {
        ZStack(alignment: .bottom) {
            demo()
                .ignoresSafeArea()

            VStack(spacing: 14) {
                textBlock
            }
            .padding(.horizontal, 8)
            .padding(.bottom, 165)
            .frame(maxWidth: .infinity)
            .background(
                LinearGradient(
                    colors: [.clear,
                             MapboxMapInterface.Colors.background.opacity(0.85),
                             MapboxMapInterface.Colors.background],
                    startPoint: .top, endPoint: .bottom
                )
                .padding(.top, -140)
                .allowsHitTesting(false)
            )
        }
    }

    private var cardLayout: some View {
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
            textBlock
            Spacer(minLength: 150)
        }
    }

    private var textBlock: some View {
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
    }
}

/// Radial glow + vignetted street grid behind the podium demo.
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

// MARK: - Pseudo-3D engine

/// Ground-plane camera: yaw orbits the scene, pitch tilts it toward the
/// horizon, zoom scales it, and a mild perspective factor shrinks the far
/// side. Scene units are roughly [-1, 1] on the ground (x east, z north),
/// y up.
private struct IntroCamera {
    var yaw: Double
    var pitch: Double = 1.0     // ~57°: readable depth without flattening
    var zoom: Double

    func rotated(_ p: SIMD3<Double>) -> SIMD3<Double> {
        let cy = cos(yaw), sy = sin(yaw)
        return SIMD3(p.x * cy - p.z * sy, p.y, p.x * sy + p.z * cy)
    }

    /// Larger = nearer to the viewer (lower on screen).
    func depth(_ p: SIMD3<Double>) -> Double {
        rotated(p).z
    }

    func project(_ p: SIMD3<Double>, in size: CGSize) -> CGPoint {
        let r = rotated(p)
        // Near (large rz) is bigger, far is smaller.
        let persp = 1.0 / (1.0 + 0.24 * (1.6 - min(r.z, 1.5)))
        let base = Double(min(size.width, size.height)) * zoom * persp
        let x = Double(size.width) / 2 + r.x * base
        let y = Double(size.height) * 0.46 + (r.z * cos(pitch) - r.y * sin(pitch)) * base
        return CGPoint(x: x, y: y)
    }
}

private struct IntroBuilding {
    var x: Double, z: Double
    var w: Double, d: Double
    var h: Double
    var tint: Double        // 0…1 brightness variation
    var accent: Bool = false
    var green: Bool = false // park block
}

private enum Intro3D {
    static func clamp01(_ x: Double) -> Double { min(max(x, 0), 1) }

    static func easeInOut(_ x: Double) -> Double {
        let t = clamp01(x)
        return t * t * (3 - 2 * t)
    }

    static func easeOutBack(_ x: Double) -> Double {
        let t = clamp01(x)
        let c = 1.70158
        let u = t - 1
        return 1 + (c + 1) * u * u * u + c * u * u
    }

    /// Closed smooth curve through the points (Catmull-Rom → Bézier).
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

    /// 3D loop vertices from polar radii + per-vertex heights.
    static func loopPoints(radii: [Double], heights: [Double],
                           rotation: Double = 0, scale: Double = 0.95) -> [SIMD3<Double>] {
        let n = radii.count
        return (0..<n).map { i in
            let a = 2 * Double.pi * Double(i) / Double(n) - .pi / 2 + rotation
            return SIMD3(radii[i] * cos(a) * scale,
                         i < heights.count ? heights[i] : 0,
                         radii[i] * sin(a) * scale)
        }
    }

    static func groundGrid(camera: IntroCamera, size: CGSize) -> Path {
        var path = Path()
        let range = stride(from: -1.4, through: 1.4, by: 0.35)
        for v in range {
            path.move(to: camera.project(SIMD3(v, 0, -1.4), in: size))
            for z in stride(from: -1.2, through: 1.4, by: 0.2) {
                path.addLine(to: camera.project(SIMD3(v, 0, z), in: size))
            }
            path.move(to: camera.project(SIMD3(-1.4, 0, v), in: size))
            for x in stride(from: -1.2, through: 1.4, by: 0.2) {
                path.addLine(to: camera.project(SIMD3(x, 0, v), in: size))
            }
        }
        return path
    }

    static func drawBuildings(_ buildings: [IntroBuilding],
                              camera: IntroCamera, size: CGSize,
                              context: GraphicsContext) {
        // Painter's algorithm: far buildings first, near last.
        let sorted = buildings.sorted {
            camera.depth(SIMD3($0.x, 0, $0.z)) < camera.depth(SIMD3($1.x, 0, $1.z))
        }

        for b in sorted {
            let halfW = b.w / 2
            let halfD = b.d / 2
            let signs: [(Double, Double)] = [(-1, -1), (1, -1), (1, 1), (-1, 1)]
            let corners: [SIMD3<Double>] = signs.map { sign in
                let cx: Double = b.x + sign.0 * halfW
                let cz: Double = b.z + sign.1 * halfD
                return SIMD3<Double>(cx, 0, cz)
            }
            let bases = corners.map { camera.project($0, in: size) }
            let tops = corners.map { camera.project(SIMD3($0.x, b.h, $0.z), in: size) }

            let baseWhite = b.green ? 0.10 : (0.15 + 0.08 * b.tint)
            func faceColor(_ brightness: Double) -> Color {
                if b.green {
                    return Color(red: 0.05, green: 0.16 * brightness + 0.06, blue: 0.08)
                }
                return Color(white: baseWhite * brightness)
            }

            // Side faces, far first within the box.
            var faces: [(depth: Double, path: Path, brightness: Double)] = []
            for i in 0..<4 {
                let j = (i + 1) % 4
                var path = Path()
                path.move(to: bases[i])
                path.addLine(to: bases[j])
                path.addLine(to: tops[j])
                path.addLine(to: tops[i])
                path.closeSubpath()
                let midX: Double = (corners[i].x + corners[j].x) / 2
                let midZ: Double = (corners[i].z + corners[j].z) / 2
                let mid = SIMD3<Double>(midX, b.h / 2, midZ)
                faces.append((camera.depth(mid), path, i % 2 == 0 ? 0.62 : 0.85))
            }
            for face in faces.sorted(by: { $0.depth < $1.depth }) {
                context.fill(face.path, with: .color(faceColor(face.brightness)))
            }

            // Top face, lightest, with a faint accent edge.
            var top = Path()
            top.move(to: tops[0])
            tops.dropFirst().forEach { top.addLine(to: $0) }
            top.closeSubpath()
            context.fill(top, with: .color(faceColor(1.15)))
            let edge = b.accent
                ? MapboxMapInterface.Colors.primary.opacity(0.7)
                : MapboxMapInterface.Colors.primary.opacity(0.14)
            context.stroke(top, with: .color(edge), lineWidth: b.accent ? 1.2 : 0.6)
        }
    }

    /// Neon route stroke in a Canvas: blurred halo layers under a crisp core.
    static func strokeNeon(_ path: Path, context: GraphicsContext,
                           center: CGPoint, glow: Double = 1) {
        let gradient = Gradient(colors: [MapboxMapInterface.Colors.primary, .cyan,
                                         MapboxMapInterface.Colors.primary, .cyan,
                                         MapboxMapInterface.Colors.primary])
        let shading = GraphicsContext.Shading.conicGradient(gradient, center: center)

        context.drawLayer { layer in
            layer.addFilter(.blur(radius: 11))
            layer.opacity = 0.55 * glow
            layer.stroke(path, with: shading, style: StrokeStyle(lineWidth: 11, lineCap: .round))
        }
        context.drawLayer { layer in
            layer.addFilter(.blur(radius: 3))
            layer.opacity = 0.85 * glow
            layer.stroke(path, with: shading, style: StrokeStyle(lineWidth: 6, lineCap: .round))
        }
        context.stroke(path, with: shading,
                       style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round))
    }
}

// MARK: - Slide 1: city scene — the engine searching, then the winning loop

private struct CityLoopScene: View {
    @State private var start = Date()

    private static let winner: [Double] = [0.62, 0.46, 0.64, 0.50, 0.60, 0.52, 0.66, 0.45]
    private static let ghostRotations: [Double] = [1.6, 3.5, 5.5]

    private static let buildings: [IntroBuilding] = [
        IntroBuilding(x: -0.95, z: -0.55, w: 0.22, d: 0.22, h: 0.34, tint: 0.8),
        IntroBuilding(x: -0.62, z: -0.95, w: 0.18, d: 0.26, h: 0.5, tint: 0.4),
        IntroBuilding(x: -0.15, z: -1.05, w: 0.24, d: 0.2, h: 0.26, tint: 0.9),
        IntroBuilding(x: 0.4, z: -0.98, w: 0.2, d: 0.24, h: 0.6, tint: 0.6),
        IntroBuilding(x: 0.95, z: -0.6, w: 0.26, d: 0.2, h: 0.38, tint: 0.5),
        IntroBuilding(x: 1.05, z: 0.0, w: 0.2, d: 0.26, h: 0.3, tint: 0.85),
        IntroBuilding(x: 0.95, z: 0.62, w: 0.24, d: 0.22, h: 0.5, tint: 0.45),
        IntroBuilding(x: 0.45, z: 1.0, w: 0.2, d: 0.2, h: 0.32, tint: 0.75),
        IntroBuilding(x: -0.2, z: 1.05, w: 0.26, d: 0.22, h: 0.44, tint: 0.55),
        IntroBuilding(x: -0.8, z: 0.85, w: 0.2, d: 0.26, h: 0.28, tint: 0.9),
        IntroBuilding(x: -1.1, z: 0.25, w: 0.24, d: 0.2, h: 0.55, tint: 0.35),
        IntroBuilding(x: 0.1, z: -0.15, w: 0.14, d: 0.14, h: 0.2, tint: 1.0),
        IntroBuilding(x: -0.3, z: 0.3, w: 0.13, d: 0.15, h: 0.16, tint: 0.7),
        IntroBuilding(x: 0.35, z: 0.35, w: 0.15, d: 0.13, h: 0.24, tint: 0.6),
    ]

    var body: some View {
        TimelineView(.animation) { timeline in
            GeometryReader { geo in
                let t = timeline.date.timeIntervalSince(start)
                let camera = IntroCamera(
                    yaw: 0.35 + t * 0.1,
                    zoom: 0.34 * (1 + 0.1 * sin(t * 0.5))
                )

                ZStack {
                    Canvas { context, size in
                        draw(t: t, camera: camera, context: context, size: size)
                    }

                    // The one input the runner gave.
                    let chipIn = Intro3D.easeOutBack((t - 3.0) / 0.5)
                    Text("5.0 mi")
                        .font(.headline.monospacedDigit())
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 7)
                        .background(
                            Capsule().fill(Color(white: 0.14).opacity(0.9))
                                .overlay(Capsule().stroke(MapboxMapInterface.Colors.primary.opacity(0.5), lineWidth: 1))
                        )
                        .scaleEffect(max(0.001, chipIn))
                        .opacity(Intro3D.clamp01((t - 3.0) / 0.3))
                        .position(x: geo.size.width / 2, y: geo.size.height * 0.14)
                }
            }
        }
    }

    private func draw(t: Double, camera: IntroCamera,
                      context: GraphicsContext, size: CGSize) {
        let center = CGPoint(x: size.width / 2, y: size.height * 0.46)

        // Street grid
        context.stroke(Intro3D.groundGrid(camera: camera, size: size),
                       with: .color(Color(white: 0.22)), lineWidth: 0.8)

        // Skyline
        Intro3D.drawBuildings(Self.buildings, camera: camera, size: size, context: context)

        // Candidate directions the engine tries and discards
        let ghostsFaded = t > 1.15
        for (i, rotation) in Self.ghostRotations.enumerated() {
            let trim = Intro3D.easeInOut((t - Double(i) * 0.3) / 0.55)
            guard trim > 0.01 else { continue }
            let pts = Intro3D.loopPoints(radii: Self.winner,
                                         heights: .init(repeating: 0.004, count: 8),
                                         rotation: rotation)
                .map { camera.project($0, in: size) }
            let path = Intro3D.smoothClosedPath(through: pts).trimmedPath(from: 0, to: trim)
            context.stroke(path,
                           with: .color(Color(white: 0.55).opacity(ghostsFaded ? 0.12 : 0.35)),
                           style: StrokeStyle(lineWidth: 2, lineCap: .round, dash: [5, 6]))
        }

        // The chosen route draws in neon
        let winnerPts = Intro3D.loopPoints(radii: Self.winner,
                                           heights: .init(repeating: 0.006, count: 8))
            .map { camera.project($0, in: size) }
        let winnerPath = Intro3D.smoothClosedPath(through: winnerPts)
        let winnerTrim = Intro3D.easeInOut((t - 1.15) / 1.8)
        if winnerTrim > 0.01 {
            Intro3D.strokeNeon(winnerPath.trimmedPath(from: 0, to: winnerTrim),
                               context: context, center: center)
        }

        // Comet lapping the loop once it's drawn
        if t > 3.0 {
            let runner = ((t - 3.0) / 4.5).truncatingRemainder(dividingBy: 1)
            drawComet(on: winnerPath, at: runner, context: context)
        }

        // Pulsing start pin
        let startPoint = camera.project(
            Intro3D.loopPoints(radii: Self.winner, heights: [0])[0], in: size)
        if winnerTrim > 0.02 {
            let pulse = (t * 0.9).truncatingRemainder(dividingBy: 1)
            var ring = Path()
            ring.addEllipse(in: CGRect(x: startPoint.x - 7 - 12 * pulse,
                                       y: startPoint.y - 7 - 12 * pulse,
                                       width: 14 + 24 * pulse,
                                       height: 14 + 24 * pulse))
            context.stroke(ring,
                           with: .color(MapboxMapInterface.Colors.primary.opacity(0.7 * (1 - pulse))),
                           lineWidth: 2)

            var dot = Path()
            dot.addEllipse(in: CGRect(x: startPoint.x - 6.5, y: startPoint.y - 6.5, width: 13, height: 13))
            context.fill(dot, with: .color(.white))
            context.stroke(dot, with: .color(MapboxMapInterface.Colors.primary), lineWidth: 4)
        }
    }

    private func drawComet(on path: Path, at position: Double, context: GraphicsContext) {
        func segment(_ length: Double) -> Path {
            let from = position - length
            if from >= 0 {
                return path.trimmedPath(from: from, to: position)
            }
            // Wrap around the loop seam.
            var p = path.trimmedPath(from: from + 1, to: 1)
            p.addPath(path.trimmedPath(from: 0, to: position))
            return p
        }

        context.stroke(segment(0.10), with: .color(.white.opacity(0.25)),
                       style: StrokeStyle(lineWidth: 7, lineCap: .round))
        context.stroke(segment(0.045), with: .color(.white.opacity(0.6)),
                       style: StrokeStyle(lineWidth: 8, lineCap: .round))
        context.drawLayer { layer in
            layer.addFilter(.blur(radius: 5))
            layer.stroke(segment(0.008), with: .color(.white),
                         style: StrokeStyle(lineWidth: 13, lineCap: .round))
        }
        context.stroke(segment(0.006), with: .color(.white),
                       style: StrokeStyle(lineWidth: 11, lineCap: .round))
    }
}

// MARK: - Slide 2: terrain scene — the loop reshaping and rising into hills

private struct TerrainScene: View {
    @State private var start = Date()

    private struct Variant {
        let radii: [Double]
        let heights: [Double]
        let ridgeAmplitude: Double
        let distance: String
        let terrain: String
        let terrainIcon: String
    }

    private static let variants: [Variant] = [
        Variant(radii: [0.5, 0.46, 0.51, 0.48, 0.49, 0.47, 0.5, 0.46],
                heights: .init(repeating: 0, count: 8),
                ridgeAmplitude: 0.015,
                distance: "3.0 mi", terrain: "Flat", terrainIcon: "minus"),
        Variant(radii: [0.66, 0.52, 0.69, 0.56, 0.64, 0.54, 0.67, 0.55],
                heights: [0.05, 0.02, 0.07, 0.03, 0.06, 0.02, 0.05, 0.03],
                ridgeAmplitude: 0.06,
                distance: "5.0 mi", terrain: "Rolling", terrainIcon: "water.waves"),
        Variant(radii: [0.78, 0.5, 0.8, 0.46, 0.75, 0.58, 0.79, 0.44],
                heights: [0.16, 0.05, 0.22, 0.08, 0.18, 0.04, 0.2, 0.07],
                ridgeAmplitude: 0.16,
                distance: "8.0 mi", terrain: "Hilly", terrainIcon: "mountain.2.fill"),
    ]

    var body: some View {
        TimelineView(.animation) { timeline in
            GeometryReader { geo in
                let t = timeline.date.timeIntervalSince(start)
                // The camera breathes: a pronounced zoom in and out over the
                // route while slowly drifting around it.
                let camera = IntroCamera(
                    yaw: 0.5 + t * 0.09,
                    zoom: 0.42 * (1 + 0.22 * sin(t * 0.45))
                )

                let cycle = 2.8
                let step = Int(floor(t / cycle)) % Self.variants.count
                let next = (step + 1) % Self.variants.count
                let phase = Intro3D.easeInOut(((t.truncatingRemainder(dividingBy: cycle)) - 1.7) / 1.1)
                let shown = phase > 0.5 ? next : step

                ZStack {
                    Canvas { context, size in
                        draw(from: Self.variants[step], to: Self.variants[next],
                             phase: phase, camera: camera, context: context, size: size)
                    }

                    // Preference chips the loop is answering to
                    HStack(spacing: 10) {
                        chip(icon: "figure.run", label: Self.variants[shown].distance, highlighted: true)
                        chip(icon: Self.variants[shown].terrainIcon, label: Self.variants[shown].terrain, highlighted: false)
                        chip(icon: "leaf.fill", label: "Trails", highlighted: false)
                    }
                    .scaleEffect(1 + 0.06 * sin(Double.pi * Intro3D.clamp01(phase)))
                    .position(x: geo.size.width / 2, y: geo.size.height * 0.13)
                }
            }
        }
    }

    private func draw(from: Variant, to: Variant, phase: Double,
                      camera: IntroCamera, context: GraphicsContext, size: CGSize) {
        let center = CGPoint(x: size.width / 2, y: size.height * 0.46)

        func lerp(_ a: Double, _ b: Double) -> Double { a + (b - a) * phase }
        let radii = zip(from.radii, to.radii).map(lerp)
        let heights = zip(from.heights, to.heights).map(lerp)
        let ridgeAmplitude = lerp(from.ridgeAmplitude, to.ridgeAmplitude)

        // Faint ground grid
        context.stroke(Intro3D.groundGrid(camera: camera, size: size),
                       with: .color(Color(white: 0.2)), lineWidth: 0.7)

        // Background ridges that grow with the terrain preference
        for (row, base) in [(-1.05, 0.55), (-0.75, 0.8), (1.0, 0.65)] {
            var ridge = Path()
            var first = true
            for x in stride(from: -1.5, through: 1.5, by: 0.08) {
                let y = ridgeAmplitude * (2.2 + base) *
                    (0.55 + 0.45 * sin(x * 4.2 + row * 3)) * (0.6 + 0.4 * cos(x * 1.7 - row))
                let point = camera.project(SIMD3(x, max(0.003, y), row), in: size)
                if first { ridge.move(to: point); first = false } else { ridge.addLine(to: point) }
            }
            context.drawLayer { layer in
                layer.addFilter(.blur(radius: 0.5))
                layer.stroke(ridge, with: .color(Color(white: 0.32).opacity(0.8)), lineWidth: 1.2)
            }
        }

        // Elevation walls: faint drop lines from the route down to the ground
        let loop3D = Intro3D.loopPoints(radii: radii, heights: heights)
        var walls = Path()
        for p in loop3D where p.y > 0.008 {
            walls.move(to: camera.project(p, in: size))
            walls.addLine(to: camera.project(SIMD3(p.x, 0, p.z), in: size))
        }
        context.stroke(walls, with: .color(MapboxMapInterface.Colors.primary.opacity(0.25)),
                       style: StrokeStyle(lineWidth: 1, dash: [2, 3]))

        // Ground shadow of the loop
        let shadowPts = loop3D.map { camera.project(SIMD3($0.x, 0, $0.z), in: size) }
        context.stroke(Intro3D.smoothClosedPath(through: shadowPts),
                       with: .color(.black.opacity(0.5)),
                       style: StrokeStyle(lineWidth: 5, lineCap: .round))

        // The route itself, riding the terrain
        let pts = loop3D.map { camera.project($0, in: size) }
        Intro3D.strokeNeon(Intro3D.smoothClosedPath(through: pts),
                           context: context, center: center)
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
                      : Color(white: 0.16).opacity(0.9))
                .overlay(Capsule().stroke(MapboxMapInterface.Colors.primary.opacity(highlighted ? 0.9 : 0.35), lineWidth: 1))
        )
    }
}

// MARK: - Slide 3: scenic scene — pins landing, the loop bending to reach them

private struct ScenicScene: View {
    @State private var start = Date()

    private static let before: [Double] = [0.5, 0.47, 0.52, 0.48, 0.51, 0.48, 0.5, 0.47]
    private static var after: [Double] {
        var r = before
        r[1] = 0.78   // park
        r[4] = 0.76   // waterfront
        r[6] = 0.74   // monument
        return r
    }

    private static let pins: [(index: Int, icon: String, delay: Double)] = [
        (1, "leaf.fill", 0.30),
        (4, "water.waves", 0.70),
        (6, "building.columns.fill", 1.10),
    ]

    private static let buildings: [IntroBuilding] = [
        // Small downtown cluster
        IntroBuilding(x: -0.85, z: -0.75, w: 0.2, d: 0.22, h: 0.42, tint: 0.5),
        IntroBuilding(x: -0.55, z: -1.0, w: 0.18, d: 0.2, h: 0.3, tint: 0.8),
        IntroBuilding(x: -1.05, z: -0.3, w: 0.22, d: 0.2, h: 0.55, tint: 0.4),
        IntroBuilding(x: 0.1, z: -1.05, w: 0.24, d: 0.2, h: 0.36, tint: 0.65),
        // The monument: tall, thin, accented
        IntroBuilding(x: -0.95, z: 0.55, w: 0.09, d: 0.09, h: 0.7, tint: 1.0, accent: true),
        // Park blocks: low and green
        IntroBuilding(x: 0.75, z: -0.6, w: 0.34, d: 0.3, h: 0.045, tint: 1.0, green: true),
        IntroBuilding(x: 1.0, z: -0.2, w: 0.3, d: 0.34, h: 0.05, tint: 0.8, green: true),
    ]

    var body: some View {
        TimelineView(.animation) { timeline in
            GeometryReader { geo in
                let t = timeline.date.timeIntervalSince(start)
                let camera = IntroCamera(
                    yaw: -0.3 + t * 0.08,
                    zoom: 0.37 * (1 + 0.12 * sin(t * 0.42))
                )
                let morph = Intro3D.easeInOut((t - 1.9) / 1.0)
                let radii = zip(Self.before, Self.after).map { $0 + ($1 - $0) * morph }
                let glow = 1 + 0.8 * sin(Double.pi * Intro3D.clamp01((t - 1.9) / 1.3))

                ZStack {
                    Canvas { context, size in
                        draw(radii: radii, glow: glow, camera: camera,
                             context: context, size: size)
                    }

                    // Landmark photo pins dropping onto the map
                    ForEach(Array(Self.pins.enumerated()), id: \.offset) { _, pin in
                        let target3D = Intro3D.loopPoints(radii: Self.after,
                                                          heights: .init(repeating: 0, count: 8))[pin.index]
                        let target = camera.project(target3D, in: geo.size)
                        let dropIn = Intro3D.easeOutBack((t - pin.delay) / 0.5)
                        let ripple = Intro3D.clamp01((t - pin.delay - 0.28) / 0.7)

                        ZStack {
                            Circle()
                                .stroke(MapboxMapInterface.Colors.primary.opacity(0.8 * (1 - ripple)), lineWidth: 2)
                                .frame(width: 30, height: 30)
                                .scaleEffect(0.4 + 2.4 * ripple)

                            IntroPhotoPin(icon: pin.icon)
                                .scaleEffect(max(0.001, dropIn), anchor: .bottom)
                                .offset(y: -60 * (1 - Intro3D.clamp01((t - pin.delay) / 0.5)))
                        }
                        .position(x: target.x, y: target.y - 4)
                        .opacity(t > pin.delay ? 1 : 0)
                    }
                }
            }
        }
    }

    private func draw(radii: [Double], glow: Double, camera: IntroCamera,
                      context: GraphicsContext, size: CGSize) {
        let center = CGPoint(x: size.width / 2, y: size.height * 0.46)

        // Water along the far edge
        let waterCorners = [SIMD3(-1.6, 0.0, 0.75), SIMD3(1.6, 0.0, 0.75),
                            SIMD3(1.6, 0.0, 1.7), SIMD3(-1.6, 0.0, 1.7)]
            .map { camera.project($0, in: size) }
        var water = Path()
        water.move(to: waterCorners[0])
        waterCorners.dropFirst().forEach { water.addLine(to: $0) }
        water.closeSubpath()
        context.fill(water, with: .linearGradient(
            Gradient(colors: [Color(red: 0.04, green: 0.13, blue: 0.22),
                              Color(red: 0.02, green: 0.07, blue: 0.13)]),
            startPoint: waterCorners[0], endPoint: waterCorners[2]))
        context.stroke(water, with: .color(.cyan.opacity(0.18)), lineWidth: 1)

        // Street grid
        context.stroke(Intro3D.groundGrid(camera: camera, size: size),
                       with: .color(Color(white: 0.21)), lineWidth: 0.7)

        // Landmarks, parks, skyline
        Intro3D.drawBuildings(Self.buildings, camera: camera, size: size, context: context)

        // The loop, bending out to collect the chosen spots
        let pts = Intro3D.loopPoints(radii: radii, heights: .init(repeating: 0.005, count: 8))
            .map { camera.project($0, in: size) }
        Intro3D.strokeNeon(Intro3D.smoothClosedPath(through: pts),
                           context: context, center: center, glow: glow)
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

// MARK: - Slide 4: the podium, with a shine on gold

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

// MARK: - Shared backdrop grid (podium page)

/// Faint street grid that makes the podium demo read as a map.
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
