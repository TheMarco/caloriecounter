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

    @ObservationIgnored private let defaults: UserDefaults

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        // Initial assignments in init do NOT fire didSet, so nothing is persisted
        // until the user actually changes a value.
        self.targets = MacroTargets(
            calories: defaults.object(forKey: Keys.calorie) as? Double ?? Constants.defaultCalorieTarget,
            fat: defaults.object(forKey: Keys.fat) as? Double ?? Constants.defaultFatTarget,
            carbs: defaults.object(forKey: Keys.carbs) as? Double ?? Constants.defaultCarbsTarget,
            protein: defaults.object(forKey: Keys.protein) as? Double ?? Constants.defaultProteinTarget
        ).clamped
        self.units = defaults.string(forKey: Keys.units).flatMap(UnitSystem.init(rawValue:)) ?? .metric
        self.biometricLockEnabled = defaults.bool(forKey: Keys.biometricLock)
        self.hasCompletedSetup = defaults.bool(forKey: Keys.completedSetup)
    }

    /// The domain settings snapshot (targets + units); lock is an app concern.
    public var appSettings: AppSettings {
        AppSettings(targets: targets, units: units)
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
    }
}
