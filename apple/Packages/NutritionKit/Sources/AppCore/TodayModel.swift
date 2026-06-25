// View model for the Today dashboard. Lives in AppCore (no SwiftUI) so its
// load/delete/offset orchestration over the NutritionStoring seam is unit-tested;
// the SwiftUI TodayView just observes it. `MacroProgress` is the pure ring/bar
// math for the macro card.

import Foundation
import Observation
import NutritionCore

/// Progress of a consumed value toward a daily target (drives a ring/bar).
public struct MacroProgress: Sendable, Equatable {
    public let consumed: Double
    public let target: Double

    public init(consumed: Double, target: Double) {
        self.consumed = consumed
        self.target = target
    }

    /// 0…1, clamped (0 when the target is non-positive).
    public var fraction: Double {
        guard target > 0 else { return 0 }
        return min(consumed / target, 1)
    }
    public var isOver: Bool { target > 0 && consumed > target }
    public var remaining: Double { max(target - consumed, 0) }
}

@Observable
@MainActor
public final class TodayModel {
    public let date: String
    @ObservationIgnored private let store: any NutritionStoring

    public private(set) var entries: [Entry] = []
    public private(set) var totals: MacroTotals = .zero
    public private(set) var offset: Double = 0
    public private(set) var isLoading = false
    /// "Your usuals": frequently-logged foods (last ~30 days) not yet logged today,
    /// for one-tap re-logging.
    public private(set) var usuals: [Entry] = []

    public init(store: any NutritionStoring, date: String = LocalDate.today()) {
        self.store = store
        self.date = date
    }

    /// Consumed calories minus the exercise/adjustment offset, clamped at zero.
    public var netCalories: Double {
        MacroMath.netCalories(total: totals.calories, offset: offset)
    }

    public func progress(for target: MacroTargets) -> (calories: MacroProgress, fat: MacroProgress, carbs: MacroProgress, protein: MacroProgress) {
        (
            MacroProgress(consumed: totals.calories, target: target.calories),
            MacroProgress(consumed: totals.fat, target: target.fat),
            MacroProgress(consumed: totals.carbs, target: target.carbs),
            MacroProgress(consumed: totals.protein, target: target.protein)
        )
    }

    public func load() async {
        isLoading = true
        defer { isLoading = false }
        async let entriesResult = store.entries(on: date)
        async let offsetResult = store.offset(on: date)
        let loaded = (try? await entriesResult) ?? []
        entries = loaded
        totals = MacroTotals.summing(loaded)
        offset = (try? await offsetResult) ?? 0
        await loadUsuals()
    }

    /// Recompute "your usuals" from the last ~30 days, excluding what's already on
    /// today's plate.
    private func loadUsuals() async {
        let endDate = LocalDate.date(from: date) ?? Date()
        let window = LocalDate.lastDays(30, endingOn: endDate)
        guard let start = window.first else { usuals = []; return }
        let recent = (try? await store.entries(from: start, to: date)) ?? []
        let loggedToday = Set(entries.map { FoodCorrection.key(food: $0.food, unit: $0.unit) })
        usuals = FoodFrequency.usuals(from: recent, excluding: loggedToday, limit: 8)
    }

    /// Re-log a previously-eaten food as a fresh entry for today, returning it (so the
    /// caller can offer an undo). Nutrition carries over 1:1.
    @discardableResult
    public func relog(_ previous: Entry, now: Date = Date()) async -> Entry {
        let fresh = Entry(
            id: UUID().uuidString, date: date, timestamp: now,
            food: previous.food, quantity: previous.quantity, unit: previous.unit,
            kcal: previous.kcal, fat: previous.fat, carbs: previous.carbs, protein: previous.protein,
            method: previous.method, confidence: previous.confidence,
            fiber: previous.fiber, sodium: previous.sodium, sugar: previous.sugar,
            nutritionConfidence: previous.nutritionConfidence
        )
        try? await store.add(fresh)
        await load()
        return fresh
    }

    /// Restore a previously-deleted entry (undo). Re-adds it by its original id.
    public func restore(_ entry: Entry) async {
        try? await store.add(entry)
        await load()
    }

    public func deleteEntry(id: String) async {
        try? await store.delete(id: id)
        await load()
    }

    public func updateOffset(_ value: Double) async {
        try? await store.setOffset(value, on: date)
        await load()
    }

    /// Persist a confirmed parse as a new entry, then refresh.
    public func add(_ entry: Entry) async {
        try? await store.add(entry)
        await load()
    }
}
