//
//  Haptics.swift
//  CircleRun
//
//  One-line haptic feedback for the app's key moments. Runners interact
//  one-handed and mid-stride, so taps should be felt, not just seen.
//

import UIKit

enum Haptics {
    /// Route generated, run saved — something the user asked for worked.
    static func success() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    /// Generation failed, run discarded.
    static func error() {
        UINotificationFeedbackGenerator().notificationOccurred(.error)
    }

    /// Toggles and pickers — spot selected, style changed.
    static func selection() {
        UISelectionFeedbackGenerator().selectionChanged()
    }

    /// Milestones mid-run — mile crossed, personal record beaten.
    static func milestone() {
        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
    }
}
