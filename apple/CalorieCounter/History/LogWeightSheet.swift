//
//  LogWeightSheet.swift
//  Enter the current body weight (in the user's unit system) and save it as
//  today's measurement. Re-logging the same day updates it; you don't have to
//  weigh in every day.
//

import SwiftUI
import AppCore
import NutritionCore

struct LogWeightSheet: View {
    @Environment(AppContainer.self) private var container
    @Environment(\.dismiss) private var dismiss

    private let units: UnitSystem
    @State private var value: Double
    @FocusState private var focused: Bool

    init(currentKg: Double?, units: UnitSystem) {
        self.units = units
        _value = State(initialValue: units.weightForDisplay(kg: currentKg ?? 75).rounded(toPlaces: 1))
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()
                Form {
                    Section {
                        HStack {
                            Text("Weight")
                            Spacer()
                            TextField("Weight", value: $value, format: .number.precision(.fractionLength(0...1)))
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                                .focused($focused)
                                .frame(maxWidth: 100)
                            Text(units.weightUnit).foregroundStyle(.secondary)
                        }
                    } footer: {
                        Text("Saved as today's weight. Update it whenever you like — you don't have to weigh in every day.")
                    }
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("Log Weight")
            .navigationBarTitleDisplayMode(.inline)
            .keyboardDoneToolbar()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Save") { save() } }
            }
            .onAppear { focused = true }
        }
        .presentationDetents([.height(220), .medium])
    }

    private func save() {
        let kg = units.kilograms(fromDisplay: value)
        guard kg > 0 else { dismiss(); return }
        let today = LocalDate.today()
        let entry = WeightEntry(id: WeightEntry.id(for: today), date: today, timestamp: Date(), weightKg: kg)
        Task {
            try? await container.store.addWeight(entry)
            await container.healthSyncWeight(entry)   // no-op unless weight sync is on
            container.dataDidChange()   // History reloads via .task(id:)
        }
        dismiss()
    }
}

private extension Double {
    func rounded(toPlaces places: Int) -> Double {
        let m = pow(10.0, Double(places))
        return (self * m).rounded() / m
    }
}
