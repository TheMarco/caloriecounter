//
//  WeightConflictSheet.swift
//  When imported Apple Health weights disagree with locally logged weights for
//  the same day, the user resolves each one (Use Apple Health / Keep current).
//

import SwiftUI
import AppCore
import NutritionCore

struct WeightConflictSheet: View {
    @Environment(AppContainer.self) private var container
    @Environment(\.dismiss) private var dismiss

    @State private var conflicts: [WeightConflict]
    private let units: UnitSystem

    init(conflicts: [WeightConflict], units: UnitSystem) {
        _conflicts = State(initialValue: conflicts)
        self.units = units
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()
                List {
                    Section {
                        ForEach(conflicts) { c in
                            VStack(alignment: .leading, spacing: 10) {
                                Text(prettyDate(c.date)).font(.headline)
                                HStack {
                                    column("This app", c.localKg)
                                    Spacer()
                                    column("Apple Health", c.healthKg)
                                }
                                HStack(spacing: 10) {
                                    Button("Use Apple Health") { resolve(c, useHealth: true) }
                                        .buttonStyle(.glass).frame(maxWidth: .infinity)
                                    Button("Keep current") { resolve(c, useHealth: false) }
                                        .buttonStyle(.glass).frame(maxWidth: .infinity)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    } footer: {
                        Text("These days have a different weight in Apple Health than in the app. Pick which to keep.")
                    }
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("Weight Conflicts")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }
    }

    private func column(_ label: String, _ kg: Double) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label).font(.caption).foregroundStyle(.secondary)
            Text(String(format: "%.1f %@", units.weightForDisplay(kg: kg), units.weightUnit))
                .font(.body.weight(.semibold)).monospacedDigit()
        }
    }

    private func resolve(_ c: WeightConflict, useHealth: Bool) {
        Task {
            await container.resolveWeightConflict(c, useHealth: useHealth)
            conflicts.removeAll { $0.id == c.id }
            if conflicts.isEmpty { dismiss() }
        }
    }

    private func prettyDate(_ key: String) -> String {
        guard let date = LocalDate.date(from: key) else { return key }
        return date.formatted(.dateTime.month(.abbreviated).day().year())
    }
}
