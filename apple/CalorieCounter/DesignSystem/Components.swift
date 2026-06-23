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

/// Friendly empty state for a day with no entries.
struct EmptyDayCard: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "fork.knife.circle.fill")
                .font(.system(size: 44))
                .foregroundStyle(DS.Macro.calories.linearGradient)
            Text("Nothing logged yet")
                .font(.headline)
            Text("Tap a button below to scan, speak, type, or snap your first food.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 28)
        .padding(.horizontal, 20)
    }
}
