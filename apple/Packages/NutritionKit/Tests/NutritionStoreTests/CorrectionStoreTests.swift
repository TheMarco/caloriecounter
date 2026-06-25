// SwiftDataStore as FoodCorrectionStoring: upsert-by-key and that the additive
// CorrectionRecord table coexists with existing entry data (no migration loss).

import Testing
import Foundation
@testable import NutritionStore
import NutritionCore

@Suite("Correction memory store")
struct CorrectionStoreTests {

    private func makeStore() throws -> SwiftDataStore { try SwiftDataStore.make(inMemory: true) }

    @Test("remember then correction(for:) round-trips by key")
    func rememberRecall() async throws {
        let store = try makeStore()
        let key = FoodCorrection.key(food: "Banana", unit: "piece")
        #expect(await store.correction(for: key) == nil)

        let c = FoodCorrection(food: "Banana", unit: "piece",
                               kcal: 100, fat: 0.4, carbs: 27, protein: 1.3,
                               updatedAt: Date(timeIntervalSince1970: 1))
        await store.remember(c)
        #expect(await store.correction(for: key) == c)
    }

    @Test("remember upserts by key — a second correction replaces the first")
    func upsertByKey() async throws {
        let store = try makeStore()
        let key = FoodCorrection.key(food: "rice", unit: "g")
        await store.remember(FoodCorrection(food: "rice", unit: "g", kcal: 200, fat: 1, carbs: 44, protein: 4,
                                            updatedAt: Date(timeIntervalSince1970: 1)))
        await store.remember(FoodCorrection(food: "Rice", unit: "g", kcal: 260, fat: 1, carbs: 56, protein: 5,
                                            updatedAt: Date(timeIntervalSince1970: 2)))
        let got = await store.correction(for: key)
        #expect(got?.kcal == 260)   // the later value wins; no duplicate row
    }

    @Test("the additive CorrectionRecord table coexists with existing entries")
    func additiveSchema() async throws {
        let store = try makeStore()
        // Existing data path still works alongside the new table.
        try await store.add(Entry(id: "e1", date: "2026-06-22", timestamp: Date(timeIntervalSince1970: 1),
                                  food: "Oats", quantity: 50, unit: "g",
                                  kcal: 190, fat: 3, carbs: 33, protein: 7, method: .text))
        await store.remember(FoodCorrection(food: "Oats", unit: "g", kcal: 180, fat: 3, carbs: 31, protein: 7,
                                            updatedAt: Date(timeIntervalSince1970: 2)))
        #expect(try await store.entries(on: "2026-06-22").count == 1)
        #expect(await store.correction(for: FoodCorrection.key(food: "oats", unit: "g")) != nil)
    }
}
