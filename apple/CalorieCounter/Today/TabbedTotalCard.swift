//
//  TabbedTotalCard.swift
//  The macro summary card: a segmented picker over calories/fat/carbs/protein
//  and a progress ring vs the user's targets (port of TabbedTotalCard.tsx).
//  Content layer (not glass).
//

import SwiftUI
import AppCore
import NutritionCore

struct TabbedTotalCard: View {
    let totals: MacroTotals
    let targets: MacroTargets
    let offset: Double

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var macro: Macro = .calories

    enum Macro: String, CaseIterable, Identifiable {
        case calories, fat, carbs, protein
        var id: String { rawValue }
        var title: String {
            switch self {
            case .calories: return "Calories"
            case .fat: return "Fat"
            case .carbs: return "Carbs"
            case .protein: return "Protein"
            }
        }
        var unit: String { self == .calories ? "kcal" : "g" }
        var tint: Color {
            switch self {
            case .calories: return .green
            case .fat: return .yellow
            case .carbs: return .blue
            case .protein: return .pink
            }
        }
    }

    private var consumed: Double {
        switch macro {
        case .calories: return totals.calories
        case .fat: return totals.fat
        case .carbs: return totals.carbs
        case .protein: return totals.protein
        }
    }
    private var target: Double {
        switch macro {
        case .calories: return targets.calories
        case .fat: return targets.fat
        case .carbs: return targets.carbs
        case .protein: return targets.protein
        }
    }
    private var progress: MacroProgress { MacroProgress(consumed: consumed, target: target) }

    var body: some View {
        VStack(spacing: 16) {
            Picker("Macro", selection: $macro) {
                ForEach(Macro.allCases) { Text($0.title).tag($0) }
            }
            .pickerStyle(.segmented)

            ZStack {
                Circle().stroke(.quaternary, lineWidth: 14)
                Circle()
                    .trim(from: 0, to: progress.fraction)
                    .stroke(progress.isOver ? Color.red : macro.tint,
                            style: StrokeStyle(lineWidth: 14, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(reduceMotion ? nil : .snappy, value: progress.fraction)
                VStack(spacing: 4) {
                    Text(consumed, format: .number.precision(.fractionLength(0)))
                        .font(.system(size: 44, weight: .bold, design: .rounded))
                        .contentTransition(.numericText())
                    Text("of \(Int(target)) \(macro.unit)")
                        .font(.subheadline).foregroundStyle(.secondary)
                    if macro == .calories && offset > 0 {
                        Text("Net \(Int(max(consumed - offset, 0))) kcal")
                            .font(.caption).foregroundStyle(.orange)
                    }
                }
            }
            .frame(width: 200, height: 200)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(macro.title)
            .accessibilityValue("\(Int(consumed)) of \(Int(target)) \(macro.unit), \(statusText)")

            Label(statusText, systemImage: progress.isOver ? "exclamationmark.triangle.fill" : "leaf.fill")
                .font(.subheadline)
                .foregroundStyle(progress.isOver ? Color.red : .secondary)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(.background.secondary, in: .rect(cornerRadius: 24))
    }

    private var statusText: String {
        if progress.isOver {
            return "Over by \(Int(consumed - target)) \(macro.unit)"
        }
        return "\(Int(progress.remaining)) \(macro.unit) left"
    }
}
