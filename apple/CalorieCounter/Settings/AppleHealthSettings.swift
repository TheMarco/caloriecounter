//
//  AppleHealthSettings.swift
//  Apple Health is opt-in and off by default. To keep the main Settings screen
//  calm, the dense controls (four sync toggles, maintenance actions, and the
//  destructive "remove data") live on a pushed detail screen — the Settings list
//  shows just one "Apple Health · On/Off" row (AppleHealthLink).
//

import SwiftUI
import AppCore
import NutritionCore

/// The compact entry in the main Settings list: one row that pushes the full
/// controls. Hidden entirely on devices without HealthKit.
struct AppleHealthLink: View {
    @Environment(AppContainer.self) private var container

    var body: some View {
        if container.isHealthAvailable {
            let s = container.settings
            let anyOn = s.healthNutritionSyncEnabled || s.healthWeightSyncEnabled
                || s.healthWeightImportEnabled || s.healthWorkoutOffsetEnabled
            Section {
                NavigationLink {
                    AppleHealthDetailView()
                } label: {
                    LabeledContent {
                        Text(anyOn ? "On" : "Off").foregroundStyle(.secondary)
                    } label: {
                        Label("Apple Health", systemImage: "heart.text.square")
                    }
                }
            } footer: {
                Text("Optionally sync meals, macros, and weigh-ins, import weight, and offset workout calories. Off until you turn it on.")
            }
        }
    }
}

/// The full Apple Health controls, pushed from Settings. Flipping a toggle on
/// triggers the system permission prompt. Disconnect stops syncing but keeps
/// already-written Health data; "Remove this app's data" deletes it.
struct AppleHealthDetailView: View {
    @Environment(AppContainer.self) private var container

    @State private var conflicts: [WeightConflict] = []
    @State private var showConflicts = false
    @State private var showRemoveConfirm = false
    @State private var working = false
    @State private var statusMessage: String?

    var body: some View {
        @Bindable var settings = container.settings
        ZStack {
            AppBackground()
            Form {
                Section {
                    Toggle("Sync nutrition to Apple Health", isOn: $settings.healthNutritionSyncEnabled)
                        .onChange(of: settings.healthNutritionSyncEnabled) { _, on in
                            if on { requestAfterAnimation { try? await container.healthSync.requestNutritionWriteAccess() } }
                        }
                    Toggle("Sync weight to Apple Health", isOn: $settings.healthWeightSyncEnabled)
                        .onChange(of: settings.healthWeightSyncEnabled) { _, on in
                            if on { requestAfterAnimation { try? await container.healthSync.requestWeightAccess() } }
                        }
                    Toggle("Import weight from Apple Health", isOn: $settings.healthWeightImportEnabled)
                        .onChange(of: settings.healthWeightImportEnabled) { _, on in
                            if on { requestAfterAnimation { try? await container.healthSync.requestWeightAccess(); await runImport() } }
                        }
                    Toggle("Offset calories from workouts", isOn: $settings.healthWorkoutOffsetEnabled)
                        .onChange(of: settings.healthWorkoutOffsetEnabled) { _, on in
                            if on { requestAfterAnimation {
                                await container.requestWorkoutAccess()
                                await container.startWorkoutObservation()
                            } }
                        }
                    if settings.healthWorkoutOffsetEnabled {
                        Text("After a longer walk or workout, we’ll offer to add its calories to that day’s offset. Reads workouts only — never written back. If your goal already assumes an activity level, offsetting can double-count.")
                            .font(.caption).foregroundStyle(.secondary)
                        Button {
                            Task {
                                working = true
                                statusMessage = await container.workoutOffsetDiagnostics()
                                working = false
                            }
                        } label: {
                            Label(working ? "Checking…" : "Check recent workouts", systemImage: "stethoscope")
                        }
                        .disabled(working)
                    }
                } header: {
                    Text("Sync")
                } footer: {
                    Text("You choose what to share, and the app keeps working even if you skip this.")
                }

                if settings.healthNutritionSyncEnabled || settings.healthWeightSyncEnabled || settings.healthWeightImportEnabled {
                    Section {
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
                    } header: {
                        Text("Status")
                    }
                }

                if settings.healthNutritionSyncEnabled || settings.healthWeightSyncEnabled
                    || settings.healthWeightImportEnabled || settings.healthWorkoutOffsetEnabled {
                    Section {
                        Button("Disconnect Apple Health") { container.disconnectHealth() }
                    } footer: {
                        Text("Disconnect stops syncing but leaves data already written to Apple Health.")
                    }
                }

                Section {
                    Button(role: .destructive) { showRemoveConfirm = true } label: {
                        Text("Remove this app’s data from Apple Health")
                    }
                } footer: {
                    Text("Deletes only the nutrition and weight samples this app wrote. Other apps’ Health data is untouched.")
                }
            }
            .scrollContentBackground(.hidden)
            .tabBarBottomClearance()
        }
        .navigationTitle("Apple Health")
        .navigationBarTitleDisplayMode(.inline)
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

    /// Run a HealthKit permission request just after the toggle's animation has
    /// settled, so presenting the system sheet never interrupts it mid-slide.
    private func requestAfterAnimation(_ work: @escaping @Sendable () async -> Void) {
        Task {
            try? await Task.sleep(for: .milliseconds(400))
            await work()
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
