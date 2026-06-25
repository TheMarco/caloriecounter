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

    @Environment(\.colorScheme) private var scheme
    @Environment(\.colorSchemeContrast) private var contrast

    /// Unfilled-track opacity. Lighter backdrops and Increase Contrast need a
    /// stronger track so the ring's progress reads clearly.
    private var trackOpacity: Double {
        let base = scheme == .dark ? 0.16 : 0.24
        return contrast == .increased ? min(base + 0.12, 0.5) : base
    }

    var body: some View {
        let over = fraction > 1
        let clamped = max(0, min(fraction, 1))
        let overage = over ? min(fraction - 1, 1) : 0   // how far past 100%, wrapped once
        ZStack {
            Circle().stroke(macro.tint.opacity(trackOpacity), lineWidth: lineWidth)

            // Base fill — completes the full ring once the target is reached.
            Circle()
                .trim(from: 0, to: over ? 1 : clamped)
                .stroke(macro.ringGradient, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .shadow(color: macro.tint.opacity(0.18), radius: lineWidth * 0.15)

            // Overage arc — wraps back over the ring in warning red so going over
            // the limit is unmistakable (more excess → more red).
            if over {
                Circle()
                    .trim(from: 0, to: overage)
                    .stroke(DS.overGradient, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .shadow(color: DS.over.opacity(0.45), radius: lineWidth * 0.3)
            }
        }
        .animation(animate ? .smooth(duration: 0.7) : nil, value: clamped)
        .animation(animate ? .smooth(duration: 0.7) : nil, value: overage)
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
    private func isOver(_ m: DS.Macro) -> Bool { consumed(m) > target(m) && target(m) > 0 }

    // Calories track the headline *net* number against the goal, so the ring, the
    // big number, and the over-indicator all agree (exercise raises the budget).
    private var calorieFraction: Double { targets.calories > 0 ? net / targets.calories : 0 }
    private var caloriesOver: Bool { net > targets.calories && targets.calories > 0 }

    var body: some View {
        VStack(spacing: 38) {
            ZStack {
                MacroRing(macro: .calories, fraction: calorieFraction, lineWidth: 22, animate: !reduceMotion)
                    .frame(width: 232, height: 232)
                VStack(spacing: 1) {
                    Text("\(Int(net))")
                        .font(.system(size: 66, weight: .bold, design: .rounded))
                        .foregroundStyle(caloriesOver ? AnyShapeStyle(DS.over) : AnyShapeStyle(.primary))
                        .contentTransition(.numericText())
                    Text(offset > 0 ? "net kcal" : "kcal")
                        .font(.callout.weight(.semibold))
                        .foregroundStyle(caloriesOver ? DS.over : DS.Macro.calories.tint)
                    if caloriesOver {
                        Text("\(Int(net - targets.calories)) over")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(DS.over)
                    } else {
                        Text("of \(Int(targets.calories)) goal")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Calories")
            .accessibilityValue(caloriesOver
                ? "\(Int(net)) net, over the \(Int(targets.calories)) goal by \(Int(net - targets.calories))"
                : "\(Int(net)) net of \(Int(targets.calories)) goal")

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
                    .foregroundStyle(isOver(m) ? AnyShapeStyle(DS.over) : AnyShapeStyle(.primary))
                    .contentTransition(.numericText())
                if isOver(m) {
                    Text("\(Int(consumed(m) - target(m)))g over")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(DS.over)
                } else {
                    Text("/ \(Int(target(m)))g")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            Text(m.title.uppercased())
                .font(.system(size: 10, weight: .semibold))
                .tracking(0.5)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(m.title)
        .accessibilityValue(isOver(m)
            ? "\(Int(consumed(m))) grams, over the \(Int(target(m))) gram target by \(Int(consumed(m) - target(m)))"
            : "\(Int(consumed(m))) of \(Int(target(m))) grams")
    }
}
