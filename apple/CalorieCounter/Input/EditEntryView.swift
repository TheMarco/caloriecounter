//
//  EditEntryView.swift
//  Edit an existing entry — name, quantity, unit — with calories+macros
//  recalculated proportionally (Core MacroMath, ported from EditEntryDialog.tsx).
//  Saves in place via store.update.
//

import SwiftUI
import AppCore
import NutritionCore

struct EditEntryView: View {
    @Environment(AppContainer.self) private var container
    @Environment(\.dismiss) private var dismiss

    private let original: Entry
    let onSaved: () -> Void

    @State private var food: String
    @State private var quantityText: String
    @State private var unit: String
    @State private var saving = false

    init(entry: Entry, onSaved: @escaping () -> Void) {
        self.original = entry
        self.onSaved = onSaved
        _food = State(initialValue: entry.food)
        _quantityText = State(initialValue: entry.quantity == entry.quantity.rounded()
                              ? String(Int(entry.quantity)) : String(entry.quantity))
        _unit = State(initialValue: entry.unit)
    }

    /// One-decimal gram display, matching the macro rows.
    private func grams(_ v: Double) -> String {
        v.formatted(.number.precision(.fractionLength(0...1)))
    }
    private func contextRow(_ label: String, _ value: String) -> some View {
        LabeledContent {
            Text(value).foregroundStyle(.secondary)
        } label: {
            Text(label).foregroundStyle(.secondary)
        }
        .font(.subheadline)
    }

    private var quantity: Double { Double(quantityText) ?? 0 }
    /// Current amount expressed in the entry's original unit (preserves nutrition
    /// across compatible unit swaps; a relabel otherwise).
    private var amountInOriginalUnit: Double {
        UnitConversion.convert(quantity, from: unit, to: original.unit) ?? quantity
    }
    private var scaled: Entry { MacroMath.scaled(original, toQuantity: amountInOriginalUnit) }

    var body: some View {
        NavigationStack {
            Form {
                Section("Food") {
                    TextField("Name", text: $food).textInputAutocapitalization(.words)
                }
                Section("Amount") {
                    HStack {
                        Text("Quantity")
                        Spacer(minLength: 8)
                        PillTextField(text: $quantityText, accessibilityLabel: "Quantity")
                        let units = UnitConversion.compatibleUnits(with: unit)
                        if units.count > 1 {
                            Picker("Unit", selection: $unit) {
                                ForEach(units, id: \.self) { Text($0).tag($0) }
                            }
                            .labelsHidden()
                        } else {
                            Text(unit).foregroundStyle(.secondary)
                        }
                    }
                }
                Section("Nutrition (recalculated)") {
                    LabeledContent("Calories", value: "\(Int(scaled.kcal)) kcal")
                    LabeledContent("Fat", value: "\(grams(scaled.fat)) g")
                    LabeledContent("Carbs", value: "\(grams(scaled.carbs)) g")
                    LabeledContent("Protein", value: "\(grams(scaled.protein)) g")
                }
                if scaled.fiber != nil || scaled.sodium != nil || scaled.sugar != nil {
                    Section {
                        if let f = scaled.fiber { contextRow("Fiber", "\(grams(f)) g") }
                        if let s = scaled.sodium { contextRow("Sodium", "\(Int(s.rounded())) mg") }
                        if let su = scaled.sugar { contextRow("Sugar", "\(grams(su)) g") }
                    } header: {
                        Text("Advanced Nutrition").font(.footnote)
                    }
                }
            }
            .navigationTitle("Edit Food")
            .navigationBarTitleDisplayMode(.inline)
            .keyboardDoneToolbar()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        saving = true
                        var updated = scaled        // kcal/macros/fiber/sodium/sugar already scaled
                        updated.food = food.trimmingCharacters(in: .whitespacesAndNewlines)
                        updated.quantity = quantity // store the amount + unit the user sees
                        updated.unit = unit
                        // Nutrition source is unchanged (only rescaled), so keep its confidence.
                        Task {
                            try? await container.store.update(updated)
                            await container.healthSyncFood(updated)   // rewrites Health data for this id
                            onSaved()
                            dismiss()
                        }
                    } label: {
                        if saving { ProgressView() } else { Text("Save") }
                    }
                    .disabled(food.trimmingCharacters(in: .whitespaces).isEmpty || quantity <= 0 || saving)
                }
            }
        }
    }
}
