//
//  SettingsView.swift
//  Daily targets (clamped to Core ranges), units, the biometric-lock toggle, the
//  photo-proxy connection, CSV export (ShareLink), reset, and about.
//

import SwiftUI
import UniformTypeIdentifiers
import AppCore
import NutritionCore

struct SettingsView: View {
    @Environment(AppContainer.self) private var container

    @State private var exportURL: URL?
    @State private var showResetConfirm = false
    @State private var showImporter = false
    @State private var importMessage: String?
    @State private var showWizard = false

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()
                settingsForm(settings: container.settings)
                    .scrollContentBackground(.hidden)
            }
                .navigationTitle("Settings")
                .task { await prepareExport() }
                .confirmationDialog("Reset all targets to the defaults?", isPresented: $showResetConfirm, titleVisibility: .visible) {
                    Button("Reset", role: .destructive) {
                        container.settings.targets = .default
                        container.settings.units = .metric
                    }
                }
                .fileImporter(isPresented: $showImporter,
                              allowedContentTypes: [.commaSeparatedText, .plainText, .text]) { result in
                    Task { await handleImport(result) }
                }
                .alert("Import", isPresented: .constant(importMessage != nil)) {
                    Button("OK") { importMessage = nil }
                } message: {
                    Text(importMessage ?? "")
                }
                .fullScreenCover(isPresented: $showWizard) {
                    SetupWizardView {}
                }
        }
    }

    private func settingsForm(settings: SettingsStore) -> some View {
        @Bindable var settings = settings
        return Form {
            Section {
                Button {
                    showWizard = true
                } label: {
                    Label("Set targets from a goal", systemImage: "wand.and.stars")
                }
            } footer: {
                Text("Re-run the setup wizard to recalculate your calorie & macro targets.")
            }

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
                if let exportURL {
                    ShareLink(item: exportURL) {
                        Label("Export CSV", systemImage: "square.and.arrow.up")
                    }
                } else {
                    HStack { ProgressView(); Text("Preparing export…").foregroundStyle(.secondary) }
                }
                Button {
                    showImporter = true
                } label: {
                    Label("Import CSV", systemImage: "square.and.arrow.down")
                }
                Button("Reset targets to defaults") { showResetConfirm = true }
            } header: {
                Text("Your Data")
            } footer: {
                Text("Export a daily-totals CSV, or import one to restore your history on a new device.")
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

    private func handleImport(_ result: Result<URL, Error>) async {
        guard case let .success(url) = result else {
            importMessage = "Couldn't open that file."
            return
        }
        let accessed = url.startAccessingSecurityScopedResource()
        defer { if accessed { url.stopAccessingSecurityScopedResource() } }

        guard let data = try? Data(contentsOf: url),
              let text = String(data: data, encoding: .utf8) else {
            importMessage = "Couldn't read that file."
            return
        }
        do {
            let days = try CSVImporter.parse(text)
            let count = await CSVImporter.apply(days, to: container.store)
            await prepareExport()   // refresh the export to include imported data
            importMessage = "Imported \(count) day\(count == 1 ? "" : "s") of data. Pull to refresh Today and History."
        } catch CSVImporter.ImportError.missingHeader {
            importMessage = "That doesn't look like a CalorieCounter export CSV."
        } catch {
            importMessage = "No data rows found in that file."
        }
    }
}
