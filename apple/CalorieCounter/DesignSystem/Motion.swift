//
//  Motion.swift
//  Reduce-Motion-aware animation factories. Callers pass the current
//  `accessibilityReduceMotion` value and get back the right transition/animation —
//  so no view branches on accessibility inline, and the "calm" alternative is
//  guaranteed everywhere the signature reveal is used.
//

import SwiftUI

enum Motion {
    /// The signature parse → meal-card reveal: a gentle scale-up + fade normally,
    /// collapsing to a plain crossfade when Reduce Motion is on.
    static func reveal(reduceMotion: Bool) -> AnyTransition {
        reduceMotion
            ? .opacity
            : .scale(scale: 0.94).combined(with: .opacity)
    }

    /// The house spring for content motion, softened to a short ease under Reduce
    /// Motion (no overshoot/bounce).
    static func spring(reduceMotion: Bool) -> Animation {
        reduceMotion
            ? .easeInOut(duration: 0.2)
            : .spring(response: 0.42, dampingFraction: 0.82)
    }

    /// Wrap a value-change animation so callers never branch: returns `nil`
    /// (i.e. *no* animation) when Reduce Motion is on. Use as
    /// `withAnimation(Motion.none(reduceMotion)) { … }` — SwiftUI treats a nil
    /// animation as an instant change.
    static func none(_ reduceMotion: Bool, otherwise base: Animation = .spring(response: 0.42, dampingFraction: 0.82)) -> Animation? {
        reduceMotion ? nil : base
    }
}
