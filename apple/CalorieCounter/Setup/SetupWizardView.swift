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
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast
    /// Whether the user can back out without finishing (true when re-run from
    /// Settings; false for mandatory first-launch onboarding).
    var allowsCancel: Bool = false
    let onFinish: () -> Void

    @State private var step = 0
    @State private var goal: WeightGoal?
    @State private var diet: DietStyle = .balanced
    @State private var sex: BiologicalSex = .male
    @State private var age = 30
    // Body stats are stored canonically in metric; the fields convert for display
    // so switching units is always lossless and the defaults suit either system.
    @State private var weightKg = 75.0
    @State private var heightCm = 175.0
    @State private var activity: ActivityLevel = .moderate

    private var units: UnitSystem { container.settings.units }
    private let stepCount = 5

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
                        case 1: dietStep
                        case 2: bodyStep
                        case 3: activityStep
                        default: planStep
                        }
                    }
                    .padding(.horizontal, DS.screenPadding)
                    .padding(.top, 8)
                }
                .scrollDismissesKeyboard(.interactively)
                .keyboardDoneToolbar()
                footer
            }
        }
        .task { await prefill() }
    }

    // MARK: - Chrome

    private var header: some View {
        VStack(spacing: 14) {
            if allowsCancel {
                HStack {
                    Button("Cancel") { dismiss() }
                        .tint(DS.Macro.calories.tint)
                    Spacer()
                }
            }
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
        case 1: return "Diet Style"
        case 2: return "About You"
        case 3: return "Activity"
        default: return "Your Plan"
        }
    }
    private var subtitle: String {
        switch step {
        case 0: return "What are you working toward?"
        case 1: return "How do you like to eat?"
        case 2: return "We use this to estimate your needs."
        case 3: return "How active are you day to day?"
        default: return "Tuned to your goal — adjust anytime in Settings."
        }
    }

    // MARK: - Steps

    private var goalStep: some View {
        VStack(spacing: 12) {
            ForEach(WeightGoal.allCases) { g in
                Button { goal = g } label: { goalCard(g) }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(goal == g ? .isSelected : [])
            }
        }
    }

    private var dietStep: some View {
        VStack(spacing: 12) {
            ForEach(DietStyle.allCases) { d in
                Button { diet = d } label: { dietCard(d) }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(diet == d ? .isSelected : [])
            }
        }
    }

    private func goalCard(_ g: WeightGoal) -> some View {
        selectableCard(selected: goal == g, color: goalColor(g), icon: g.systemImage) {
            Text(g.label).font(.headline)
            Text(g.detail).font(.caption).foregroundStyle(.secondary)
        }
    }

    private func dietCard(_ d: DietStyle) -> some View {
        let color = DS.Macro.calories.tint
        return selectableCard(selected: diet == d, color: color, icon: d.systemImage) {
            Text(d.label).font(.headline)
            Text(d.detail).font(.caption).foregroundStyle(.secondary)
            Text(d.splitLabel).font(.caption2.weight(.semibold)).foregroundStyle(color)
        }
    }

    /// A selectable option card (goal / diet / activity). At accessibility text sizes
    /// it reflows to a vertical layout — icon and checkmark on a top row, the label
    /// full-width below — so big text doesn't squeeze into a narrow middle column and
    /// the controls don't strand. Otherwise it's the standard icon · text · check row.
    @ViewBuilder
    private func selectableCard<Content: View>(
        selected: Bool, color: Color, icon: String? = nil, cornerRadius: CGFloat = 22,
        @ViewBuilder content: () -> Content
    ) -> some View {
        let text = VStack(alignment: .leading, spacing: 4) { content() }
            .frame(maxWidth: .infinity, alignment: .leading)
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        if let icon { iconBadge(icon, color) }
                        Spacer()
                        selectionMark(selected, color)
                    }
                    text
                }
            } else {
                HStack(spacing: 14) {
                    if let icon { iconBadge(icon, color) }
                    text
                    selectionMark(selected, color)
                }
            }
        }
        .fixedSize(horizontal: false, vertical: true)
        .padding(16)
        .background {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .stroke(selected ? color.opacity(0.7) : DS.cardBorder(colorScheme, colorSchemeContrast),
                                lineWidth: selected ? 2 : 1)
                }
                .shadow(color: colorScheme == .dark ? .clear : .black.opacity(0.05), radius: 7, y: 2)
        }
    }

    private func iconBadge(_ name: String, _ color: Color) -> some View {
        ZStack {
            Circle().fill(color.opacity(0.18))
            Image(systemName: name).font(.system(size: 20, weight: .semibold)).foregroundStyle(color)
        }
        .frame(width: 48, height: 48)
    }

    private func selectionMark(_ selected: Bool, _ color: Color) -> some View {
        Image(systemName: selected ? "checkmark.circle.fill" : "circle")
            .font(.title3)
            .foregroundStyle(selected ? color : Color.secondary.opacity(0.4))
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
                    labeledRow("Age") { ageChip }
                    Divider()
                    labeledRow("Weight") {
                        numberField("weight", weightFieldBinding, unit: units.weightUnit, decimals: 1)
                    }
                    Divider()
                    if units == .metric {
                        labeledRow("Height") { numberField("height", $heightCm, unit: "cm") }
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
                    selectableCard(selected: activity == level, color: DS.Macro.calories.tint, cornerRadius: 20) {
                        Text(level.label).font(.headline)
                        Text(level.detail).font(.caption).foregroundStyle(.secondary)
                    }
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(activity == level ? .isSelected : [])
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
            Text("These are estimates to get you started, not medical advice. If you have a health condition or specific goals, check with a doctor or registered dietitian.")
                .font(.caption2).foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 4)
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

    /// A value pill matching the rest of the app (caret-to-end, green-check dismiss).
    private func numberField(_ id: String, _ value: Binding<Double>, unit: String? = nil, decimals: Int = 0) -> some View {
        PillNumberField(value: value, unit: unit, decimals: decimals,
                        accessibilityLabel: id.capitalized, onCommit: clampInputs)
    }

    private var ageChip: some View {
        PillNumberField(value: Binding(get: { Double(age) }, set: { age = Int($0.rounded()) }),
                        accessibilityLabel: "Age", keyboard: .numberPad, onCommit: clampInputs)
    }

    /// Snap typed values into sane ranges when the keyboard closes.
    private func clampInputs() {
        age = min(max(age, 14), 100)
        weightKg = min(max(weightKg, 25), 400)
        heightCm = min(max(heightCm, 90), 250)
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
                    activity: activity, goal: goal ?? .maintain, dietStyle: diet)
    }

    private func finish() {
        container.settings.targets = GoalPlanner.targets(for: profile)
        container.settings.savedProfile = profile   // basis for pre-fill + the weight-drift nudge
        container.settings.hasCompletedSetup = true
        // Seed the weight history with the weight used for this plan.
        let today = LocalDate.today()
        let weight = WeightEntry(id: WeightEntry.id(for: today), date: today, timestamp: Date(), weightKg: weightKg)
        Task {
            try? await container.store.addWeight(weight)
            container.dataDidChange()
        }
        onFinish()
        dismiss()
    }

    /// On re-run, pre-fill the user's previous answers and their latest weigh-in.
    private func prefill() async {
        if let p = container.settings.savedProfile {
            sex = p.sex; age = p.age; heightCm = p.heightCm
            weightKg = p.weightKg; activity = p.activity; diet = p.dietStyle; goal = p.goal
        }
        if let latest = (try? await container.store.latestWeight())?.weightKg {
            weightKg = latest   // prefer current weight (drives the nudge's recalc)
        }
    }
}
