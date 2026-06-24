// Workout-offset engine: reading completed Apple Health workouts and folding their
// calories into the day's offset. Proven with an in-memory store + a mock Health
// seam seeded with workouts — no HealthKit. Covers the "real workout" floor, the
// opt-in gate, dedup (never offered/added twice), stacking, and dismiss.

import Testing
import Foundation
@testable import AppCore
import NutritionCore
import NutritionStore
import NutritionAPI

private struct StubFoodParser: FoodParsing {
    func parse(text: String, units: UnitSystem) async throws -> ParsedFood {
        ParsedFood(food: text, quantity: 1, unit: "g", kcal: 1)
    }
}
private struct StubPhotoParser: PhotoParsing {
    func parse(imageData: Data, units: UnitSystem, details: PhotoDetails) async throws -> ParsedFood {
        ParsedFood(food: "photo", quantity: 1, unit: "plate", kcal: 1)
    }
}
private struct StubBarcode: BarcodeResolving {
    func resolve(code: String, units: UnitSystem) async throws -> ParsedFood {
        ParsedFood(food: "barcode", quantity: 100, unit: "g", kcal: 1)
    }
}

@MainActor
@Suite("WorkoutOffsets")
struct WorkoutOffsetTests {

    private func makeContainer(
        workoutsEnabled: Bool,
        seededWorkouts: [WorkoutSample],
        healthAvailable: Bool = true
    ) throws -> (AppContainer, SettingsStore) {
        let keychain = KeychainStore(service: "com.test.cc.workouts.\(UUID().uuidString)")
        let store = try SwiftDataStore.make(inMemory: true)
        let settings = SettingsStore(defaults: UserDefaults(suiteName: "test-w-\(UUID().uuidString)")!)
        settings.healthWorkoutOffsetEnabled = workoutsEnabled
        let container = AppContainer(
            store: store, keychain: keychain, apiClient: APIClient(tokens: keychain),
            foodParser: StubFoodParser(), photoParser: StubPhotoParser(),
            barcodeResolver: StubBarcode(),
            foodSearch: StaticFoodSearch(),
            settings: settings, healthSync: MockHealthSyncService(
                available: healthAvailable, seededWorkouts: seededWorkouts))
        return (container, settings)
    }

    private func workout(id: String = UUID().uuidString, date: String, kcal: Double,
                         minutes: Int = 30, name: String = "Run") -> WorkoutSample {
        let end = Date()
        return WorkoutSample(id: id, date: date, activityName: name,
                             start: end.addingTimeInterval(-Double(minutes) * 60), end: end,
                             durationMinutes: minutes, kcal: kcal)
    }

    private var today: String { LocalDate.key(for: Date()) }

    // MARK: - The "real workout" floor (pure)

    @Test("a brief, low-energy burst is not a real workout; a longer session is")
    func realWorkoutFloor() {
        // The stairs case: short and small → excluded.
        #expect(!WorkoutSample.qualifiesAsRealWorkout(durationMinutes: 4, kcal: 50))
        // Long but trivial energy → excluded.
        #expect(!WorkoutSample.qualifiesAsRealWorkout(durationMinutes: 40, kcal: 30))
        // Short but intense → excluded (must clear BOTH floors).
        #expect(!WorkoutSample.qualifiesAsRealWorkout(durationMinutes: 6, kcal: 200))
        // A 25-minute walk that burned 120 kcal → a real workout.
        #expect(WorkoutSample.qualifiesAsRealWorkout(durationMinutes: 25, kcal: 120))
    }

    // MARK: - Opt-in gate

    @Test("no offers unless the toggle is on")
    func gatedOnToggle() async throws {
        let (off, _) = try makeContainer(workoutsEnabled: false,
                                         seededWorkouts: [workout(date: today, kcal: 300)])
        #expect(await off.pendingWorkoutOffers().isEmpty)

        let (on, _) = try makeContainer(workoutsEnabled: true,
                                        seededWorkouts: [workout(date: today, kcal: 300)])
        #expect(await on.pendingWorkoutOffers().count == 1)
    }

    @Test("no offers when HealthKit is unavailable")
    func gatedOnAvailability() async throws {
        let (c, _) = try makeContainer(workoutsEnabled: true,
                                       seededWorkouts: [workout(date: today, kcal: 300)],
                                       healthAvailable: false)
        #expect(await c.pendingWorkoutOffers().isEmpty)
    }

    // MARK: - Apply / dedup / stacking

    @Test("accepting an offer adds its calories to that day's offset and stops re-offering it")
    func applyAddsOffsetAndDedups() async throws {
        let w = workout(date: today, kcal: 320)
        let (c, _) = try makeContainer(workoutsEnabled: true, seededWorkouts: [w])

        #expect(await c.pendingWorkoutOffers().count == 1)
        await c.applyWorkoutOffset(w)

        #expect(try await c.store.offset(on: today) == 320)     // folded into the day's offset
        #expect(await c.pendingWorkoutOffers().isEmpty)         // never offered twice
    }

    @Test("a manual offset is preserved and multiple workouts stack")
    func stacksOnExistingOffset() async throws {
        let w1 = workout(date: today, kcal: 200, name: "Walk")
        let w2 = workout(date: today, kcal: 150, name: "Strength Training")
        let (c, _) = try makeContainer(workoutsEnabled: true, seededWorkouts: [w1, w2])

        try await c.store.setOffset(100, on: today)   // pre-existing manual adjustment
        await c.applyWorkoutOffset(w1)
        await c.applyWorkoutOffset(w2)

        #expect(try await c.store.offset(on: today) == 450)     // 100 + 200 + 150
        #expect(await c.pendingWorkoutOffers().isEmpty)
    }

    @Test("dismissing an offer removes it without changing the offset")
    func dismissDoesNotOffset() async throws {
        let w = workout(date: today, kcal: 300)
        let (c, _) = try makeContainer(workoutsEnabled: true, seededWorkouts: [w])

        c.dismissWorkoutOffer(w)
        #expect(try await c.store.offset(on: today) == 0)       // untouched
        #expect(await c.pendingWorkoutOffers().isEmpty)         // not suggested again
    }

    @Test("enabling the toggle requests workout read access")
    func enablingRequestsAccess() async throws {
        let (c, _) = try makeContainer(workoutsEnabled: true, seededWorkouts: [])
        await c.requestWorkoutAccess()
        let mock = c.healthSync as? MockHealthSyncService
        #expect(await mock?.workoutAccessRequested == true)
    }
}
