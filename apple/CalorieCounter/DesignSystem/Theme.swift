//
//  Theme.swift
//  The visual design system: macro palette + gradients, type, spacing, and the
//  shared backdrop. The rule throughout: iOS 26 Liquid Glass is for chrome and
//  temporary surfaces; content sits on calm matte cards (DS.contentFill).
//

import SwiftUI
import UIKit
import NutritionCore

extension AppearanceMode {
    /// SwiftUI scheme to force, or `nil` to follow the system ("Auto").
    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }

    /// UIKit style for the window-level override. Applied to the window so the choice
    /// reaches presented sheets live — a presenter's `.preferredColorScheme` does not
    /// propagate to an already-presented sheet, but a window override cascades to it
    /// just like a system light/dark switch.
    var uiUserInterfaceStyle: UIUserInterfaceStyle {
        switch self {
        case .system: return .unspecified
        case .light: return .light
        case .dark: return .dark
        }
    }
}

extension Color {
    init(hex: UInt32) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: 1
        )
    }
}

/// Design tokens.
enum DS {
    // Geometry
    static let screenPadding: CGFloat = 20
    static let cardRadius: CGFloat = 28
    static let chipRadius: CGFloat = 20

    /// Bottom SCROLL clearance — the inset that lets the last row scroll fully clear
    /// of the floating dock. Scaled with Dynamic Type at the call site, so at large
    /// text sizes there's proportionally more room to scroll tall content above the
    /// bar. (Distinct from the background shelf below, which is fixed: the dock
    /// itself doesn't grow with Dynamic Type, so neither should the scrim that masks
    /// it.) Kept ≥ the shelf height so content always clears the fade.
    static let dockClearance: CGFloat = 188

    /// The dock's background SHELF — a fixed scrim painted behind the floating bar so
    /// content doesn't ghost against the backdrop as it slides under. `dockSolidBand`
    /// is the fully-opaque base that hides the bar + the raised "+" jewel; `dockFade`
    /// is the short soft fade above it. Both FIXED (the dock doesn't scale), so the
    /// fade stays a tight transition instead of dissolving readable rows at large
    /// text sizes — tall content scrolls clear via `dockClearance` instead.
    static let dockSolidBand: CGFloat = 124
    static let dockFade: CGFloat = 48

    /// At accessibility text sizes the dock stops floating OVER the scroll content and
    /// reserves this much REAL space beneath it, so tall content (the macro summary,
    /// the weekly insight) scrolls within the area ABOVE the bar instead of being
    /// swallowed behind it. Tall enough to clear the whole floating dock — the capsule
    /// plus the raised "+" jewel — so the scroll area ends cleanly above it. Fixed: the
    /// dock doesn't grow with Dynamic Type.
    static let dockReserve: CGFloat = 132

    /// The app's base backdrop color (matches `AppBackground`'s base), used to paint
    /// the dock's background shelf so content fades into the background behind it.
    static func appBackgroundBase(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color(hex: 0x0C0D10) : Color(hex: 0xF4F5F7)
    }

    /// MATTE content-surface fill — the design rule: glass is for chrome/transient
    /// surfaces (dock, tray, toasts), MATTE is for anything that holds information
    /// (cards, rows, charts, chips). A solid, calm, readable surface lifted subtly
    /// off the backdrop — never translucent, so data never feels mushy or slippery.
    static func contentFill(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color(hex: 0x16181D) : .white
    }

    /// Card/separator border that stays visible in both schemes (a white edge is
    /// invisible on a light backdrop) and strengthens when Increase Contrast is on.
    static func cardBorder(_ scheme: ColorScheme, _ contrast: ColorSchemeContrast) -> Color {
        let base = scheme == .dark ? Color.white : Color.black
        let opacity: Double = scheme == .dark
            ? (contrast == .increased ? 0.18 : 0.08)
            : (contrast == .increased ? 0.22 : 0.12)
        return base.opacity(opacity)
    }

    /// Over-target signal: a warm, unmistakable red that still fits the muted
    /// palette. Used for the overage ring arc and "X over" labels.
    static let over = Color(hex: 0xE0594F)
    static let overGradient = AngularGradient(
        colors: [Color(hex: 0xD6433D), Color(hex: 0xEC7A6F), Color(hex: 0xD6433D)],
        center: .center, angle: .degrees(-90)
    )

    /// The four tracked macros with their identity colors + gradients.
    enum Macro: String, CaseIterable, Identifiable {
        case calories, protein, carbs, fat
        var id: String { rawValue }

        var title: String {
            switch self {
            case .calories: return "Calories"
            case .protein: return "Protein"
            case .carbs: return "Carbs"
            case .fat: return "Fat"
            }
        }
        var short: String {
            switch self {
            case .calories: return "kcal"
            case .protein, .carbs, .fat: return "g"
            }
        }
        var systemImage: String {
            switch self {
            case .calories: return "flame.fill"
            case .protein: return "bolt.heart.fill"
            case .carbs: return "leaf.fill"
            case .fat: return "drop.fill"
            }
        }
        /// Solid identity color — muted, refined tones (distinct but not neon).
        var tint: Color {
            switch self {
            case .calories: return Color(hex: 0x57B58C)   // sage green
            case .protein:  return Color(hex: 0xCC7C8C)   // muted rose
            case .carbs:    return Color(hex: 0x6E9AC8)   // dusty blue
            case .fat:      return Color(hex: 0xCFA85C)   // soft gold
            }
        }
        /// Two-stop gradient stops used to paint rings and bars (subtle spread).
        var stops: [Color] {
            switch self {
            case .calories: return [Color(hex: 0x4FAE84), Color(hex: 0x73C2A1)]
            case .protein:  return [Color(hex: 0xC4707F), Color(hex: 0xD597A3)]
            case .carbs:    return [Color(hex: 0x6390C2), Color(hex: 0x8BB0D6)]
            case .fat:      return [Color(hex: 0xC79E54), Color(hex: 0xDABA7C)]
            }
        }
        /// Angular gradient for a progress ring (gives the swept-color look).
        var ringGradient: AngularGradient {
            AngularGradient(colors: stops + [stops.first ?? tint],
                            center: .center, angle: .degrees(-90))
        }
        var linearGradient: LinearGradient {
            LinearGradient(colors: stops, startPoint: .topLeading, endPoint: .bottomTrailing)
        }
    }
}

/// Full-screen backdrop: a calm, near-neutral base with one barely-there glow for
/// depth. Restrained so the content carries the color, not the chrome.
struct AppBackground: View {
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        ZStack {
            DS.appBackgroundBase(scheme)
                .ignoresSafeArea()

            // A single, very subtle accent glow at the top.
            RadialGradient(
                colors: [DS.Macro.calories.tint.opacity(scheme == .dark ? 0.10 : 0.06), .clear],
                center: .top, startRadius: 0, endRadius: 440
            )
            .ignoresSafeArea()
        }
    }
}

/// Reserves scroll space for the floating dock so the LAST card can scroll fully
/// above it (paired with `MainTabView`'s background shelf, which fades anything
/// passing behind the bar mid-scroll into the app background). Applied to the
/// Today / History scroll containers; the height scales with Dynamic Type so the
/// reserved space grows alongside the content. The matching shelf height lives in
/// `DS.dockClearance`.
private struct TabBarBottomClearance: ViewModifier {
    @Environment(\.dynamicTypeSize) private var typeSize
    @ScaledMetric(relativeTo: .body) private var clearance: CGFloat = DS.dockClearance
    func body(content: Content) -> some View {
        if typeSize.isAccessibilitySize {
            // Reserve REAL space by shrinking the scroll view's FRAME (a sibling spacer
            // in a VStack), not just insetting its scroll offsets — a List/ScrollView
            // otherwise renders edge-to-edge and draws content under the dock regardless
            // of contentMargins/safeAreaInset. With a smaller frame the scroll area ends
            // ABOVE the dock, so tall content (the macro summary, the weekly insight)
            // scrolls within the space above the bar instead of being swallowed behind it.
            // (Must be applied as the LAST modifier so it wraps the fully-built scroll view.)
            VStack(spacing: 0) {
                content
                Color.clear.frame(height: DS.dockReserve)
            }
        } else {
            // Standard sizes: the dock floats over the content; reserve enough scroll
            // clearance that the last card can still scroll fully clear of it.
            content.contentMargins(.bottom, clearance, for: .scrollContent)
        }
    }
}

extension View {
    func tabBarBottomClearance() -> some View { modifier(TabBarBottomClearance()) }
}

/// A MATTE content card (data deserves a solid, calm surface — not glass). Used for
/// grouped content everywhere: insights, plan, weight, charts, banners.
struct SoftCard<Content: View>: View {
    @Environment(\.colorScheme) private var scheme
    @Environment(\.colorSchemeContrast) private var contrast
    @ViewBuilder var content: Content
    var padding: CGFloat = 18

    var body: some View {
        content
            .padding(padding)
            .background {
                RoundedRectangle(cornerRadius: DS.cardRadius, style: .continuous)
                    .fill(DS.contentFill(scheme))
                    .overlay {
                        RoundedRectangle(cornerRadius: DS.cardRadius, style: .continuous)
                            .stroke(DS.cardBorder(scheme, contrast), lineWidth: 1)
                    }
                    // A soft shadow lifts the card off the backdrop (light mode mainly).
                    .shadow(color: scheme == .dark ? .clear : .black.opacity(0.06),
                            radius: 9, y: 3)
            }
    }
}
