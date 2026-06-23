//
//  AppleHealthSettings.swift
//  The opt-in Apple Health section. Every sync is off by default; flipping a
//  toggle on triggers the system permission prompt. Disconnect stops syncing but
//  keeps already-written Health data; "Remove this app's data" deletes it.
//

import SwiftUI
import AppCore
import NutritionCore

struct AppleHealthSettings: View {
    @Environment(AppContainer.self) private var container

    @State private var conflicts: [WeightConflict] = []
    @State private var showConflicts = false
    @State private var showRemoveConfirm = false
    @State private var working = false
    @State private var statusMessage: String?

    var body: some View {
        @Bindable var settings = container.settings
        // HealthKit isn't available on every device — hide the whole section then.
        if container.healthSync.isAvailable() {
            Section {
                Toggle("Sync nutrition to Apple Health", isOn: $settings.healthNutritionSyncEnabled)
                    .onChange(of: settings.healthNutritionSyncEnabled) { _, on in
                        if on { Task { try? await container.healthSync.requestNutritionWriteAccess() } }
                    }
                Toggle("Sync weight to Apple Health", isOn: $settings.healthWeightSyncEnabled)
                    .onChange(of: settings.healthWeightSyncEnabled) { _, on in
                        if on { Task { try? await container.healthSync.requestWeightAccess() } }
                    }
                Toggle("Import weight from Apple Health", isOn: $settings.healthWeightImportEnabled)
                    .onChange(of: settings.healthWeightImportEnabled) { _, on in
                        if on { Task { try? await container.healthSync.requestWeightAccess(); await runImport() } }
                    }

                if settings.healthNutritionSyncEnabled || settings.healthWeightSyncEnabled {
                    LabeledContent("Synced fields", value: "Calories, protein, carbs, fat")
                }
                if let last = settings.healthLastSyncAt {
                    LabeledContent("Last sync", value: last.formatted(.relative(presentation: .named)))
                }

                if settings.healthWeightImportEnabled {
                    Button { Task { await runImport() } } label: {
                        Label(working ? "Importing…" : "Import from Apple Health now", systemImage: "arrow.down.circle")
                    }.disabled(working)
                }
                if settings.healthNutritionSyncEnabled {
                    Button { Task { working = true; await container.repairHealthSync(daysBack: 30); working = false; statusMessage = "Re-synced the last 30 days." } } label: {
                        Label("Repair sync", systemImage: "arrow.triangle.2.circlepath")
                    }.disabled(working)
                }
                if settings.healthNutritionSyncEnabled || settings.healthWeightSyncEnabled || settings.healthWeightImportEnabled {
                    Button("Disconnect Apple Health") { container.disconnectHealth() }
                }
                Button(role: .destructive) { showRemoveConfirm = true } label: {
                    Text("Remove this app’s data from Apple Health")
                }
            } header: {
                Text("Apple Health")
            } footer: {
                Text("Save meals, macros, and weigh-ins to Apple Health, and import weight you already have there. You choose what to share, and the app keeps working even if you skip this. Disconnect stops syncing but leaves data already in Health.")
            }
            .confirmationDialog("Remove all CalorieCounter data from Apple Health?",
                                isPresented: $showRemoveConfirm, titleVisibility: .visible) {
                Button("Remove", role: .destructive) {
                    Task { await container.removeAllHealthData(); statusMessage = "Removed this app’s data from Apple Health." }
                }
            } message: {
                Text("This deletes only the nutrition and weight samples this app wrote. Other apps’ Health data is untouched.")
            }
            .alert("Apple Health", isPresented: .constant(statusMessage != nil)) {
                Button("OK") { statusMessage = nil }
            } message: { Text(statusMessage ?? "") }
            .sheet(isPresented: $showConflicts) {
                WeightConflictSheet(conflicts: conflicts, units: container.settings.units)
            }
        }
    }

    private func runImport() async {
        working = true
        let found = await container.importHealthWeights()
        working = false
        if found.isEmpty {
            statusMessage = "Weight is up to date with Apple Health."
        } else {
            conflicts = found
            showConflicts = true
        }
    }
}
