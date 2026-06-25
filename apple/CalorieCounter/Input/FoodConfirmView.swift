//
//  FoodConfirmView.swift
//  The signature confirmation moment: every capture flow converges here, and the
//  parsed food reveals into the hero MealCard — honest about its provenance
//  (Measured / Estimated / Adjusted), framing estimates as "about N". One-tap
//  correction chips (½ · 2× · Less · More · Swap unit) adjust it; Save persists via
//  FoodConfirmModel → store.add and hands the saved entry back so Today can offer
//  an undo. Replaces FoodConfirmDialog.tsx.
//

import SwiftUI
import AppCore
import NutritionCore

struct FoodConfirmView: View {
    @Environment(AppContainer.self) private var container
    @Environment(\.dismiss) private var dismiss
    let parsed: ParsedFood
    let method: InputMethod
    /// Hands the saved entry back so the host (Today) can offer a one-tap undo.
    let onSaved: (Entry) -> Void

    @State private var model: FoodConfirmModel?

    /// Typed/spoken entries show a "change your search" shortcut that goes BACK to the
    /// search form (with its live suggestions, recent foods, and Analyze). A scan has
    /// no search form to return to.
    private var canResearch: Bool { method == .text || method == .voice }

    var body: some View {
        Group {
            if let model {
                ConfirmForm(model: model, notes: parsed.notes, onSaved: onSaved,
                            searchTerm: canResearch ? parsed.food : nil,
                            onEditSearch: { dismiss() })   // pop back to the search form
            } else {
                ProgressView()
            }
        }
        .task {
            if model == nil {
                let m = FoodConfirmModel(parsed: parsed, method: method,
                                         store: container.store, corrections: container.corrections)
                await m.loadRememberedCorrection()   // pre-apply your last edit for this food
                model = m
            }
        }
    }
}

private struct ConfirmForm: View {
    @Environment(AppContainer.self) private var container
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var typeSize
    @Bindable var model: FoodConfirmModel
    let notes: String?
    let onSaved: (Entry) -> Void
    /// The original search term; when non-nil, a tappable shortcut back to the search
    /// form is shown. `onEditSearch` performs the navigation.
    var searchTerm: String? = nil
    var onEditSearch: () -> Void = {}

    @State private var saving = false
    @State private var revealed = false

    /// The capture-method phrasing for the badge's source row.
    private var sourceLabel: String {
        switch model.method {
        case .barcode: return "Barcode"
        case .label:   return "Label"
        case .photo:   return "Photo estimate"
        case .voice:   return "Spoken estimate"
        case .text:    return "Typed estimate"
        }
    }

    private var detailText: String {
        let q = model.quantity
        let amount = q == q.rounded() ? String(Int(q)) : String(format: "%.1f", q)
        return "\(amount) \(model.unit)"
    }

    var body: some View {
        Form {
            if let searchTerm {
                Section {
                    Button(action: onEditSearch) {
                        HStack(spacing: 8) {
                            Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                            Text(searchTerm).foregroundStyle(.primary).lineLimit(1)
                            Spacer(minLength: 8)
                            Image(systemName: "chevron.right").font(.caption2).foregroundStyle(.tertiary)
                        }
                        .contentShape(.rect)
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("EditSearch")
                } footer: {
                    Text("Not what you meant? Tap to change your search.")
                }
            }

            // The hero: the parsed food revealed as a MealCard, honest about its
            // provenance and framing estimates as "about N".
            Section {
                Group {
                    if revealed {
                        MealCard(
                            foodName: model.food.isEmpty ? parsedNamePlaceholder : model.food,
                            detail: detailText,
                            kcal: model.kcal, protein: model.protein, carbs: model.carbs, fat: model.fat,
                            confidence: model.nutritionConfidence, sourceLabel: sourceLabel
                        ) {
                            chipRow
                        }
                        .transition(Motion.reveal(reduceMotion: reduceMotion))
                    }
                }
                .frame(maxWidth: .infinity)
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 8, trailing: 0))
            } footer: {
                if model.appliedRememberedCorrection {
                    Label("We remembered your last edit for this food.", systemImage: "checkmark.circle")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
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

            if model.hasBreakdown {
                breakdownSection
            }
            // Show fiber/sodium/sugar whenever we have them — the MealCard covers the
            // headline macros, this is the extra detail.
            if model.fiber != nil || model.sodium != nil || model.sugar != nil {
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
        .onAppear {
            guard !revealed else { return }
            withAnimation(Motion.spring(reduceMotion: reduceMotion)) { revealed = true }
            model.isLowConfidenceEstimate ? Haptics.uncertain() : Haptics.parsed()
        }
        .keyboardDoneToolbar()
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button {
                    saving = true
                    Task {
                        let entry = await model.save()
                        await container.healthSyncFood(entry)   // no-op unless Health sync is on
                        Haptics.saved()
                        onSaved(entry)
                    }
                } label: {
                    if saving { ProgressView() } else { Text("Add") }
                }
                .disabled(model.food.trimmingCharacters(in: .whitespaces).isEmpty || model.quantity <= 0 || saving)
            }
        }
    }

    private var parsedNamePlaceholder: String { "This food" }

    /// One-tap honest corrections. Adjusting the portion never pretends to be more
    /// precise — it just rescales the estimate.
    @ViewBuilder
    private var chipRow: some View {
        // At standard sizes the chips share one equal-width row; at accessibility
        // sizes they stack full-width so the labels never crush and each stays an
        // easy tap target. (No horizontal scroller — it would swallow the sheet's
        // vertical scroll gesture.)
        if typeSize.isAccessibilitySize {
            VStack(spacing: 8) { chipButtons }
        } else {
            HStack(spacing: 8) { chipButtons }
        }
    }

    @ViewBuilder
    private var chipButtons: some View {
        chip("½", selected: model.isPortion(0.5)) { model.setPortion(0.5) }
        chip("2×", selected: model.isPortion(2)) { model.setPortion(2) }
        chip("Less") { model.nudge(0.85) }
        chip("More") { model.nudge(1.15) }
        if UnitConversion.compatibleUnits(with: model.unit).count > 1 {
            chip("Swap unit") { model.cycleUnit() }
        }
    }

    private func chip(_ label: String, selected: Bool = false, _ action: @escaping () -> Void) -> some View {
        Button {
            withAnimation(Motion.spring(reduceMotion: reduceMotion)) { action() }
            Haptics.adjusted()
        } label: {
            Text(label)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)
        .tint(selected ? DS.Macro.calories.tint : .secondary)
        .font(.subheadline.weight(.medium))
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
                Text("Use −/+ to halve or double an ingredient, tap the amount to set it exactly, or swipe to remove. The totals above update to match.")
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
        HStack(spacing: 8) {
            Text(component.name)
                .font(.subheadline)
                .lineLimit(1)
                .truncationMode(.tail)
            Spacer(minLength: 4)

            Button {
                onGramsChanged(max(1, (component.grams * 0.5).rounded()))
            } label: {
                Image(systemName: "minus.circle")
            }
            .buttonStyle(.borderless)
            .accessibilityLabel("Halve \(component.name)")

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

            Button {
                onGramsChanged((component.grams * 2).rounded())
            } label: {
                Image(systemName: "plus.circle")
            }
            .buttonStyle(.borderless)
            .accessibilityLabel("Double \(component.name)")

            Text("\(Int(component.kcal.rounded())) kcal")
                .font(.caption)
                .foregroundStyle(.secondary)
                .monospacedDigit()
                .frame(minWidth: 52, alignment: .trailing)
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
