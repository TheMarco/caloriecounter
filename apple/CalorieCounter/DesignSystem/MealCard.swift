//
//  MealCard.swift
//  The signature confirmation card — the most memorable, most *honest* moment in
//  the app. Every capture (text/voice/photo/barcode) reveals into this one card,
//  and the onboarding "try a meal" demo reuses it. Pure presentation: it reads a
//  `MealCardModel` (which `FoodConfirmModel` and the demo both satisfy) and takes
//  an `accessory` slot for the correction chips / breakdown the host supplies.
//

import SwiftUI
import NutritionCore

/// The thin data contract MealCard renders. Kept minimal so both the live confirm
/// model and a canned onboarding sample can satisfy it.
protocol MealCardModel {
    var foodName: String { get }
    /// A short serving subtitle, e.g. "1 medium · banana" or "100 g".
    var detail: String { get }
    var kcal: Double { get }
    var protein: Double { get }
    var carbs: Double { get }
    var fat: Double { get }
    var confidence: NutritionConfidence? { get }
    /// Optional capture phrasing for the source row, e.g. "Photo estimate".
    var sourceLabel: String? { get }
}

struct MealCard<Accessory: View>: View {
    let foodName: String
    let detail: String
    let kcal: Double
    let protein: Double
    let carbs: Double
    let fat: Double
    let confidence: NutritionConfidence?
    let sourceLabel: String?
    @ViewBuilder var accessory: Accessory

    @Environment(\.colorScheme) private var scheme
    @Environment(\.colorSchemeContrast) private var contrast

    init(
        foodName: String,
        detail: String,
        kcal: Double,
        protein: Double,
        carbs: Double,
        fat: Double,
        confidence: NutritionConfidence?,
        sourceLabel: String? = nil,
        @ViewBuilder accessory: () -> Accessory = { EmptyView() }
    ) {
        self.foodName = foodName
        self.detail = detail
        self.kcal = kcal
        self.protein = protein
        self.carbs = carbs
        self.fat = fat
        self.confidence = confidence
        self.sourceLabel = sourceLabel
        self.accessory = accessory()
    }

    /// Build directly from any model satisfying the contract.
    init(model: any MealCardModel, @ViewBuilder accessory: () -> Accessory = { EmptyView() }) {
        self.init(
            foodName: model.foodName, detail: model.detail, kcal: model.kcal,
            protein: model.protein, carbs: model.carbs, fat: model.fat,
            confidence: model.confidence, sourceLabel: model.sourceLabel, accessory: accessory
        )
    }

    @Environment(\.dynamicTypeSize) private var typeSize

    private var isExact: Bool { ConfidenceDisplay.from(confidence).isExact }
    private var displayKcal: Int {
        isExact ? Int(kcal.rounded()) : HonestNumber.estimateRounded(kcal)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header

            heroNumber

            macroChips

            ConfidenceBadge(confidence: confidence, style: .sourceRow, sourceLabel: sourceLabel)

            accessory
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: DS.cardRadius, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay {
                    RoundedRectangle(cornerRadius: DS.cardRadius, style: .continuous)
                        .stroke(DS.cardBorder(scheme, contrast), lineWidth: 1)
                }
                .shadow(color: scheme == .dark ? .clear : .black.opacity(0.06), radius: 10, y: 4)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(accessibilitySummary)
    }

    /// The honest hero number: "about N" for estimates, exact otherwise. Built as a
    /// single concatenated Text so the whole "about N kcal" line scales as one unit
    /// (reliable shrink-to-fit at AX5, where an HStack of separate Texts overflows).
    private var heroNumber: some View {
        var line = AttributedString()
        if !isExact {
            var about = AttributedString("about ")
            about.font = .title3.weight(.semibold)
            about.foregroundColor = .secondary
            line.append(about)
        }
        var number = AttributedString("\(displayKcal)")
        number.font = .system(size: 52, weight: .bold, design: .rounded)
        number.foregroundColor = DS.Macro.calories.tint
        line.append(number)
        var unit = AttributedString(" kcal")
        unit.font = .title3.weight(.semibold)
        unit.foregroundColor = .secondary
        line.append(unit)
        return Text(line)
            .monospacedDigit()
            .lineLimit(1)
            .minimumScaleFactor(0.4)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// Name + provenance badge. They sit side-by-side normally; at accessibility
    /// text sizes the badge drops below the name so neither is squeezed off-card.
    @ViewBuilder
    private var header: some View {
        let name = VStack(alignment: .leading, spacing: 3) {
            Text(foodName)
                .font(.title2.weight(.bold))
                .lineLimit(2)
            if !detail.isEmpty {
                Text(detail)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        if typeSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: 8) {
                name
                ConfidenceBadge(confidence: confidence)
            }
        } else {
            HStack(alignment: .top) {
                name
                Spacer(minLength: 8)
                ConfidenceBadge(confidence: confidence)
            }
        }
    }

    /// Protein / carbs / fat chips. A single row normally; a vertical stack at
    /// accessibility sizes, where three full-width chips can't share a line.
    @ViewBuilder
    private var macroChips: some View {
        if typeSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: 8) {
                macroChip(.protein, protein)
                macroChip(.carbs, carbs)
                macroChip(.fat, fat)
            }
        } else {
            HStack(spacing: 10) {
                macroChip(.protein, protein)
                macroChip(.carbs, carbs)
                macroChip(.fat, fat)
            }
        }
    }

    private var accessibilitySummary: String {
        let provenance = ConfidenceDisplay.from(confidence).title
        let kcalPhrase = isExact ? "\(displayKcal) calories" : "about \(displayKcal) calories"
        return "\(foodName), \(detail.isEmpty ? "" : detail + ", ")\(kcalPhrase), \(provenance)"
    }

    private func macroChip(_ macro: DS.Macro, _ grams: Double) -> some View {
        HStack(spacing: 6) {
            Circle().fill(macro.tint).frame(width: 7, height: 7)
            Text(macro.title)
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
                .lineLimit(1)
            Text("\(Int(grams.rounded()))g")
                .font(.caption.weight(.semibold).monospacedDigit())
                .lineLimit(1)
        }
        .fixedSize(horizontal: false, vertical: true)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Capsule().fill(macro.tint.opacity(0.12)))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(macro.title) \(Int(grams.rounded())) grams")
    }
}

/// A plain value sample for previews and the onboarding "try a meal" demo.
struct SampleMeal: MealCardModel {
    var foodName: String
    var detail: String
    var kcal: Double
    var protein: Double
    var carbs: Double
    var fat: Double
    var confidence: NutritionConfidence?
    var sourceLabel: String?
}

#Preview("MealCard", traits: .sizeThatFitsLayout) {
    VStack(spacing: 20) {
        MealCard(model: SampleMeal(
            foodName: "Banana", detail: "1 medium · 118 g",
            kcal: 105, protein: 1.3, carbs: 27, fat: 0.4,
            confidence: .estimated, sourceLabel: "Photo estimate"
        ))
        MealCard(model: SampleMeal(
            foodName: "Greek Yogurt", detail: "1 cup · 245 g",
            kcal: 146, protein: 25, carbs: 8, fat: 4,
            confidence: .barcode, sourceLabel: "Barcode"
        ))
    }
    .padding()
    .background(AppBackground())
}
