// FoodFrequency.usuals: the "your usuals" ranking — most-frequent distinct foods
// from recent entries, each as its most-recent representative, newest-frequency
// first, excluding what's already logged today. Pure + unit-tested.

import Testing
import Foundation
@testable import NutritionCore

@Suite("FoodFrequency.usuals")
struct FoodFrequencyTests {

    private func entry(_ food: String, _ unit: String = "g", at t: TimeInterval) -> Entry {
        Entry(id: "\(food)-\(t)", date: "2026-06-20", timestamp: Date(timeIntervalSince1970: t),
              food: food, quantity: 100, unit: unit, kcal: 100, fat: 1, carbs: 1, protein: 1, method: .text)
    }

    @Test("most-frequent foods come first; each appears once")
    func ranksByFrequency() {
        let recent = [
            entry("Coffee", at: 1), entry("Coffee", at: 2), entry("Coffee", at: 3),
            entry("Eggs", at: 4), entry("Eggs", at: 5),
            entry("Toast", at: 6),
        ]
        let usuals = FoodFrequency.usuals(from: recent, limit: 5)
        #expect(usuals.map(\.food) == ["Coffee", "Eggs", "Toast"])   // 3× , 2× , 1×
        // The representative is the most recent of its group.
        #expect(usuals.first { $0.food == "Coffee" }?.timestamp == Date(timeIntervalSince1970: 3))
    }

    @Test("ties break by recency, and the limit is honored")
    func tieByRecencyAndLimit() {
        let recent = [entry("A", at: 1), entry("B", at: 9), entry("C", at: 5)]  // all 1×
        #expect(FoodFrequency.usuals(from: recent, limit: 2).map(\.food) == ["B", "C"])  // newest first
    }

    @Test("foods already logged today are excluded")
    func excludesToday() {
        let recent = [entry("Coffee", at: 3), entry("Coffee", at: 2), entry("Eggs", at: 1)]
        let excluding: Set<String> = [FoodCorrection.key(food: "coffee", unit: "g")]
        #expect(FoodFrequency.usuals(from: recent, excluding: excluding, limit: 5).map(\.food) == ["Eggs"])
    }

    @Test("same food in different units is distinct")
    func unitDistinct() {
        let recent = [entry("Milk", "cup", at: 2), entry("Milk", "ml", at: 1)]
        #expect(FoodFrequency.usuals(from: recent, limit: 5).count == 2)
    }
}
