// Round-trip + upsert coverage for the verified-label store (the per-barcode memory
// of user-confirmed nutrition labels). Fresh in-memory store per test, no simulator.

import Testing
import Foundation
@testable import NutritionStore
import NutritionCore

@Suite("BarcodeLabelStore")
struct BarcodeLabelStoreTests {

    private func makeStore() throws -> SwiftDataStore {
        try SwiftDataStore.make(inMemory: true)
    }

    private func label(_ barcode: String, kcal: Double, name: String = "Test Product") -> VerifiedLabel {
        VerifiedLabel(
            barcode: barcode,
            name: name,
            facts: LabelFacts(servingDescription: "1 serving", kcal: kcal, protein: 10, carbs: 20, fat: 5),
            updatedAt: Date(timeIntervalSince1970: 1_000)
        )
    }

    @Test("Unknown barcode returns nil")
    func unknownIsNil() async throws {
        let store = try makeStore()
        #expect(await store.verifiedLabel(for: "0000") == nil)
    }

    @Test("Save then fetch round-trips the values")
    func saveAndFetch() async throws {
        let store = try makeStore()
        await store.saveVerifiedLabel(label("123", kcal: 240))
        let got = try #require(await store.verifiedLabel(for: "123"))
        #expect(got.barcode == "123")
        #expect(got.name == "Test Product")
        #expect(got.facts.kcal == 240)
        #expect(got.facts.protein == 10)
    }

    @Test("Saving the same barcode upserts (no duplicate, newest wins)")
    func upsert() async throws {
        let store = try makeStore()
        await store.saveVerifiedLabel(label("123", kcal: 240))
        await store.saveVerifiedLabel(label("123", kcal: 300, name: "Renamed"))
        let got = try #require(await store.verifiedLabel(for: "123"))
        #expect(got.facts.kcal == 300)
        #expect(got.name == "Renamed")
    }

    @Test("Distinct barcodes are independent")
    func independentBarcodes() async throws {
        let store = try makeStore()
        await store.saveVerifiedLabel(label("111", kcal: 100))
        await store.saveVerifiedLabel(label("222", kcal: 200))
        #expect(await store.verifiedLabel(for: "111")?.facts.kcal == 100)
        #expect(await store.verifiedLabel(for: "222")?.facts.kcal == 200)
    }
}
