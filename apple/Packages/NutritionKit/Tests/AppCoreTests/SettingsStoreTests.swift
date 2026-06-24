// SettingsStore persists macro targets, unit system, and the biometric-lock
// toggle in UserDefaults. Each test uses an isolated suite so it doesn't touch
// the real app defaults. Defaults mirror the web app (2000/65/250/100, metric).

import Testing
import Foundation
@testable import AppCore
import NutritionCore

@MainActor
@Suite("SettingsStore")
struct SettingsStoreTests {

    private func makeDefaults() -> UserDefaults {
        UserDefaults(suiteName: "test-settings-\(UUID().uuidString)")!
    }

    @Test("fresh defaults match the web app")
    func defaults() {
        let store = SettingsStore(defaults: makeDefaults())
        #expect(store.targets == MacroTargets(calories: 2000, fat: 65, carbs: 250, protein: 100))
        #expect(store.units == .metric)
        #expect(store.biometricLockEnabled == false)
        #expect(store.appearance == .system)
        #expect(store.appSettings == AppSettings(targets: store.targets, units: .metric))
    }

    @Test("values persist and reload across instances")
    func persistence() {
        let defaults = makeDefaults()
        let a = SettingsStore(defaults: defaults)
        a.units = .imperial
        a.targets = MacroTargets(calories: 2200, fat: 70, carbs: 200, protein: 120)
        a.biometricLockEnabled = true
        a.appearance = .dark

        let b = SettingsStore(defaults: defaults)
        #expect(b.units == .imperial)
        #expect(b.targets == MacroTargets(calories: 2200, fat: 70, carbs: 200, protein: 120))
        #expect(b.biometricLockEnabled == true)
        #expect(b.appearance == .dark)
    }

    @Test("Apple Health sync toggles default off and persist")
    func healthFlags() {
        let defaults = makeDefaults()
        let a = SettingsStore(defaults: defaults)
        #expect(a.healthNutritionSyncEnabled == false)   // opt-in
        #expect(a.healthWeightSyncEnabled == false)
        #expect(a.healthWeightImportEnabled == false)
        #expect(a.healthLastSyncAt == nil)

        a.healthNutritionSyncEnabled = true
        a.healthWeightImportEnabled = true
        a.healthLastSyncAt = Date(timeIntervalSince1970: 1_750_000_000)

        let b = SettingsStore(defaults: defaults)
        #expect(b.healthNutritionSyncEnabled == true)
        #expect(b.healthWeightSyncEnabled == false)
        #expect(b.healthWeightImportEnabled == true)
        #expect(b.healthLastSyncAt == Date(timeIntervalSince1970: 1_750_000_000))
    }

    @Test("the saved body profile persists and reloads")
    func profilePersistence() {
        let defaults = makeDefaults()
        let a = SettingsStore(defaults: defaults)
        #expect(a.savedProfile == nil)
        let p = UserProfile(sex: .female, age: 41, weightKg: 68, heightCm: 165,
                            activity: .light, goal: .steadyLoss, dietStyle: .lowCarb)
        a.savedProfile = p
        #expect(SettingsStore(defaults: defaults).savedProfile == p)
    }

    @Test("out-of-range targets are clamped when persisted")
    func clamping() {
        let defaults = makeDefaults()
        let a = SettingsStore(defaults: defaults)
        a.targets = MacroTargets(calories: 100, fat: 999, carbs: 1, protein: 999)

        let b = SettingsStore(defaults: defaults)
        // Ranges widened for keto/low-carb: fat ≤ 300, carbs ≥ 20.
        #expect(b.targets == MacroTargets(calories: 1000, fat: 300, carbs: 20, protein: 300))
    }
}
