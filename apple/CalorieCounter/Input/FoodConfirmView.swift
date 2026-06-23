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

    var body: some View {
        Group {
            if let model {
                ConfirmForm(model: model, notes: parsed.notes, onSaved: onSaved)
            } else {
                ProgressView()
            }
        }
        .task {
            if model == nil {
                model = FoodConfirmModel(parsed: parsed, method: method, store: container.store)
            }
        }
    }
}

private struct ConfirmForm: View {
    @Bindable var model: FoodConfirmModel
    let notes: String?
    let onSaved: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var saving = false

    var body: some View {
        Form {
            Section("Food") {
                TextField("Name", text: $model.food)
                    .textInputAutocapitalization(.words)
            }
            Section("Amount") {
                HStack {
                    TextField("Quantity", text: $model.quantityText)
                        .keyboardType(.decimalPad)
                    Divider()
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
            if let notes, !notes.isEmpty {
                Section("Notes") {
                    Text(notes).font(.footnote).foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle("Confirm Food")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button {
                    saving = true
                    Task { await model.save(); onSaved() }
                } label: {
                    if saving { ProgressView() } else { Text("Add") }
                }
                .disabled(model.food.trimmingCharacters(in: .whitespaces).isEmpty || model.quantity <= 0 || saving)
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
