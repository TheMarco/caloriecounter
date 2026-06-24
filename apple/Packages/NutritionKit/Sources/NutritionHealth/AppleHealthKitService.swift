// The concrete HealthKit implementation of `HealthSyncing`. This is the ONLY
// file in the package that imports HealthKit — everything else depends on the
// pure `HealthSyncing` seam in NutritionCore.
//
// Design:
//  • Each food entry is one `HKCorrelation(.food)` grouping nutrient samples.
//  • Every sample AND the correlation carry `CalorieCounterFoodEntryID` + a source
//    marker in metadata, so edits/deletes find exactly this app's data via a
//    metadata predicate (HealthKit samples are immutable → delete-and-recreate).
//  • Body mass is one sample per day, tagged with the day key for de-dup.
//  • All work is guarded on `HKHealthStore.isHealthDataAvailable()`.

import Foundation
import HealthKit
import NutritionCore

public actor AppleHealthKitService: HealthSyncing {
    private let store = HKHealthStore()
    private let appVersion: String

    public init(appVersion: String? = nil) {
        self.appVersion = appVersion
            ?? (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String)
            ?? "1.0"
    }

    // MARK: - Metadata keys / markers

    private enum Meta {
        static let entryID = "CalorieCounterFoodEntryID"
        static let weightDate = "CalorieCounterWeightDate"
        static let source = "CalorieCounterSource"
        static let sourceValue = "CalorieCounter"
        static let appVersion = "CalorieCounterAppVersion"
    }

    // MARK: - Types we touch

    private var nutritionTypes: [HKQuantityType] {
        [HKQuantityType(.dietaryEnergyConsumed),
         HKQuantityType(.dietaryProtein),
         HKQuantityType(.dietaryCarbohydrates),
         HKQuantityType(.dietaryFatTotal)]
    }
    private var foodType: HKCorrelationType { HKCorrelationType(.food) }
    private var weightType: HKQuantityType { HKQuantityType(.bodyMass) }
    private var workoutType: HKWorkoutType { HKWorkoutType.workoutType() }
    private var activeEnergyType: HKQuantityType { HKQuantityType(.activeEnergyBurned) }

    // NB: authorization can only be requested for the individual quantity samples,
    // NOT for the `.food` correlation type (HealthKit rejects that with
    // "Authorization to share … is disallowed: HKCorrelationTypeIdentifierFood").
    // Writing the correlation still works because we hold access to its samples.
    private var nutritionShareTypes: Set<HKSampleType> {
        Set(nutritionTypes as [HKSampleType])
    }

    // MARK: - Availability / authorization

    nonisolated public func isAvailable() -> Bool { HKHealthStore.isHealthDataAvailable() }

    public func requestNutritionWriteAccess() async throws {
        guard isAvailable() else { return }
        try await store.requestAuthorization(toShare: nutritionShareTypes, read: [])
    }

    public func requestWeightAccess() async throws {
        guard isAvailable() else { return }
        try await store.requestAuthorization(toShare: [weightType], read: [weightType])
    }

    public func requestWorkoutAccess() async throws {
        guard isAvailable() else { return }
        // Read-only: workouts + their active energy. The app never writes either.
        try await store.requestAuthorization(toShare: [], read: [workoutType, activeEnergyType])
    }

    public func authorizationSummary() async -> HealthAuthorizationSummary {
        guard isAvailable() else { return .unavailable }
        let nutrition = store.authorizationStatus(for: HKQuantityType(.dietaryEnergyConsumed)) == .sharingAuthorized
        let weight = store.authorizationStatus(for: weightType) == .sharingAuthorized
        return HealthAuthorizationSummary(isAvailable: true,
                                          nutritionWriteAuthorized: nutrition,
                                          weightAuthorized: weight)
    }

    // MARK: - Nutrition write

    public func syncFoodEntry(_ entry: Entry) async throws {
        guard isAvailable() else { return }
        // Replace any prior data for this id first, so an edit can never duplicate.
        try await deleteSyncedFoodEntry(id: entry.id)

        let meta: [String: Any] = [
            Meta.entryID: entry.id,
            Meta.source: Meta.sourceValue,
            Meta.appVersion: appVersion,
            HKMetadataKeyFoodType: entry.food,
        ]
        let ts = entry.timestamp
        var samples: [HKQuantitySample] = []
        func add(_ type: HKQuantityType, _ unit: HKUnit, _ value: Double) {
            guard value > 0 else { return }
            samples.append(HKQuantitySample(
                type: type,
                quantity: HKQuantity(unit: unit, doubleValue: value),
                start: ts, end: ts, metadata: meta))
        }
        add(HKQuantityType(.dietaryEnergyConsumed), .kilocalorie(), entry.kcal)
        add(HKQuantityType(.dietaryProtein), .gram(), entry.protein)
        add(HKQuantityType(.dietaryCarbohydrates), .gram(), entry.carbs)
        add(HKQuantityType(.dietaryFatTotal), .gram(), entry.fat)
        // (Fiber/sodium/sugar samples are added once those fields exist on Entry.)

        guard !samples.isEmpty else { return }
        let correlation = HKCorrelation(type: foodType, start: ts, end: ts,
                                        objects: Set(samples), metadata: meta)
        try await store.save(correlation)
    }

    public func deleteSyncedFoodEntry(id: String) async throws {
        guard isAvailable() else { return }
        let predicate = HKQuery.predicateForObjects(
            withMetadataKey: Meta.entryID, operatorType: .equalTo, value: id)
        for type in nutritionTypes {
            _ = try? await store.deleteObjects(of: type, predicate: predicate)
        }
        _ = try? await store.deleteObjects(of: foodType, predicate: predicate)
    }

    // MARK: - Weight write / read

    public func syncWeightEntry(_ entry: WeightEntry) async throws {
        guard isAvailable() else { return }
        // One sample per day → replace the day's prior sample.
        let dayPredicate = HKQuery.predicateForObjects(
            withMetadataKey: Meta.weightDate, operatorType: .equalTo, value: entry.date)
        _ = try? await store.deleteObjects(of: weightType, predicate: dayPredicate)

        let sample = HKQuantitySample(
            type: weightType,
            quantity: HKQuantity(unit: .gramUnit(with: .kilo), doubleValue: entry.weightKg),
            start: entry.timestamp, end: entry.timestamp,
            metadata: [Meta.weightDate: entry.date, Meta.source: Meta.sourceValue, Meta.appVersion: appVersion])
        try await store.save(sample)
    }

    public func importWeights(daysBack: Int) async throws -> [WeightEntry] {
        guard isAvailable() else { return [] }
        let start = Calendar.current.date(byAdding: .day, value: -max(1, daysBack), to: Date())
        let datePredicate = HKQuery.predicateForSamples(withStart: start, end: nil)
        let descriptor = HKSampleQueryDescriptor(
            predicates: [.quantitySample(type: weightType, predicate: datePredicate)],
            sortDescriptors: [SortDescriptor(\.startDate, order: .reverse)])
        let samples = try await descriptor.result(for: store)

        // Newest sample per local day, oldest-first.
        var byDay: [String: WeightEntry] = [:]
        for s in samples {
            let day = LocalDate.key(for: s.startDate)
            guard byDay[day] == nil else { continue }   // sorted newest-first → first wins
            let kg = s.quantity.doubleValue(for: .gramUnit(with: .kilo))
            byDay[day] = WeightEntry(id: WeightEntry.id(for: day), date: day, timestamp: s.startDate, weightKg: kg)
        }
        return byDay.values.sorted { $0.date < $1.date }
    }

    // MARK: - Workouts (read-only, for calorie offsets)

    public func recentWorkouts(since start: Date) async throws -> [WorkoutSample] {
        guard isAvailable() else { return [] }
        let predicate = HKQuery.predicateForSamples(withStart: start, end: nil)
        let descriptor = HKSampleQueryDescriptor(
            predicates: [.workout(predicate)],
            sortDescriptors: [SortDescriptor(\.startDate, order: .reverse)])
        let workouts = try await descriptor.result(for: store)

        return workouts.compactMap { w -> WorkoutSample? in
            // Active energy burned. Without it we can't offset, so skip the workout.
            guard let kcal = w.statistics(for: activeEnergyType)?
                .sumQuantity()?.doubleValue(for: .kilocalorie()), kcal > 0 else { return nil }
            let minutes = Int((w.duration / 60).rounded())
            guard WorkoutSample.qualifiesAsRealWorkout(durationMinutes: minutes, kcal: kcal) else { return nil }
            return WorkoutSample(
                id: w.uuid.uuidString,
                date: LocalDate.key(for: w.endDate),
                activityName: Self.activityName(for: w.workoutActivityType),
                start: w.startDate, end: w.endDate,
                durationMinutes: minutes, kcal: kcal.rounded())
        }
    }

    private var workoutObserver: HKObserverQuery?

    public func startWorkoutBackgroundDelivery(onUpdate: @escaping @Sendable () async -> Void) async {
        guard isAvailable(), workoutObserver == nil else { return }   // register once per process
        // Ask iOS to wake us when a new workout is saved (best-effort; throttled).
        try? await store.enableBackgroundDelivery(for: workoutType, frequency: .immediate)
        let query = HKObserverQuery(sampleType: workoutType, predicate: nil) { _, completion, _ in
            // Kick off the app-level check, then acknowledge immediately. (The HK
            // completion handler isn't Sendable, so it can't be captured into the
            // Task — calling it synchronously here both satisfies that and keeps our
            // background budget intact; posting a local notification is quick.)
            Task { await onUpdate() }
            completion()
        }
        store.execute(query)
        workoutObserver = query
    }

    /// A short, friendly label for the prompt. Covers the common types; anything
    /// else falls back to a generic "Workout".
    static func activityName(for type: HKWorkoutActivityType) -> String {
        switch type {
        case .walking: return "Walk"
        case .running: return "Run"
        case .hiking: return "Hike"
        case .cycling: return "Ride"
        case .swimming: return "Swim"
        case .rowing: return "Row"
        case .elliptical: return "Elliptical"
        case .stairClimbing, .stairs: return "Stair Climb"
        case .traditionalStrengthTraining, .functionalStrengthTraining: return "Strength Training"
        case .highIntensityIntervalTraining: return "HIIT"
        case .yoga: return "Yoga"
        case .pilates: return "Pilates"
        case .coreTraining: return "Core Training"
        case .dance, .cardioDance: return "Dance"
        default: return "Workout"
        }
    }

    // MARK: - Bulk remove

    public func removeAllAppData() async throws {
        guard isAvailable() else { return }
        let mine = HKQuery.predicateForObjects(
            withMetadataKey: Meta.source, operatorType: .equalTo, value: Meta.sourceValue)
        for type in nutritionTypes {
            _ = try? await store.deleteObjects(of: type, predicate: mine)
        }
        _ = try? await store.deleteObjects(of: foodType, predicate: mine)
        _ = try? await store.deleteObjects(of: weightType, predicate: mine)
    }
}
