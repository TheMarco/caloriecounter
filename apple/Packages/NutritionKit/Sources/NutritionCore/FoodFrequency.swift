// FoodFrequency — "your usuals": the foods you log often, surfaced for one-tap
// re-logging. Pure ranking over recent entries so it's unit-tested; TodayModel
// feeds it the last few weeks and the view shows the top few.

import Foundation

public enum FoodFrequency {
    /// The most-frequent distinct foods (by normalized food+unit) from `recent`,
    /// each represented by its most-recent entry, ordered by frequency then recency,
    /// excluding any whose key is in `excluding` (e.g. already logged today), capped
    /// at `limit`.
    public static func usuals(from recent: [Entry], excluding: Set<String> = [], limit: Int) -> [Entry] {
        var counts: [String: Int] = [:]
        var representative: [String: Entry] = [:]   // most-recent entry per key
        for e in recent {
            let key = FoodCorrection.key(food: e.food, unit: e.unit)
            counts[key, default: 0] += 1
            if let existing = representative[key] {
                if e.timestamp > existing.timestamp { representative[key] = e }
            } else {
                representative[key] = e
            }
        }
        return representative.values
            .filter { !excluding.contains(FoodCorrection.key(food: $0.food, unit: $0.unit)) }
            .sorted { a, b in
                let ka = FoodCorrection.key(food: a.food, unit: a.unit)
                let kb = FoodCorrection.key(food: b.food, unit: b.unit)
                let (ca, cb) = (counts[ka] ?? 0, counts[kb] ?? 0)
                if ca != cb { return ca > cb }            // more often first
                return a.timestamp > b.timestamp          // then more recent
            }
            .prefix(limit)
            .map { $0 }
    }
}
