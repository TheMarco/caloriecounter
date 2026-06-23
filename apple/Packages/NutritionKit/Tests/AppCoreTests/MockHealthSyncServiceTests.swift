// MockHealthSyncService records calls so the rest of the app's Health-sync
// behavior (edit doesn't duplicate, import dedup, remove-all) is testable.

import Testing
import Foundation
@testable import AppCore
import NutritionCore

@Suite("MockHealthSyncService")
struct MockHealthSyncServiceTests {

    private func entry(_ id: String) -> Entry {
        Entry(id: id, date: "2026-06-23", timestamp: Date(timeIntervalSince1970: 0),
              food: "F", quantity: 1, unit: "g", kcal: 100, fat: 1, carbs: 2, protein: 3, method: .text)
    }
    private func weight(_ date: String, _ kg: Double) -> WeightEntry {
        WeightEntry(id: WeightEntry.id(for: date), date: date,
                    timestamp: Date(timeIntervalSince1970: 0), weightKg: kg)
    }

    @Test("syncing the same food id twice doesn't duplicate; delete removes it")
    func foodSyncIdempotentAndDelete() async throws {
        let mock = MockHealthSyncService()
        try await mock.syncFoodEntry(entry("a"))
        try await mock.syncFoodEntry(entry("a"))   // edit / re-sync same id
        #expect(await mock.syncFoodCallCount == 2)
        #expect(await mock.syncedFoodIDs == ["a"])  // set → no duplicate

        try await mock.deleteSyncedFoodEntry(id: "a")
        #expect(await mock.syncedFoodIDs.isEmpty)
        #expect(await mock.deletedFoodIDs == ["a"])
    }

    @Test("weight sync upserts by day; import returns oldest-first; removeAll clears")
    func weightSyncImportRemove() async throws {
        let mock = MockHealthSyncService(seededWeights: [weight("2026-06-10", 83)])
        try await mock.syncWeightEntry(weight("2026-06-17", 82))
        try await mock.syncWeightEntry(weight("2026-06-17", 81.5))   // same day updates

        let imported = try await mock.importWeights(daysBack: 90)
        #expect(imported.map(\.date) == ["2026-06-10", "2026-06-17"])
        #expect(imported.last?.weightKg == 81.5)

        try await mock.removeAllAppData()
        #expect(await mock.removeAllCalled)
        #expect(try await mock.importWeights(daysBack: 90).isEmpty)
    }

    @Test("an unavailable mock reports unavailable")
    func unavailableMock() async {
        let mock = MockHealthSyncService(available: false)
        #expect(mock.isAvailable() == false)
        #expect(await mock.authorizationSummary() == .unavailable)
    }
}
