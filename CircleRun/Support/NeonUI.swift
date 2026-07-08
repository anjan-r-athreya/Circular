//
//  NeonUI.swift
//  CircleRun
//
//  The Night Circuit component kit: the palette, glow cards, cap labels,
//  stat tiles, and the neon route trace that serves as the app's monogram.
//  Design reference: the Night Circuit board (tokens map 1:1).
//

import SwiftUI
import CoreLocation

// MARK: - Palette

enum Night {
    static let ground = Color(red: 0.039, green: 0.055, blue: 0.078)   // #0A0E14
    static let panel = Color(red: 0.067, green: 0.098, blue: 0.153)    // #111927
    static let panelDeep = Color(red: 0.051, green: 0.078, blue: 0.125)
    static let line = Color(red: 0.24, green: 0.61, blue: 1).opacity(0.22)
    static let blue = Color(red: 0.24, green: 0.61, blue: 1)           // #3D9BFF
    static let cyan = Color(red: 0.35, green: 0.91, blue: 1)           // #59E8FF
    static let gold = Color(red: 1, green: 0.83, blue: 0.30)           // #FFD34D — records only
    static let pink = Color(red: 1, green: 0.36, blue: 0.54)           // #FF5C8A — heart rate only
    static let ember = Color(red: 1, green: 0.62, blue: 0.27)          // #FF9F45 — climbs & streaks
    static let text = Color(red: 0.92, green: 0.95, blue: 1)
    static let dim = Color(red: 0.56, green: 0.64, blue: 0.75)
    static let faint = Color(red: 0.29, green: 0.35, blue: 0.45)
}

// MARK: - Building blocks

/// Dark panel with a thin circuit-blue stroke and a soft glow.
struct GlowCard<Content: View>: View {
    var stroke: Color = Night.line
    var glow: Color = Night.blue.opacity(0.07)
    @ViewBuilder let content: () -> Content

    var body: some View {
        content()
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 18)
                    .fill(Night.panel)
                    .overlay(RoundedRectangle(cornerRadius: 18).stroke(stroke, lineWidth: 1))
            )
            .shadow(color: glow, radius: 12)
    }
}

/// Tiny letterspaced caps — every section and stat label in the system.
struct CapLabel: View {
    let text: String
    var color: Color = Night.faint

    var body: some View {
        Text(text)
            .font(.system(size: 10, weight: .bold))
            .kerning(1.8)
            .foregroundColor(color)
    }
}

/// Stat tile: glow dot + cap label + big rounded number.
struct StatTile: View {
    let label: String
    let value: String
    var unit: String? = nil
    var tint: Color = Night.blue

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 5) {
                Circle()
                    .fill(tint)
                    .frame(width: 7, height: 7)
                    .shadow(color: tint, radius: 4)
                CapLabel(text: label)
            }
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text(value)
                    .font(.system(size: 20, weight: .heavy, design: .rounded))
                    .monospacedDigit()
                    .foregroundColor(Night.text)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                if let unit {
                    Text(unit)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(Night.dim)
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Night.panel)
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(Night.line, lineWidth: 1))
        )
    }
}

/// Dashed hairline that reads like a route path.
struct DashRule: View {
    var body: some View {
        Line()
            .stroke(Night.dim.opacity(0.25), style: StrokeStyle(lineWidth: 1, dash: [3, 4]))
            .frame(height: 1)
    }

    private struct Line: Shape {
        func path(in rect: CGRect) -> Path {
            var p = Path()
            p.move(to: CGPoint(x: rect.minX, y: rect.midY))
            p.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
            return p
        }
    }
}

// MARK: - Neon route trace

/// A run's GPS trace drawn as a glowing loop — the app's monogram.
/// Optionally draws itself on and keeps a comet lapping the path.
struct NeonTraceView: View {
    let coordinates: [CLLocationCoordinate2D]
    var color: Color = Night.blue
    var lineWidth: CGFloat = 2.6
    /// Draw-on entrance plus a lapping comet head (hero usage).
    var animated: Bool = false

    @State private var start = Date()

    var body: some View {
        if animated {
            TimelineView(.animation) { timeline in
                let t = timeline.date.timeIntervalSince(start)
                canvas(drawProgress: min(1, t / 1.4),
                       cometProgress: t < 1.4 ? min(1, t / 1.4)
                                             : ((t - 1.4) / 3.4).truncatingRemainder(dividingBy: 1))
            }
        } else {
            canvas(drawProgress: 1, cometProgress: nil)
        }
    }

    private func canvas(drawProgress: Double, cometProgress: Double?) -> some View {
        Canvas { context, size in
            let points = normalized(in: size)
            guard points.count > 2 else { return }

            var path = Path()
            path.move(to: points[0])
            points.dropFirst().forEach { path.addLine(to: $0) }
            path.closeSubpath()
            let drawn = drawProgress < 1 ? path.trimmedPath(from: 0, to: drawProgress) : path

            // Halo under a crisp core.
            context.drawLayer { layer in
                layer.addFilter(.blur(radius: 5))
                layer.opacity = 0.75
                layer.stroke(drawn, with: .color(color),
                             style: StrokeStyle(lineWidth: lineWidth * 2.4, lineCap: .round, lineJoin: .round))
            }
            context.stroke(drawn, with: .color(color),
                           style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round))

            // Comet head riding the loop.
            if let cometProgress, let head = point(along: points, fraction: cometProgress) {
                let halo = Path(ellipseIn: CGRect(x: head.x - 6, y: head.y - 6, width: 12, height: 12))
                context.drawLayer { layer in
                    layer.addFilter(.blur(radius: 4))
                    layer.fill(halo, with: .color(.white.opacity(0.8)))
                }
                context.fill(Path(ellipseIn: CGRect(x: head.x - 2.5, y: head.y - 2.5, width: 5, height: 5)),
                             with: .color(.white))
            }
        }
    }

    /// Coordinates fitted into the view with padding, aspect preserved.
    private func normalized(in size: CGSize) -> [CGPoint] {
        guard coordinates.count > 2,
              let minLat = coordinates.map(\.latitude).min(),
              let maxLat = coordinates.map(\.latitude).max(),
              let minLng = coordinates.map(\.longitude).min(),
              let maxLng = coordinates.map(\.longitude).max() else { return [] }

        let latSpan = max(maxLat - minLat, 1e-6)
        // Longitude degrees shrink with latitude; correct so loops keep shape.
        let lngScale = cos((minLat + maxLat) / 2 * .pi / 180)
        let lngSpan = max((maxLng - minLng) * lngScale, 1e-6)

        let inset: CGFloat = lineWidth * 3 + 4
        let fit = min((size.width - 2 * inset) / lngSpan, (size.height - 2 * inset) / latSpan)
        let xOffset = (size.width - lngSpan * fit) / 2
        let yOffset = (size.height - latSpan * fit) / 2

        return coordinates.map { c in
            CGPoint(x: xOffset + ((c.longitude - minLng) * lngScale) * fit,
                    y: yOffset + (maxLat - c.latitude) * fit)
        }
    }

    /// Point a fraction of the way along the polyline's length.
    private func point(along points: [CGPoint], fraction: Double) -> CGPoint? {
        guard points.count > 1 else { return nil }
        var lengths: [CGFloat] = [0]
        var closed = points
        closed.append(points[0])
        for i in 1..<closed.count {
            lengths.append(lengths[i - 1] + hypot(closed[i].x - closed[i - 1].x,
                                                  closed[i].y - closed[i - 1].y))
        }
        guard let total = lengths.last, total > 0 else { return nil }
        let target = CGFloat(fraction) * total
        for i in 1..<closed.count where lengths[i] >= target {
            let segment = lengths[i] - lengths[i - 1]
            let t = segment > 0 ? (target - lengths[i - 1]) / segment : 0
            return CGPoint(x: closed[i - 1].x + (closed[i].x - closed[i - 1].x) * t,
                           y: closed[i - 1].y + (closed[i].y - closed[i - 1].y) * t)
        }
        return closed.last
    }
}

/// Faint dot grid backing hero panels (the map, abstracted).
struct DotGrid: View {
    var body: some View {
        Canvas { context, size in
            let step: CGFloat = 16
            var y: CGFloat = step / 2
            while y < size.height {
                var x: CGFloat = step / 2
                while x < size.width {
                    context.fill(Path(ellipseIn: CGRect(x: x, y: y, width: 1.6, height: 1.6)),
                                 with: .color(Night.dim.opacity(0.16)))
                    x += step
                }
                y += step
            }
        }
        .allowsHitTesting(false)
    }
}
