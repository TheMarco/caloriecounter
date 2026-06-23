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
