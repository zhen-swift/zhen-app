// Motion.swift — the animation budget, which is deliberately small.
//
// The artboards are static, so this is a decision rather than a measurement. This app
// shows a network changing on its own, and every animation that is not caused by the
// user competes with one that is.
//
// The most important entry is the one that is `nil`. A value that animates every time it
// changes, when it changes twice a second, reads as noise — RTT and counters are
// swapped, not tweened.

import SwiftUI

/// Durations and curves, so no view writes a bare number or picks its own curve.
public enum Motion {
    /// A row arriving during a live scan.
    public static let rowAppear = Animation.easeOut(duration: 0.18)
    /// A selection moving.
    public static let selection = Animation.easeInOut(duration: 0.12)
    /// A disclosure opening.
    public static let disclosure = Animation.easeInOut(duration: 0.15)

    /// The animation to use, honouring the user's Reduce Motion setting.
    ///
    /// Call this rather than reaching for an `Animation` directly. Reduce Motion is not
    /// a preference about taste; for some people it is the difference between using the
    /// app and feeling ill.
    ///
    /// - Parameters:
    ///   - animation: what to play when motion is allowed.
    ///   - reduceMotion: the value of `\.accessibilityReduceMotion`.
    /// - Returns: the animation, or nil when motion is reduced.
    public static func honouring(_ animation: Animation, reduceMotion: Bool) -> Animation? {
        reduceMotion ? nil : animation
    }
}
