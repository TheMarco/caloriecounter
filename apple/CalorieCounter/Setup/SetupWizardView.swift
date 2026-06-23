//
//  SetupWizardView.swift
//  Goal-based onboarding: pick a goal, enter body stats and activity, and the app
//  computes daily calorie + macro targets (GoalPlanner). Shown on first launch and
//  re-runnable from Settings.
//

import SwiftUI
import AppCore
import NutritionCore

struct SetupWizardView: View {
    @Environment(AppContainer.self) private var container
    @Environment(\.dismiss) private var dismiss
    let onFinish: () -> Void

    @State private var step = 0
    @State private var goal: WeightGoal?
    @State private var sex: BiologicalSex = .male
    @State private var age = 30
    // Body stats are stored canonically in metric; the fields convert for display
    // so switching units is always lossless and the defaults suit either system.
    @State private var weightKg = 75.0
    @State private var heightCm = 175.0
    @State private var activity: ActivityLevel = .moderate

    private var units: UnitSystem { container.settings.units }
    private let stepCount = 4

    private static let lbPerKg = 2.2046226

    var body: some View {
        ZStack {
            AppBackground()
            VStack(spacing: 0) {
                header
                ScrollView {
                    Group {
                        switch step {
                        case 0: goalStep
                        case 1: bodyStep
                        case 2: activityStep
                        default: planStep
                        }
                    }
                    .padding(.horizontal, DS.screenPadding)
                    .padding(.top, 8)
                }
                footer
            }
        }
    }

    // MARK: - Chrome

    private var header: some View {
        VStack(spacing: 14) {
            HStack(spacing: 6) {
                ForEach(0..<stepCount, id: \.self) { i in
                    Capsule()
                        .fill(i <= step ? AnyShapeStyle(DS.Macro.calories.linearGradient) : AnyShapeStyle(Color.secondary.opacity(0.25)))
                        .frame(height: 5)
                }
            }
            Text(title)
                .font(.largeTitle.weight(.bold))
                .frame(maxWidth: .infinity, alignment: .leading)
            Text(subtitle)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, DS.screenPadding)
        .padding(.top, 16)
        .padding(.bottom, 8)
    }

    private var footer: some View {
        HStack(spacing: 12) {
            if step > 0 {
                Button { withAnimation(.snappy) { step -= 1 } } label: {
                    Text("Back").frame(maxWidth: .infinity).padding(.vertical, 6)
                }
                .buttonStyle(.glass)
            }
            Button {
                if step < stepCount - 1 {
                    withAnimation(.snappy) { step += 1 }
                } else {
                    finish()
                }
            } label: {
                Text(step < stepCount - 1 ? "Continue" : "Start Tracking")
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity).padding(.vertical, 6)
            }
            .buttonStyle(.glassProminent)
            .tint(DS.Macro.calories.tint)
            .disabled(step == 0 && goal == nil)
        }
        .padding(DS.screenPadding)
    }

    private var title: String {
        switch step {
        case 0: return "Your Goal"
        case 1: return "About You"
        case 2: return "Activity"
        default: return "Your Plan"
        }
    }
    private var subtitle: String {
        switch step {
        case 0: return "What are you working toward?"
        case 1: return "We use this to estimate your needs."
        case 2: return "How active are you day to day?"
        default: return "Tuned to your goal — adjust anytime in Settings."
        }
    }

    // MARK: - Steps

    private var goalStep: some View {
        VStack(spacing: 12) {
            ForEach(WeightGoal.allCases) { g in
                Button { goal = g } label: { goalCard(g) }
                    .buttonStyle(.plain)
            }
        }
    }

    private func goalCard(_ g: WeightGoal) -> some View {
        let selected = goal == g
        let color = goalColor(g)
        return HStack(spacing: 14) {
            ZStack {
                Circle().fill(color.opacity(0.18))
                Image(systemName: g.systemImage).font(.system(size: 20, weight: .semibold)).foregroundStyle(color)
            }
            .frame(width: 48, height: 48)
            VStack(alignment: .leading, spacing: 3) {
                Text(g.label).font(.headline)
                Text(g.detail).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                .font(.title3)
                .foregroundStyle(selected ? color : Color.secondary.opacity(0.4))
        }
        .padding(16)
        .background {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay {
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(selected ? color.opacity(0.7) : .white.opacity(0.06), lineWidth: selected ? 2 : 1)
                }
        }
    }

    private var bodyStep: some View {
        VStack(spacing: 16) {
            SoftCard {
                VStack(spacing: 18) {
                    labeledRow("Units") {
                        Picker("", selection: unitsBinding) {
                            ForEach(UnitSystem.allCases, id: \.self) { Text($0.label).tag($0) }
                        }
                        .pickerStyle(.segmented)
                        .frame(width: 180)
                    }
                    Divider()
                    labeledRow("Sex") {
                        Picker("", selection: $sex) {
                            ForEach(BiologicalSex.allCases) { Text($0.label).tag($0) }
                        }
                        .pickerStyle(.segmented)
                        .frame(width: 180)
                    }
                    Divider()
                    labeledRow("Age") {
                        Stepper("\(age)", value: $age, in: 14...100).fixedSize()
                    }
                    Divider()
                    labeledRow(units == .metric ? "Weight (kg)" : "Weight (lb)") {
                        numberField(weightFieldBinding)
                    }
                    Divider()
                    if units == .metric {
                        labeledRow("Height (cm)") { numberField($heightCm) }
                    } else {
                        labeledRow("Height") {
                            HStack(spacing: 6) {
                                Picker("", selection: heightFtBinding) { ForEach(3...8, id: \.self) { Text("\($0) ft").tag($0) } }
                                Picker("", selection: heightInBinding) { ForEach(0...11, id: \.self) { Text("\($0) in").tag($0) } }
                            }
                            .pickerStyle(.menu)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Unit-aware bindings (canonical storage is metric)

    private var unitsBinding: Binding<UnitSystem> {
        Binding(get: { container.settings.units },
                set: { container.settings.units = $0 })
    }

    /// Weight shown in the current system; writes convert back to kg.
    private var weightFieldBinding: Binding<Double> {
        Binding(
            get: { units == .metric ? weightKg : (weightKg * Self.lbPerKg) },
            set: { weightKg = units == .metric ? $0 : ($0 / Self.lbPerKg) }
        )
    }

    private var totalInches: Int { Int((heightCm / 2.54).rounded()) }
    private var heightFtBinding: Binding<Int> {
        Binding(
            get: { totalInches / 12 },
            set: { heightCm = (Double($0) * 12 + Double(totalInches % 12)) * 2.54 }
        )
    }
    private var heightInBinding: Binding<Int> {
        Binding(
            get: { totalInches % 12 },
            set: { heightCm = (Double(totalInches / 12) * 12 + Double($0)) * 2.54 }
        )
    }

    private var activityStep: some View {
        VStack(spacing: 12) {
            ForEach(ActivityLevel.allCases) { level in
                Button { activity = level } label: {
                    HStack(spacing: 14) {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(level.label).font(.headline)
                            Text(level.detail).font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Image(systemName: activity == level ? "checkmark.circle.fill" : "circle")
                            .font(.title3)
                            .foregroundStyle(activity == level ? DS.Macro.calories.tint : Color.secondary.opacity(0.4))
                    }
                    .padding(16)
                    .background {
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .fill(.ultraThinMaterial)
                            .overlay {
                                RoundedRectangle(cornerRadius: 20, style: .continuous)
                                    .stroke(activity == level ? DS.Macro.calories.tint.opacity(0.6) : .white.opacity(0.06),
                                            lineWidth: activity == level ? 2 : 1)
                            }
                    }
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var planStep: some View {
        let targets = GoalPlanner.targets(for: profile)
        return VStack(spacing: 18) {
            MacroDashboard(totals: .zero, targets: targets, offset: 0)
                .padding(.top, 4)
            SoftCard {
                VStack(spacing: 12) {
                    planRow("Daily Calories", "\(Int(targets.calories)) kcal", DS.Macro.calories)
                    planRow("Protein", "\(Int(targets.protein)) g", DS.Macro.protein)
                    planRow("Carbs", "\(Int(targets.carbs)) g", DS.Macro.carbs)
                    planRow("Fat", "\(Int(targets.fat)) g", DS.Macro.fat)
                }
            }
            Text("Based on a \(Int(GoalPlanner.tdee(profile))) kcal maintenance estimate.")
                .font(.caption).foregroundStyle(.tertiary)
        }
    }

    // MARK: - Helpers

    private func labeledRow<Content: View>(_ label: String, @ViewBuilder _ content: () -> Content) -> some View {
        HStack {
            Text(label).font(.body.weight(.medium))
            Spacer()
            content()
        }
    }

    private func numberField(_ value: Binding<Double>) -> some View {
        TextField("", value: value, format: .number.precision(.fractionLength(0...1)))
            .keyboardType(.decimalPad)
            .multilineTextAlignment(.trailing)
            .frame(width: 90)
            .textFieldStyle(.roundedBorder)
    }

    private func planRow(_ label: String, _ value: String, _ macro: DS.Macro) -> some View {
        HStack {
            Circle().fill(macro.tint).frame(width: 8, height: 8)
            Text(label)
            Spacer()
            Text(value).fontWeight(.semibold).monospacedDigit()
        }
    }

    private func goalColor(_ g: WeightGoal) -> Color {
        switch g {
        case .radicalLoss: return DS.Macro.fat.tint
        case .steadyLoss: return DS.Macro.calories.tint
        case .maintain: return DS.Macro.carbs.tint
        case .gain: return Color(hex: 0xBF5AF2)
        }
    }

    private var profile: UserProfile {
        UserProfile(sex: sex, age: age, weightKg: weightKg, heightCm: heightCm,
                    activity: activity, goal: goal ?? .maintain)
    }

    private func finish() {
        container.settings.targets = GoalPlanner.targets(for: profile)
        container.settings.hasCompletedSetup = true
        // Seed the weight history with the starting weight from onboarding.
        let today = LocalDate.today()
        let weight = WeightEntry(id: WeightEntry.id(for: today), date: today, timestamp: Date(), weightKg: weightKg)
        Task {
            try? await container.store.addWeight(weight)
            container.dataDidChange()
        }
        onFinish()
        dismiss()
    }
}
