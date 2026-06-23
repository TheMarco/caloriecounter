//
//  MacroDashboard.swift
//  The hero: a large gradient calorie ring with the day's net total, plus three
//  satellite macro rings. Reused on Today and the day-detail screen.
//

import SwiftUI
import AppCore
import NutritionCore

/// A single gradient progress ring with a soft glow and over-target halo.
struct MacroRing: View {
    let macro: DS.Macro
    let fraction: Double
    var lineWidth: CGFloat = 16
    var animate: Bool = true

    var body: some View {
        let clamped = max(0, min(fraction, 1))
        ZStack {
            Circle().stroke(macro.tint.opacity(0.16), lineWidth: lineWidth)
            if fraction > 1 {
                Circle().stroke(macro.tint.opacity(0.35), lineWidth: lineWidth)
            }
            Circle()
                .trim(from: 0, to: clamped)
                .stroke(macro.ringGradient, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .shadow(color: macro.tint.opacity(0.5), radius: lineWidth * 0.45)
        }
        .animation(animate ? .smooth(duration: 0.7) : nil, value: clamped)
    }
}

struct MacroDashboard: View {
    let totals: MacroTotals
    let targets: MacroTargets
    let offset: Double

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var net: Double { MacroMath.netCalories(total: totals.calories, offset: offset) }

    private func consumed(_ m: DS.Macro) -> Double {
        switch m {
        case .calories: return totals.calories
        case .protein: return totals.protein
        case .carbs: return totals.carbs
        case .fat: return totals.fat
        }
    }
    private func target(_ m: DS.Macro) -> Double {
        switch m {
        case .calories: return targets.calories
        case .protein: return targets.protein
        case .carbs: return targets.carbs
        case .fat: return targets.fat
        }
    }
    private func fraction(_ m: DS.Macro) -> Double {
        let t = target(m); return t > 0 ? consumed(m) / t : 0
    }

    var body: some View {
        VStack(spacing: 24) {
            ZStack {
                MacroRing(macro: .calories, fraction: fraction(.calories), lineWidth: 22, animate: !reduceMotion)
                    .frame(width: 232, height: 232)
                VStack(spacing: 1) {
                    Text("\(Int(net))")
                        .font(.system(size: 66, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary)
                        .contentTransition(.numericText())
                    Text(offset > 0 ? "net kcal" : "kcal")
                        .font(.callout.weight(.semibold))
                        .foregroundStyle(DS.Macro.calories.tint)
                    Text("of \(Int(targets.calories)) goal")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Calories")
            .accessibilityValue("\(Int(net)) net of \(Int(targets.calories)) goal")

            HStack(spacing: 12) {
                ForEach([DS.Macro.protein, .carbs, .fat]) { m in
                    macroSatellite(m)
                }
            }
        }
    }

    private func macroSatellite(_ m: DS.Macro) -> some View {
        VStack(spacing: 9) {
            ZStack {
                MacroRing(macro: m, fraction: fraction(m), lineWidth: 8, animate: !reduceMotion)
                    .frame(width: 60, height: 60)
                Image(systemName: m.systemImage)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(m.tint)
            }
            VStack(spacing: 1) {
                Text("\(Int(consumed(m)))")
                    .font(.callout.weight(.bold).monospacedDigit())
                    .contentTransition(.numericText())
                Text("/ \(Int(target(m)))g")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Text(m.title.uppercased())
                .font(.system(size: 10, weight: .semibold))
                .tracking(0.5)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(m.title)
        .accessibilityValue("\(Int(consumed(m))) of \(Int(target(m))) grams")
    }
}
