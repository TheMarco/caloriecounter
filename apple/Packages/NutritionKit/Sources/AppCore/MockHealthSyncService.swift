// In-memory no-op `HealthSyncing` for previews, UI tests, and unit tests. Records
// calls so tests can assert sync/edit/delete/import behavior without HealthKit.

import Foundation
import NutritionCore

public actor MockHealthSyncService: HealthSyncing {
    private let available: Bool
    /// Stored weights to hand back from `importWeights` (configurable for tests).
    private var weightStore: [WeightEntry]

    public private(set) var syncedFoodIDs: Set<String> = []
    public private(set) var syncFoodCallCount = 0
    public private(set) var deletedFoodIDs: [String] = []
    public private(set) var syncedWeightDates: Set<String> = []
    public private(set) var nutritionAccessRequested = false
    public private(set) var weightAccessRequested = false
    public private(set) var removeAllCalled = false

    public init(available: Bool = true, seededWeights: [WeightEntry] = []) {
        self.available = available
        self.weightStore = seededWeights
    }

    nonisolated public func isAvailable() -> Bool { available }

    public func requestNutritionWriteAccess() async throws { nutritionAccessRequested = true }
    public func requestWeightAccess() async throws { weightAccessRequested = true }

    public func syncFoodEntry(_ entry: Entry) async throws {
        syncFoodCallCount += 1
        syncedFoodIDs.insert(entry.id)   // idempotent set → edits don't duplicate
    }
    public func deleteSyncedFoodEntry(id: String) async throws {
        deletedFoodIDs.append(id)
        syncedFoodIDs.remove(id)
    }

    public func syncWeightEntry(_ entry: WeightEntry) async throws {
        syncedWeightDates.insert(entry.date)
        weightStore.removeAll { $0.date == entry.date }
        weightStore.append(entry)
    }
    public func importWeights(daysBack: Int) async throws -> [WeightEntry] {
        weightStore.sorted { $0.date < $1.date }
    }

    public func removeAllAppData() async throws {
        removeAllCalled = true
        syncedFoodIDs.removeAll()
        syncedWeightDates.removeAll()
        weightStore.removeAll()
    }

    public func authorizationSummary() async -> HealthAuthorizationSummary {
        available
            ? HealthAuthorizationSummary(isAvailable: true, nutritionWriteAuthorized: true, weightAuthorized: true)
            : .unavailable
    }
}
