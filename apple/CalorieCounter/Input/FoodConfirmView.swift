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
    @Environment(AppContainer.self) private var container
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
            Section {
                advancedRow("Fiber", $model.fiberText, "g")
                advancedRow("Sodium", $model.sodiumText, "mg")
                advancedRow("Sugar", $model.sugarText, "g")
            } header: {
                Text("Advanced Nutrition").font(.footnote)
            } footer: {
                Text("Optional — leave blank if unknown.").font(.caption2)
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

    private func nutritionRow(_ label: String, _ value: Double, _ unit: String) -> some View {
        LabeledContent(label) {
            Text("\(value.formatted(.number.precision(.fractionLength(0...1)))) \(unit)")
                .contentTransition(.numericText())
                .monospacedDigit()
        }
    }

    /// A quiet, secondary row for optional fiber/sodium/sugar (visually subordinate
    /// to the macros above).
    private func advancedRow(_ label: String, _ text: Binding<String>, _ unit: String) -> some View {
        HStack {
            Text(label).font(.subheadline).foregroundStyle(.secondary)
            Spacer()
            TextField("—", text: text)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .font(.subheadline)
                .frame(maxWidth: 80)
            Text(unit).font(.subheadline).foregroundStyle(.secondary)
        }
    }
}
