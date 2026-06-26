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
    @State private var showWorkoutPrimer = false
    @State private var workoutPrimerContinued = false

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
                            guard on else { return }
                            Task {
                                // Prime only when iOS will actually show its sheet (first
                                // time). Otherwise just (re)start observing — it can't ask
                                // again, and the primer with no system sheet would confuse.
                                if await container.workoutAccessNeedsPrompt() {
                                    workoutPrimerContinued = false
                                    showWorkoutPrimer = true
                                } else {
                                    await container.requestWorkoutAccess()
                                    await container.startWorkoutObservation()
                                }
                            }
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
        .sheet(isPresented: $showWorkoutPrimer, onDismiss: {
            // Backed out without continuing → don't leave the switch on without access.
            if !workoutPrimerContinued {
                container.settings.healthWorkoutOffsetEnabled = false
            }
        }) {
            WorkoutAccessPrimer(
                onContinue: {
                    workoutPrimerContinued = true
                    showWorkoutPrimer = false
                    Task {
                        await container.requestWorkoutAccess()
                        await container.startWorkoutObservation()
                    }
                },
                onCancel: { showWorkoutPrimer = false }   // onDismiss flips the switch back
            )
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

/// Pre-permission explainer shown right before the system HealthKit sheet when the
/// user enables workout offsets. Apple's sheet defaults its read toggles to OFF, so
/// this tells the user to tap "Turn On All" — without it, most people grant nothing
/// and the feature silently does nothing. This is a plain explainer, never a replica
/// of the system sheet (which Apple's guidelines require and recommend).
private struct WorkoutAccessPrimer: View {
    let onContinue: () -> Void
    let onCancel: () -> Void
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 18) {
                    ZStack {
                        Circle()
                            .fill(DS.Macro.calories.linearGradient)
                            .frame(width: 66, height: 66)
                            .shadow(color: DS.Macro.calories.tint.opacity(0.4), radius: 10, y: 4)
                        Image(systemName: "figure.run")
                            .font(.system(size: 30, weight: .bold))
                            .foregroundStyle(.white)
                    }
                    .padding(.top, 4)

                    VStack(spacing: 8) {
                        Text("Offset workouts automatically")
                            .font(.title2.weight(.bold))
                            .multilineTextAlignment(.center)
                        Text("After a workout, we’ll offer to add the calories you burned to that day — so your targets reflect your activity.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        primerRow("checkmark.circle.fill",
                                  "On the next screen, tap **Turn On All**.")
                        primerRow("heart.text.square.fill",
                                  "It needs both **Workouts** and **Active Energy** — Apple leaves these off by default.")
                        primerRow("lock.fill",
                                  "Read-only. We never write workouts back to Health.")
                    }
                    .padding(18)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: DS.cardRadius, style: .continuous)
                            .fill(DS.contentFill(scheme))
                    )
                }
                .padding(24)
            }

            VStack(spacing: 12) {
                Button(action: onContinue) {
                    Text("Continue")
                        .font(.headline)
                        .frame(maxWidth: .infinity).frame(height: 52)
                        .background(Capsule().fill(DS.Macro.calories.linearGradient))
                        .foregroundStyle(.white)
                }
                .buttonStyle(.plain)
                Button("Not now", action: onCancel)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 24)
            .padding(.top, 8)
            .padding(.bottom, 20)
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    private func primerRow(_ icon: String, _ markdown: LocalizedStringKey) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(DS.Macro.calories.tint)
                .frame(width: 24)
            Text(markdown)
                .font(.subheadline)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
    }
}
