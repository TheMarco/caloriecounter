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
    @Environment(\.dismiss) private var dismiss
    /// When presented as a sheet (from the gear), show a Done button to dismiss.
    var showsDoneButton: Bool = false

    @State private var exportURL: URL?
    @State private var showResetConfirm = false
    @State private var showEraseConfirm = false
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
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    if showsDoneButton {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Done") { dismiss() }
                        }
                    }
                }
                .keyboardDoneToolbar()
                .task { await prepareExport() }
                .confirmationDialog("Reset all targets to the defaults?", isPresented: $showResetConfirm, titleVisibility: .visible) {
                    Button("Reset", role: .destructive) {
                        container.settings.targets = .default
                        container.settings.units = .metric
                    }
                }
                .confirmationDialog("Erase all data and start over?",
                                    isPresented: $showEraseConfirm, titleVisibility: .visible) {
                    Button("Erase Everything", role: .destructive) {
                        Task { await performFullReset() }
                    }
                } message: {
                    Text("This permanently deletes every food entry and offset, resets your targets, and restarts setup. This can't be undone.")
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
                    SetupWizardView(allowsCancel: true) {}
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

            Section {
                targetField("Calories", value: $settings.targets.calories, unit: "kcal")
                targetField("Fat", value: $settings.targets.fat, unit: "g")
                targetField("Carbs", value: $settings.targets.carbs, unit: "g")
                targetField("Protein", value: $settings.targets.protein, unit: "g")
            } header: {
                Text("Daily Targets")
            } footer: {
                Text("Tap a value to edit it. Swipe down or tap Done to finish.")
            }

            Section("Units") {
                Picker("Measurement", selection: $settings.units) {
                    ForEach(UnitSystem.allCases, id: \.self) { Text($0.label).tag($0) }
                }
            }

            Section("Appearance") {
                Picker("Theme", selection: $settings.appearance) {
                    ForEach(AppearanceMode.allCases, id: \.self) { Text($0.label).tag($0) }
                }
                .pickerStyle(.segmented)
            }

            Section {
                Toggle("Haptics", isOn: $settings.hapticsEnabled)
                    .onChange(of: settings.hapticsEnabled) { _, on in Haptics.enabled = on }
            } footer: {
                Text("Subtle taps when a food is recognized, adjusted, saved, or undone.")
            }

            Section {
                Toggle("Require Face ID / Touch ID", isOn: $settings.biometricLockEnabled)
            } header: {
                Text("Security")
            } footer: {
                Text("Lock the app when it goes to the background. Your data stays on this device.")
            }

            AppleHealthLink()

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
                Button(role: .destructive) {
                    showEraseConfirm = true
                } label: {
                    Label("Erase All Data & Start Over", systemImage: "trash")
                }
            } header: {
                Text("Reset")
            } footer: {
                Text("Delete everything and return to the setup wizard. Export a backup first if you want to keep your history.")
            }

            Section {
                NavigationLink { AboutView() } label: { Label("About", systemImage: "info.circle") }
            }
        }
        .scrollDismissesKeyboard(.interactively)   // swipe down to dismiss the number pad
    }

    /// A tidy, tappable target row: label on the left, and the value + unit in a
    /// chip on the right that's clearly an input — faintly filled at rest and
    /// accent-highlighted while you're editing it, so it's obvious which field is
    /// active. Typed values snap into range when the keyboard closes (clampTargets).
    private func targetField(_ label: String, value: Binding<Double>, unit: String) -> some View {
        HStack {
            Text(label)
            Spacer(minLength: 8)
            PillNumberField(value: value, unit: unit, accessibilityLabel: label,
                            keyboard: .numberPad, onCommit: clampTargets)
        }
    }

    /// Snap every target into its valid range (called when the number pad closes).
    private func clampTargets() {
        container.settings.targets = container.settings.targets.clamped
    }

    private func prepareExport() async {
        // Full backup: every individual food + each day's offset.
        let entries = (try? await container.store.entries(from: "0000-01-01", to: "9999-12-31")) ?? []
        let dayRows = (try? await container.store.dailyTotals(lastDays: 730)) ?? []
        let weights = (try? await container.store.weights(from: "0000-01-01", to: "9999-12-31")) ?? []
        var offsets: [String: Double] = [:]
        for d in dayRows where d.offset > 0 { offsets[d.date] = d.offset }
        let csv = CSVExporter.entriesCSV(entries: entries, offsets: offsets, weights: weights)
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(CSVExporter.filename())
        try? csv.write(to: url, atomically: true, encoding: .utf8)
        exportURL = url
    }

    /// Full factory reset: wipe all entries/offsets, restore default settings, and
    /// relaunch the setup wizard (which re-sets targets and marks setup complete).
    private func performFullReset() async {
        try? await container.store.deleteAll()
        container.settings.targets = .default
        container.settings.units = .metric
        container.settings.biometricLockEnabled = false
        container.settings.hasCompletedSetup = false
        await prepareExport()       // export now reflects the empty store
        container.dataDidChange()   // Today/History reload to show the wipe
        showWizard = true
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
            let result = try CSVImporter.parse(text)
            let count = await CSVImporter.apply(result, to: container.store)
            await prepareExport()       // refresh the export to include imported data
            container.dataDidChange()   // Today and History reload automatically
            importMessage = "Imported \(count) day\(count == 1 ? "" : "s") of data."
        } catch CSVImporter.ImportError.unrecognizedFormat {
            importMessage = "That doesn't look like a CalorieCounter export CSV."
        } catch {
            importMessage = "No data rows found in that file."
        }
    }
}
