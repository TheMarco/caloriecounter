//
//  Theme.swift
//  The visual design system: macro palette + gradients, type, spacing, and the
//  shared backdrop. iOS 26 Liquid Glass for chrome/floating controls; vibrant
//  gradient rings and glass cards for content.
//

import SwiftUI

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
        /// Solid identity color.
        var tint: Color {
            switch self {
            case .calories: return Color(hex: 0x30D158)
            case .protein:  return Color(hex: 0xFF375F)
            case .carbs:    return Color(hex: 0x0A84FF)
            case .fat:      return Color(hex: 0xFF9F0A)
            }
        }
        /// Two-stop gradient stops used to paint rings and bars.
        var stops: [Color] {
            switch self {
            case .calories: return [Color(hex: 0x32D74B), Color(hex: 0x66E0A3)]
            case .protein:  return [Color(hex: 0xFF375F), Color(hex: 0xFF7AA0)]
            case .carbs:    return [Color(hex: 0x0A84FF), Color(hex: 0x64D2FF)]
            case .fat:      return [Color(hex: 0xFF9F0A), Color(hex: 0xFFD60A)]
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

/// Full-screen backdrop: a soft adaptive base with a gentle colored glow behind
/// the hero. Calm and premium so the vibrant rings/cards pop.
struct AppBackground: View {
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        ZStack {
            (scheme == .dark ? Color(hex: 0x0B0B0F) : Color(hex: 0xF2F3F7))
                .ignoresSafeArea()

            // Soft green glow, top-trailing.
            RadialGradient(
                colors: [DS.Macro.calories.tint.opacity(scheme == .dark ? 0.30 : 0.22), .clear],
                center: .topTrailing, startRadius: 0, endRadius: 520
            )
            .ignoresSafeArea()
            .blendMode(scheme == .dark ? .screen : .plusDarker)

            // Cooler counter-glow, bottom-leading, for depth.
            RadialGradient(
                colors: [DS.Macro.carbs.tint.opacity(scheme == .dark ? 0.20 : 0.14), .clear],
                center: .bottomLeading, startRadius: 0, endRadius: 480
            )
            .ignoresSafeArea()
            .blendMode(scheme == .dark ? .screen : .plusDarker)
        }
    }
}

/// A content card with a glassy, layered look (used for grouped content).
struct SoftCard<Content: View>: View {
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
                            .stroke(.white.opacity(0.08), lineWidth: 1)
                    }
            }
    }
}
