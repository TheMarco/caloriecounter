//
//  CalorieOffsetView.swift
//  Shows the day's exercise/adjustment offset and opens a sheet to edit it.
//  Persists via TodayModel.updateOffset → store.setOffset.
//

import SwiftUI

struct CalorieOffsetView: View {
    let offset: Double
    let onEdit: () -> Void

    var body: some View {
        Button(action: onEdit) {
            HStack(spacing: 12) {
                Image(systemName: "flame.fill")
                    .foregroundStyle(.orange)
                    .font(.title3)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Exercise / Adjustment").font(.subheadline.weight(.medium))
                    Text(offset > 0 ? "−\(Int(offset)) kcal today" : "Tap to log calories burned")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right").font(.caption).foregroundStyle(.tertiary)
            }
            .padding()
            .frame(maxWidth: .infinity)
            .background(.background.secondary, in: .rect(cornerRadius: 16))
        }
        .buttonStyle(.plain)
    }
}

struct CalorieOffsetSheet: View {
    @State private var value: Double
    let onSave: (Double) -> Void
    @Environment(\.dismiss) private var dismiss

    init(value: Double, onSave: @escaping (Double) -> Void) {
        _value = State(initialValue: value)
        self.onSave = onSave
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Calories burned / adjustment") {
                    Stepper(value: $value, in: 0...5000, step: 25) {
                        Text("\(Int(value)) kcal")
                            .font(.title3.weight(.semibold))
                            .contentTransition(.numericText())
                    }
                    HStack {
                        Text("Exact value")
                        Spacer(minLength: 8)
                        PillNumberField(value: $value, unit: "kcal", accessibilityLabel: "Exact value",
                                        keyboard: .numberPad, onCommit: { value = min(max(value, 0), 5000) })
                    }
                }
            }
            .navigationTitle("Adjustment")
            .navigationBarTitleDisplayMode(.inline)
            .keyboardDoneToolbar()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { onSave(max(0, value)); dismiss() }
                }
            }
        }
        .presentationDetents([.medium])
    }
}
