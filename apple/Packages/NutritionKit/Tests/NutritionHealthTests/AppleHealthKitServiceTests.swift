// AppleHealthKitService — the parts verifiable without a real Health database.
// On a dev/CI Mac `HKHealthStore.isHealthDataAvailable()` is false, so we assert
// the unavailable path is a safe no-op (the app must work without Apple Health).
// Full read/write behavior is device-only manual QA.

import Testing
import Foundation
@testable import NutritionHealth
import NutritionCore

@Suite("AppleHealthKitService")
struct AppleHealthKitServiceTests {

    @Test("when HealthKit is unavailable, every operation is a safe no-op")
    func unavailableIsSafe() async throws {
        let svc = AppleHealthKitService(appVersion: "test")
        // Skip on the rare host where HealthKit data is actually available.
        guard !svc.isAvailable() else { return }

        #expect(await svc.authorizationSummary() == .unavailable)
        #expect(try await svc.importWeights(daysBack: 30).isEmpty)

        // Best-effort writes/deletes must not throw when unavailable.
        let entry = Entry(id: "x", date: "2026-06-23", timestamp: Date(timeIntervalSince1970: 0),
                          food: "Oatmeal", quantity: 1, unit: "bowl",
                          kcal: 310, fat: 6, carbs: 54, protein: 10, method: .text)
        try await svc.syncFoodEntry(entry)
        try await svc.deleteSyncedFoodEntry(id: "x")
        try await svc.syncWeightEntry(WeightEntry(id: "w", date: "2026-06-23",
                                                  timestamp: Date(timeIntervalSince1970: 0), weightKg: 80))
        try await svc.removeAllAppData()
        try await svc.requestNutritionWriteAccess()
        try await svc.requestWeightAccess()
    }
}
