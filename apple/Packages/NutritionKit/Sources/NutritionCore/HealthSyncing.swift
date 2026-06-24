// Apple Health integration seam. HealthKit itself is confined to the
// `NutritionHealth` module (the only place that imports HealthKit); everything
// else depends on this pure-Core protocol, so view models and tests use a mock.
//
// The app is fully usable when Health is unavailable or permission is denied —
// every method is best-effort and callers treat failures as non-fatal.

import Foundation

/// A snapshot of what the app is currently allowed to do with Apple Health.
public struct HealthAuthorizationSummary: Sendable, Equatable {
    /// Whether HealthKit exists on this device at all (`false` on Mac/unsupported).
    public var isAvailable: Bool
    /// Whether the app may write nutrition samples.
    public var nutritionWriteAuthorized: Bool
    /// Whether the app may read/write body-mass samples.
    public var weightAuthorized: Bool

    public init(isAvailable: Bool, nutritionWriteAuthorized: Bool, weightAuthorized: Bool) {
        self.isAvailable = isAvailable
        self.nutritionWriteAuthorized = nutritionWriteAuthorized
        self.weightAuthorized = weightAuthorized
    }

    public static let unavailable = HealthAuthorizationSummary(
        isAvailable: false, nutritionWriteAuthorized: false, weightAuthorized: false)
}

/// A same-day disagreement between a locally logged weight and an Apple Health
/// sample, surfaced to the user to resolve (Use Apple Health / Keep current).
public struct WeightConflict: Sendable, Equatable, Identifiable {
    public let date: String          // YYYY-MM-DD
    public let localKg: Double
    public let healthKg: Double
    public var id: String { date }

    public init(date: String, localKg: Double, healthKg: Double) {
        self.date = date
        self.localKg = localKg
        self.healthKg = healthKg
    }
}

/// Writing this app's nutrition/weight to Apple Health, importing weight back,
/// and removing this app's previously written Health data. HealthKit samples are
/// immutable, so edits delete-and-recreate this app's data (matched by metadata).
public protocol HealthSyncing: Sendable {
    /// Whether HealthKit is present on this device (cheap, synchronous).
    func isAvailable() -> Bool

    /// Request write access for nutrition types (energy + macros, and fiber/sodium
    /// once those exist on the entry).
    func requestNutritionWriteAccess() async throws
    /// Request read/write access for body mass.
    func requestWeightAccess() async throws
    /// Request READ access for workouts + active energy (the app never writes these;
    /// it only reads completed workouts to suggest a calorie offset).
    func requestWorkoutAccess() async throws

    /// Write (or rewrite) a food entry as a `.food` correlation tagged with the
    /// entry id. Safe to call repeatedly — it replaces this app's prior data for
    /// that id, so edits never duplicate.
    func syncFoodEntry(_ entry: Entry) async throws
    /// Delete this app's Health data for a food entry id.
    func deleteSyncedFoodEntry(id: String) async throws

    /// Write (or rewrite) a body-mass sample for a weigh-in (one per day).
    func syncWeightEntry(_ entry: WeightEntry) async throws
    /// Body-mass samples from the last `daysBack` days, reduced to one per local
    /// day (newest), oldest-first.
    func importWeights(daysBack: Int) async throws -> [WeightEntry]

    /// Completed workouts since `start`, filtered to "real" ones (duration + energy
    /// floor) and sorted newest-first. Read-only; returns `[]` when unavailable or
    /// unauthorized. Each carries its active-energy burn for offsetting.
    func recentWorkouts(since start: Date) async throws -> [WorkoutSample]

    /// Enable HealthKit background delivery for workouts and observe new ones,
    /// invoking `onUpdate` when the system wakes the app for a new workout (so a
    /// notification can be posted even while the app is closed). Best-effort; a no-op
    /// when unavailable. Registers at most once per process.
    func startWorkoutBackgroundDelivery(onUpdate: @escaping @Sendable () async -> Void) async

    /// Delete everything this app has ever written to Apple Health (matched by the
    /// app's source metadata). Does not touch other apps' data.
    func removeAllAppData() async throws

    /// Current availability + authorization snapshot.
    func authorizationSummary() async -> HealthAuthorizationSummary
}
