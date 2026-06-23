//
//  SettingsView.swift
//  Daily targets (clamped to Core ranges), units, the biometric-lock toggle, the
//  photo-proxy connection, CSV export (ShareLink), reset, and about.
//

import SwiftUI
import AppCore
import NutritionCore

struct SettingsView: View {
    @Environment(AppContainer.self) private var container

    @State private var photoConnected = false
    @State private var showLogin = false
    @State private var exportURL: URL?
    @State private var showResetConfirm = false

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()
                settingsForm(settings: container.settings)
                    .scrollContentBackground(.hidden)
            }
                .navigationTitle("Settings")
                .task {
                    photoConnected = await container.isPhotoProxyAuthenticated()
                    await prepareExport()
                }
                .sheet(isPresented: $showLogin) {
                    PhotoProxyLoginSheet { Task { photoConnected = await container.isPhotoProxyAuthenticated() } }
                }
                .confirmationDialog("Reset all targets to the defaults?", isPresented: $showResetConfirm, titleVisibility: .visible) {
                    Button("Reset", role: .destructive) {
                        container.settings.targets = .default
                        container.settings.units = .metric
                    }
                }
        }
    }

    private func settingsForm(settings: SettingsStore) -> some View {
        @Bindable var settings = settings
        return Form {
            Section("Daily Targets") {
                targetStepper("Calories", value: $settings.targets.calories, range: 1000...5000, step: 50, unit: "kcal")
                targetStepper("Fat", value: $settings.targets.fat, range: 20...200, step: 5, unit: "g")
                targetStepper("Carbs", value: $settings.targets.carbs, range: 50...500, step: 5, unit: "g")
                targetStepper("Protein", value: $settings.targets.protein, range: 30...300, step: 5, unit: "g")
            }

            Section("Units") {
                Picker("Measurement", selection: $settings.units) {
                    ForEach(UnitSystem.allCases, id: \.self) { Text($0.label).tag($0) }
                }
            }

            Section {
                Toggle("Require Face ID / Touch ID", isOn: $settings.biometricLockEnabled)
            } header: {
                Text("Security")
            } footer: {
                Text("Lock the app when it goes to the background. Your data stays on this device.")
            }

            Section {
                if photoConnected {
                    LabeledContent("Photo parsing", value: "Connected")
                    Button("Disconnect", role: .destructive) {
                        Task { await container.signOutPhotoProxy(); photoConnected = false }
                    }
                } else {
                    Button("Connect photo parsing") { showLogin = true }
                }
            } header: {
                Text("Plate Photos")
            } footer: {
                Text("Plate-of-food photos use the secure cloud service. Barcodes, labels, text, and voice all stay on-device.")
            }

            Section("Your Data") {
                if let exportURL {
                    ShareLink(item: exportURL) {
                        Label("Export CSV", systemImage: "square.and.arrow.up")
                    }
                } else {
                    HStack { ProgressView(); Text("Preparing export…").foregroundStyle(.secondary) }
                }
                Button("Reset targets to defaults") { showResetConfirm = true }
            }

            Section {
                NavigationLink { AboutView() } label: { Label("About", systemImage: "info.circle") }
            }
        }
    }

    private func targetStepper(_ label: String, value: Binding<Double>, range: ClosedRange<Double>, step: Double, unit: String) -> some View {
        Stepper(value: value, in: range, step: step) {
            LabeledContent(label, value: "\(Int(value.wrappedValue)) \(unit)")
        }
    }

    private func prepareExport() async {
        let days = (try? await container.store.dailyTotals(lastDays: 365)) ?? []
        let csv = CSVExporter.csv(from: days)
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(CSVExporter.filename())
        try? csv.write(to: url, atomically: true, encoding: .utf8)
        exportURL = url
    }
}
