//
//  FoodConfirmView.swift
//  The shared confirmation sheet every capture flow converges on: edit the name,
//  quantity, and unit; calories+macros recalculate live; Save persists via
//  FoodConfirmModel → store.add. Replaces FoodConfirmDialog.tsx.
//

import SwiftUI
import AppCore
import NutritionCore

struct FoodConfirmView: View {
    @Environment(AppContainer.self) private var container
    let parsed: ParsedFood
    let method: InputMethod
    let onSaved: () -> Void

    @State private var model: FoodConfirmModel?
    @State private var searchText = ""
    @State private var reanalyzing = false

    /// Typed/spoken entries can be re-analyzed in place; a scan can't be re-typed.
    private var canResearch: Bool { method == .text || method == .voice }

    var body: some View {
        Group {
            if let model {
                ConfirmForm(model: model, notes: parsed.notes, onSaved: onSaved,
                            searchTerm: canResearch ? $searchText : nil,
                            reanalyzing: reanalyzing,
                            onReanalyze: reanalyze)
            } else {
                ProgressView()
            }
        }
        .task {
            if model == nil {
                model = FoodConfirmModel(parsed: parsed, method: method, store: container.store)
                searchText = parsed.food
            }
        }
    }

    /// Re-run the parser on an edited search term and replace the result in place,
    /// so you don't have to go back to the search screen.
    private func reanalyze() {
        let q = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty, !reanalyzing else { return }
        reanalyzing = true
        Task {
            let result = try? await container.foodParser.parse(text: q, units: container.settings.units)
            reanalyzing = false
            if let result {
                model = FoodConfirmModel(parsed: result, method: method, store: container.store)
            }
        }
    }
}

private struct ConfirmForm: View {
    @Environment(AppContainer.self) private var container
    @Bindable var model: FoodConfirmModel
    let notes: String?
    let onSaved: () -> Void
    var searchTerm: Binding<String>? = nil
    var reanalyzing: Bool = false
    var onReanalyze: () -> Void = {}

    @Environment(\.dismiss) private var dismiss
    @State private var saving = false

    var body: some View {
        Form {
            if let searchTerm {
                Section {
                    HStack(spacing: 8) {
                        Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                        TextField("Edit search…", text: searchTerm)
                            .submitLabel(.search)
                            .onSubmit(onReanalyze)
                        if reanalyzing { ProgressView() }
                    }
                } footer: {
                    Text("Change what you typed and press search to re-analyze.")
                }
            }
            Section("Food") {
                TextField("Name", text: $model.food)
                    .textInputAutocapitalization(.words)
            }
            Section("Amount") {
                HStack {
                    Text("Quantity")
                    Spacer(minLength: 8)
                    PillTextField(text: $model.quantityText, accessibilityLabel: "Quantity")
                    let units = UnitConversion.compatibleUnits(with: model.unit)
                    if units.count > 1 {
                        Picker("Unit", selection: $model.unit) {
                            ForEach(units, id: \.self) { Text($0).tag($0) }
                        }
                        .labelsHidden()
                    } else {
                        Text(model.unit).foregroundStyle(.secondary)
                    }
                }
            }
            Section("Nutrition (recalculated)") {
                nutritionRow("Calories", model.kcal, "kcal")
                nutritionRow("Fat", model.fat, "g")
                nutritionRow("Carbs", model.carbs, "g")
                nutritionRow("Protein", model.protein, "g")
            }
            if model.hasBreakdown {
                breakdownSection
            } else if model.fiber != nil || model.sodium != nil || model.sugar != nil {
                Section {
                    if let f = model.fiber { nutritionRow("Fiber", f, "g") }
                    if let s = model.sodium { nutritionRow("Sodium", s, "mg") }
                    if let su = model.sugar { nutritionRow("Sugar", su, "g") }
                } header: {
                    Text("Advanced Nutrition").font(.footnote)
                }
            }
            if let notes, !notes.isEmpty {
                Section("Notes") {
                    Text(notes).font(.footnote).foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle("Confirm Food")
        .navigationBarTitleDisplayMode(.inline)
        .keyboardDoneToolbar()
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button {
                    saving = true
                    Task {
                        let entry = await model.save()
                        await container.healthSyncFood(entry)   // no-op unless Health sync is on
                        onSaved()
                    }
                } label: {
                    if saving { ProgressView() } else { Text("Add") }
                }
                .disabled(model.food.trimmingCharacters(in: .whitespaces).isEmpty || model.quantity <= 0 || saving)
            }
        }
    }

    /// A collapsed, editable ingredient breakdown for compound foods. Tap the header
    /// to expand; tap an amount to adjust or swipe to remove — the totals above follow.
    @ViewBuilder
    private var breakdownSection: some View {
        Section {
            Button {
                withAnimation { model.componentsExpanded.toggle() }
            } label: {
                HStack {
                    Text("Breakdown").font(.subheadline)
                    Spacer()
                    Text("^[\(model.components.count) item](inflect: true)")
                        .font(.subheadline).foregroundStyle(.secondary)
                    Image(systemName: model.componentsExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption2).foregroundStyle(.secondary)
                }
            }
            .buttonStyle(.plain)

            if model.componentsExpanded {
                ForEach(model.components.indices, id: \.self) { index in
                    BreakdownRow(component: model.components[index]) { newGrams in
                        model.setComponentGrams(at: index, to: newGrams)
                    }
                }
                .onDelete { offsets in
                    for i in offsets.sorted(by: >) { model.removeComponent(at: i) }
                }
            }
        } footer: {
            if model.componentsExpanded {
                Text("Tap an amount to adjust, or swipe to remove. The totals above update to match.")
                    .font(.caption2)
            }
        }
    }

    private func nutritionRow(_ label: String, _ value: Double, _ unit: String) -> some View {
        LabeledContent(label) {
            Text("\(value.formatted(.number.precision(.fractionLength(0...1)))) \(unit)")
                .contentTransition(.numericText())
                .monospacedDigit()
        }
    }

}

/// One editable ingredient line: name · [amount g] pill · kcal. The amount is a
/// free-text buffer (so you can clear and retype) committed live when valid, in the
/// app's standard value-pill styling with the caret-to-end AmountField.
private struct BreakdownRow: View {
    let component: FoodComponent
    let onGramsChanged: (Double) -> Void

    @State private var text = ""
    @State private var editing = false

    var body: some View {
        HStack(spacing: 10) {
            Text(component.name)
                .font(.subheadline)
                .lineLimit(1)
            Spacer(minLength: 8)

            HStack(spacing: 3) {
                AmountField(text: $text,
                            onEditingChanged: { isEditing in
                                editing = isEditing
                                if !isEditing { normalize() }
                            },
                            onChange: applyLive)
                    .frame(minWidth: 22)
                Text("g").font(.subheadline).foregroundStyle(.secondary)
            }
            .valuePill(editing: editing)

            Text("\(Int(component.kcal.rounded())) kcal")
                .font(.caption)
                .foregroundStyle(.secondary)
                .monospacedDigit()
                .frame(minWidth: 58, alignment: .trailing)
        }
        .onAppear { text = Self.gramText(component.grams) }
        .onChange(of: component.grams) { _, grams in
            if !editing { text = Self.gramText(grams) }   // reflect external rescales
        }
    }

    /// Apply a valid amount as it's typed; ignore blank/partial input so the field
    /// can be cleared and retyped.
    private func applyLive() {
        if let grams = Double(text), grams >= 0 { onGramsChanged(grams) }
    }

    /// On blur, commit and normalize the text (restores the canonical value if left blank).
    private func normalize() {
        if let grams = Double(text), grams >= 0 { onGramsChanged(grams) }
        text = Self.gramText(component.grams)
    }

    private static func gramText(_ grams: Double) -> String {
        grams == grams.rounded() ? String(Int(grams)) : String(format: "%.1f", grams)
    }
}
