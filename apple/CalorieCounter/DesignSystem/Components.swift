//
//  Components.swift
//  Shared glass content components: entry cards, the exercise-offset chip, and
//  the empty state.
//

import SwiftUI
import NutritionCore

/// Per–input-method accent color for icons.
extension InputMethod {
    var accent: Color {
        switch self {
        case .barcode: return Color(hex: 0x5E5CE6)   // indigo
        case .voice:   return Color(hex: 0xFF375F)   // pink
        case .text:    return Color(hex: 0x0A84FF)   // blue
        case .photo:   return Color(hex: 0xFF9F0A)   // amber
        case .label:   return Color(hex: 0x30D158)   // green
        }
    }

    /// Short verb-y label for the capture buttons ("Scan / Speak / Type / Photo").
    var shortLabel: String {
        switch self {
        case .barcode: return "Scan"
        case .voice:   return "Speak"
        case .text:    return "Type"
        case .photo:   return "Photo"
        case .label:   return "Label"
        }
    }
}

/// A single logged food, as a floating glass card.
struct EntryCard: View {
    let entry: Entry

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle().fill(.secondary.opacity(0.12))
                Image(systemName: entry.method.systemImage)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
            .frame(width: 44, height: 44)

            VStack(alignment: .leading, spacing: 3) {
                Text(entry.food)
                    .font(.body.weight(.semibold))
                    .lineLimit(1)
                Text("\(quantity) \(entry.unit)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 5) {
                HStack(alignment: .firstTextBaseline, spacing: 3) {
                    Text("\(Int(entry.kcal))")
                        .font(.title3.weight(.bold).monospacedDigit())
                        .foregroundStyle(DS.Macro.calories.tint)
                    Text("kcal").font(.caption2).foregroundStyle(.secondary)
                }
                HStack(spacing: 8) {
                    macroPip(.protein, entry.protein)
                    macroPip(.carbs, entry.carbs)
                    macroPip(.fat, entry.fat)
                }
            }
        }
        .padding(14)
        .background {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay {
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(.white.opacity(0.06), lineWidth: 1)
                }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(entry.food), \(quantity) \(entry.unit), \(Int(entry.kcal)) calories")
    }

    private var quantity: String {
        entry.quantity.formatted(.number.precision(.fractionLength(0...2)))
    }

    private func macroPip(_ m: DS.Macro, _ value: Double) -> some View {
        HStack(spacing: 3) {
            Circle().fill(m.tint).frame(width: 6, height: 6)
            Text("\(Int(value))")
                .font(.caption2.monospacedDigit())
                .foregroundStyle(.secondary)
        }
    }
}

/// Exercise / adjustment offset, as a tappable glass pill.
struct OffsetChip: View {
    let offset: Double
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 13) {
                ZStack {
                    Circle().fill(DS.Macro.fat.tint.opacity(0.18))
                    Image(systemName: "flame.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(DS.Macro.fat.tint)
                }
                .frame(width: 40, height: 40)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Exercise & Adjustments")
                        .font(.subheadline.weight(.semibold))
                    Text(offset > 0 ? "Burning \(Int(offset)) kcal today" : "Tap to log calories burned")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if offset > 0 {
                    Text("−\(Int(offset))")
                        .font(.callout.weight(.bold).monospacedDigit())
                        .foregroundStyle(DS.Macro.fat.tint)
                }
                Image(systemName: "chevron.right").font(.caption.weight(.semibold)).foregroundStyle(.tertiary)
            }
            .padding(14)
            .background {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay {
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .stroke(.white.opacity(0.06), lineWidth: 1)
                    }
            }
        }
        .buttonStyle(.plain)
    }
}

/// A brief green halo on a freshly-logged entry — the "it landed" cue that pairs
/// with the ring ticking up. Fades out shortly after appearing (instant under
/// Reduce Motion).
private struct JustLoggedHighlight: ViewModifier {
    let active: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var faded = false

    func body(content: Content) -> some View {
        content
            .overlay {
                if active {
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(DS.Macro.calories.tint, lineWidth: 2)
                        .shadow(color: DS.Macro.calories.tint.opacity(0.5), radius: 8)
                        .opacity(faded ? 0 : 0.9)
                        .allowsHitTesting(false)
                }
            }
            .task(id: active) {
                guard active else { return }
                faded = false
                withAnimation(.easeOut(duration: reduceMotion ? 0.01 : 1.2)) { faded = true }
            }
    }
}

extension View {
    /// Briefly halo this row when it's the entry that was just logged.
    func justLoggedHighlight(_ active: Bool) -> some View {
        modifier(JustLoggedHighlight(active: active))
    }
}

/// The Settings gear for the top-right toolbar — a quiet affordance, not a floating
/// feature button: a thin glyph at ~78% of the label color, no glass bubble/glow,
/// with a full 44pt tap target.
struct SettingsGearButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "gearshape")
                .font(.system(size: 18, weight: .regular))
                .foregroundStyle(.primary.opacity(0.78))
                .frame(width: 44, height: 44)        // keep the tap target generous…
                .contentShape(.rect)
        }
        .buttonStyle(.plain)                          // …drop the iOS 26 glass capsule
        .accessibilityLabel("Settings")
    }
}

/// Dock-aware empty state: one short, quiet invitation that points to the dock's
/// "+". No green bubble competing with the +, no paragraph, no duplicated button.
struct EmptyDayCard: View {
    var body: some View {
        VStack(spacing: 8) {
            Text("Start with a meal")
                .font(.headline)
                .foregroundStyle(.primary)
            Text("Tap the + below to log your first food.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            // A soft cue toward the "+" in the dock below.
            Image(systemName: "chevron.compact.down")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(.tertiary)
                .padding(.top, 2)
                .accessibilityHidden(true)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 28)
        .padding(.horizontal, 20)
        .accessibilityElement(children: .combine)
    }
}
