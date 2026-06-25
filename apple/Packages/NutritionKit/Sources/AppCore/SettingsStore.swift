// Observable settings backed by UserDefaults: macro targets, unit system, and the
// biometric-lock toggle. Defaults mirror the web app (`src/lib/constants.ts`:
// 2000/65/250/100, metric). Targets are clamped to the valid ranges on persist,
// so a reload always yields sane values.

import Foundation
import Observation
import NutritionCore

@Observable
@MainActor
public final class SettingsStore {
    public var targets: MacroTargets { didSet { persistTargets() } }
    public var units: UnitSystem { didSet { defaults.set(units.rawValue, forKey: Keys.units) } }
    public var biometricLockEnabled: Bool { didSet { defaults.set(biometricLockEnabled, forKey: Keys.biometricLock) } }
    /// Whether the goal setup wizard has been completed (drives first-launch onboarding).
    public var hasCompletedSetup: Bool { didSet { defaults.set(hasCompletedSetup, forKey: Keys.completedSetup) } }
    /// Color-scheme preference (auto/light/dark); the app maps it to a SwiftUI `ColorScheme?`.
    public var appearance: AppearanceMode { didSet { defaults.set(appearance.rawValue, forKey: Keys.appearance) } }
    /// Whether to play haptic feedback (default on). The app mirrors this to `Haptics.enabled`.
    public var hapticsEnabled: Bool { didSet { defaults.set(hapticsEnabled, forKey: Keys.haptics) } }

    // MARK: - Apple Health (all opt-in; default off)
    /// Write food entries (calories + macros) to Apple Health.
    public var healthNutritionSyncEnabled: Bool { didSet { defaults.set(healthNutritionSyncEnabled, forKey: Keys.healthNutrition) } }
    /// Write weigh-ins to Apple Health.
    public var healthWeightSyncEnabled: Bool { didSet { defaults.set(healthWeightSyncEnabled, forKey: Keys.healthWeight) } }
    /// Import body-mass samples from Apple Health into the app.
    public var healthWeightImportEnabled: Bool { didSet { defaults.set(healthWeightImportEnabled, forKey: Keys.healthWeightImport) } }
    /// Read completed workouts from Apple Health and offer to offset their calories.
    public var healthWorkoutOffsetEnabled: Bool { didSet { defaults.set(healthWorkoutOffsetEnabled, forKey: Keys.healthWorkoutOffset) } }
    /// Timestamp of the last successful sync, shown in Settings.
    public var healthLastSyncAt: Date? {
        didSet { defaults.set(healthLastSyncAt?.timeIntervalSince1970 ?? 0, forKey: Keys.healthLastSync) }
    }

    /// The body profile the current targets were computed from (saved by the setup
    /// wizard). Lets the wizard pre-fill on re-run and drives the "weight changed —
    /// update targets?" nudge.
    public var savedProfile: UserProfile? {
        didSet {
            if let p = savedProfile, let data = try? JSONEncoder().encode(p) {
                defaults.set(data, forKey: Keys.profile)
            } else {
                defaults.removeObject(forKey: Keys.profile)
            }
        }
    }

    @ObservationIgnored private let defaults: UserDefaults

    /// `defaultUnits` is the fallback when the user has never chosen a unit system
    /// (the app passes a locale-aware default; tests default to `.metric`).
    public init(defaults: UserDefaults = .standard, defaultUnits: UnitSystem = .metric) {
        self.defaults = defaults
        // Initial assignments in init do NOT fire didSet, so nothing is persisted
        // until the user actually changes a value.
        self.targets = MacroTargets(
            calories: defaults.object(forKey: Keys.calorie) as? Double ?? Constants.defaultCalorieTarget,
            fat: defaults.object(forKey: Keys.fat) as? Double ?? Constants.defaultFatTarget,
            carbs: defaults.object(forKey: Keys.carbs) as? Double ?? Constants.defaultCarbsTarget,
            protein: defaults.object(forKey: Keys.protein) as? Double ?? Constants.defaultProteinTarget
        ).clamped
        self.units = defaults.string(forKey: Keys.units).flatMap(UnitSystem.init(rawValue:)) ?? defaultUnits
        self.biometricLockEnabled = defaults.bool(forKey: Keys.biometricLock)
        self.hasCompletedSetup = defaults.bool(forKey: Keys.completedSetup)
        self.appearance = defaults.string(forKey: Keys.appearance).flatMap(AppearanceMode.init(rawValue:)) ?? .system
        self.hapticsEnabled = defaults.object(forKey: Keys.haptics) as? Bool ?? true   // default on
        self.healthNutritionSyncEnabled = defaults.bool(forKey: Keys.healthNutrition)
        self.healthWeightSyncEnabled = defaults.bool(forKey: Keys.healthWeight)
        self.healthWeightImportEnabled = defaults.bool(forKey: Keys.healthWeightImport)
        self.healthWorkoutOffsetEnabled = defaults.bool(forKey: Keys.healthWorkoutOffset)
        let lastSync = defaults.double(forKey: Keys.healthLastSync)
        self.healthLastSyncAt = lastSync > 0 ? Date(timeIntervalSince1970: lastSync) : nil
        self.savedProfile = defaults.data(forKey: Keys.profile)
            .flatMap { try? JSONDecoder().decode(UserProfile.self, from: $0) }
    }

    /// The domain settings snapshot (targets + units); lock is an app concern.
    public var appSettings: AppSettings {
        AppSettings(targets: targets, units: units)
    }

    // MARK: - Workout ledgers
    // Per-workout state keyed by HKWorkout UUID, stored as [uuid: YYYY-MM-DD] and
    // pruned on write so they can't grow without bound. Kept off the @Observable
    // surface (not UI state) — read/written straight through UserDefaults.
    //  • "handled"  — offered-and-resolved (accepted or dismissed); never suggest again.
    //  • "notified" — a background notification was already posted; never re-notify.

    public func isWorkoutHandled(_ id: String) -> Bool { ledger(Keys.workoutHandledLedger)[id] != nil }
    public func markWorkoutHandled(id: String, date: String) { mark(id: id, date: date, key: Keys.workoutHandledLedger) }

    public func isWorkoutNotified(_ id: String) -> Bool { ledger(Keys.workoutNotifiedLedger)[id] != nil }
    public func markWorkoutNotified(id: String, date: String) { mark(id: id, date: date, key: Keys.workoutNotifiedLedger) }

    private func ledger(_ key: String) -> [String: String] {
        defaults.data(forKey: key)
            .flatMap { try? JSONDecoder().decode([String: String].self, from: $0) } ?? [:]
    }

    private func mark(id: String, date: String, key: String) {
        var entries = ledger(key)
        let cutoff = LocalDate.key(for: Date().addingTimeInterval(
            -Double(Constants.workoutLedgerRetentionDays) * 86_400))
        entries = entries.filter { $0.value >= cutoff }   // prune stale entries
        entries[id] = date
        if let data = try? JSONEncoder().encode(entries) {
            defaults.set(data, forKey: key)
        }
    }

    private func persistTargets() {
        let c = targets.clamped
        defaults.set(c.calories, forKey: Keys.calorie)
        defaults.set(c.fat, forKey: Keys.fat)
        defaults.set(c.carbs, forKey: Keys.carbs)
        defaults.set(c.protein, forKey: Keys.protein)
    }

    private enum Keys {
        static let calorie = "settings.calorieTarget"
        static let fat = "settings.fatTarget"
        static let carbs = "settings.carbsTarget"
        static let protein = "settings.proteinTarget"
        static let units = "settings.units"
        static let completedSetup = "settings.hasCompletedSetup"
        static let biometricLock = "settings.biometricLockEnabled"
        static let appearance = "settings.appearance"
        static let haptics = "settings.hapticsEnabled"
        static let healthNutrition = "settings.healthNutritionSync"
        static let healthWeight = "settings.healthWeightSync"
        static let healthWeightImport = "settings.healthWeightImport"
        static let healthWorkoutOffset = "settings.healthWorkoutOffset"
        static let healthLastSync = "settings.healthLastSyncAt"
        static let workoutHandledLedger = "settings.handledWorkoutLedger"
        static let workoutNotifiedLedger = "settings.notifiedWorkoutLedger"
        static let profile = "settings.savedProfile"
    }
}
