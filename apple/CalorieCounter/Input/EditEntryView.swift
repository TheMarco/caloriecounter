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
    @State private var fiberText: String
    @State private var sodiumText: String
    @State private var sugarText: String
    @State private var saving = false

    init(entry: Entry, onSaved: @escaping () -> Void) {
        self.original = entry
        self.onSaved = onSaved
        _food = State(initialValue: entry.food)
        _quantityText = State(initialValue: entry.quantity == entry.quantity.rounded()
                              ? String(Int(entry.quantity)) : String(entry.quantity))
        _unit = State(initialValue: entry.unit)
        _fiberText = State(initialValue: Self.fmt(entry.fiber))
        _sodiumText = State(initialValue: Self.fmt(entry.sodium))
        _sugarText = State(initialValue: Self.fmt(entry.sugar))
    }

    private static func fmt(_ v: Double?) -> String {
        guard let v else { return "" }
        return v == v.rounded() ? String(Int(v)) : String(v)
    }
    private func parse(_ text: String) -> Double? {
        let t = text.trimmingCharacters(in: .whitespaces)
        return t.isEmpty ? nil : Double(t)
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
                    LabeledContent("Fat", value: "\(scaled.fat.formatted(.number.precision(.fractionLength(0...1)))) g")
                    LabeledContent("Carbs", value: "\(scaled.carbs.formatted(.number.precision(.fractionLength(0...1)))) g")
                    LabeledContent("Protein", value: "\(scaled.protein.formatted(.number.precision(.fractionLength(0...1)))) g")
                }
                Section {
                    advancedRow("Fiber", $fiberText, "g")
                    advancedRow("Sodium", $sodiumText, "mg")
                    advancedRow("Sugar", $sugarText, "g")
                } header: {
                    Text("Advanced Nutrition").font(.footnote)
                } footer: {
                    Text("Optional — leave blank if unknown.").font(.caption2)
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
                        var updated = scaled        // correct kcal/macros for the amount
                        updated.food = food.trimmingCharacters(in: .whitespacesAndNewlines)
                        updated.quantity = quantity // store the amount + unit the user sees
                        updated.unit = unit
                        updated.fiber = parse(fiberText)
                        updated.sodium = parse(sodiumText)
                        updated.sugar = parse(sugarText)
                        updated.nutritionConfidence = .userEdited
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

    private func advancedRow(_ label: String, _ text: Binding<String>, _ unit: String) -> some View {
        HStack {
            Text(label).font(.subheadline).foregroundStyle(.secondary)
            Spacer(minLength: 8)
            PillTextField(text: text, unit: unit, placeholder: "—", accessibilityLabel: label)
        }
    }
}
