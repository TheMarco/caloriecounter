//
//  TryAMealStep.swift
//  Onboarding's no-commitment demo: right after the trust promise, a canned meal
//  reveals into the real MealCard so people *feel* logging — and its honesty
//  (an "Estimated" badge, "about 105 kcal", one-tap adjust) — before being asked
//  for any body data. Pure local: no network, nothing saved.
//

import SwiftUI
import NutritionCore

struct TryAMealStep: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var revealed = false
    /// Local-only scale the demo chips apply, so "adjust" feels real without saving.
    @State private var multiplier = 1.0

    private static let baseKcal = 105.0
    private static let baseProtein = 1.3
    private static let baseCarbs = 27.0
    private static let baseFat = 0.4

    private var sample: SampleMeal {
        SampleMeal(
            foodName: "Banana",
            detail: portionDetail,
            kcal: Self.baseKcal * multiplier,
            protein: Self.baseProtein * multiplier,
            carbs: Self.baseCarbs * multiplier,
            fat: Self.baseFat * multiplier,
            confidence: .estimated,
            sourceLabel: "Photo estimate"
        )
    }

    private var portionDetail: String {
        switch multiplier {
        case 0.5:  return "½ medium · 59 g"
        case 2.0:  return "2 medium · 236 g"
        default:   return "1 medium · 118 g"
        }
    }

    private static let chips: [(label: String, kind: Adjust)] = [
        ("½", .half), ("2×", .double), ("Less", .less), ("More", .more)
    ]
    private enum Adjust { case half, double, less, more }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if revealed {
                MealCard(model: sample) {
                    chipRow
                }
                .transition(Motion.reveal(reduceMotion: reduceMotion))
            }

            Text("This is logging. Tap a chip to adjust — nothing's saved yet.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .onAppear {
            guard !revealed else { return }
            withAnimation(Motion.spring(reduceMotion: reduceMotion)) { revealed = true }
            Haptics.parsed()
        }
    }

    private var chipRow: some View {
        HStack(spacing: 8) {
            ForEach(Self.chips, id: \.label) { chip in
                Button(chip.label) { apply(chip.kind) }
                    .buttonStyle(.bordered)
                    .tint(.secondary)
                    .font(.subheadline.weight(.medium))
                    .frame(maxWidth: .infinity)
            }
        }
        .accessibilityElement(children: .contain)
    }

    private func apply(_ adjust: Adjust) {
        withAnimation(Motion.spring(reduceMotion: reduceMotion)) {
            switch adjust {
            case .half:   multiplier = 0.5
            case .double: multiplier = 2.0
            case .less:   multiplier = max(0.25, multiplier * 0.85)
            case .more:   multiplier = min(4.0, multiplier * 1.15)
            }
        }
        Haptics.adjusted()
    }
}
