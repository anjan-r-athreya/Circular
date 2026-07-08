//
//  Theme.swift
//  CircleRun
//
//  The app's shared motion vocabulary: three springs, one press style,
//  and two entrance transitions. Every animated surface uses these so
//  the whole app moves like one thing.
//

import SwiftUI

extension Animation {
    /// The standard spring — matches MapboxMapInterface.Animation.spring.
    static let theme = Animation.spring(response: 0.4, dampingFraction: 0.8)
    /// Quick feedback: button presses, value changes.
    static let themeSnappy = Animation.spring(response: 0.3, dampingFraction: 0.7)
    /// Cards and overlays arriving.
    static let themeEntrance = Animation.spring(response: 0.55, dampingFraction: 0.8)
}

extension AnyTransition {
    /// Cards and sheets rise into place from below.
    static let riseIn = AnyTransition.move(edge: .bottom)
        .combined(with: .opacity)
        .combined(with: .scale(scale: 0.97, anchor: .bottom))
    /// Banners and chips drop in from above.
    static let dropIn = AnyTransition.move(edge: .top).combined(with: .opacity)
}

/// Press feedback for every tappable control: quick shrink and dim,
/// spring back on release.
struct ThemeButtonStyle: ButtonStyle {
    var scale: CGFloat = 0.9

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? scale : 1)
            .opacity(configuration.isPressed ? 0.8 : 1)
            .animation(.themeSnappy, value: configuration.isPressed)
    }
}

/// Staggered entrance for lists of cards — each arrives a beat after the
/// one above it.
private struct StaggeredAppear: ViewModifier {
    let index: Int
    @State private var shown = false

    func body(content: Content) -> some View {
        content
            .opacity(shown ? 1 : 0)
            .offset(y: shown ? 0 : 18)
            .scaleEffect(shown ? 1 : 0.97)
            .onAppear {
                withAnimation(.themeEntrance.delay(Double(index) * 0.06)) {
                    shown = true
                }
            }
    }
}

extension View {
    func staggeredAppear(index: Int) -> some View {
        modifier(StaggeredAppear(index: index))
    }
}
