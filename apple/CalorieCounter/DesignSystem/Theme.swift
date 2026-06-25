//
//  Theme.swift
//  The visual design system: macro palette + gradients, type, spacing, and the
//  shared backdrop. iOS 26 Liquid Glass for chrome/floating controls; vibrant
//  gradient rings and glass cards for content.
//

import SwiftUI
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
            (scheme == .dark ? Color(hex: 0x0C0D10) : Color(hex: 0xF4F5F7))
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

extension View {
    /// Bottom inset so scrollable content can scroll clear of the floating Liquid
    /// Glass tab bar (which sits over content and doesn't reserve safe area). Applied
    /// to the Today / History / Settings scroll containers. Tune here in one place.
    func tabBarBottomClearance() -> some View {
        contentMargins(.bottom, 72, for: .scrollContent)
    }
}

/// A content card with a glassy, layered look (used for grouped content).
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
                    .fill(.ultraThinMaterial)
                    .overlay {
                        RoundedRectangle(cornerRadius: DS.cardRadius, style: .continuous)
                            .stroke(DS.cardBorder(scheme, contrast), lineWidth: 1)
                    }
                    // In light mode the material barely separates from a light
                    // backdrop; a soft shadow lifts the card so it reads as a surface.
                    .shadow(color: scheme == .dark ? .clear : .black.opacity(0.06),
                            radius: 9, y: 3)
            }
    }
}
