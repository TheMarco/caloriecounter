// The production FoodDatabaseQuerying seam. It defers touching FoodDatabase.shared
// — and therefore the ~380 ms cold load of the bundled 3 MB DB — until the first
// actual query, which happens off the main thread (TextInputModel offloads it).
// This keeps the heavy load off the synchronous app-launch path; AppContainer warms
// it in the background shortly after launch so the first suggestion is still fast.

import Foundation
import NutritionCore
import NutritionAI

public struct LazySharedFoodDatabase: FoodDatabaseQuerying {
    public init() {}

    public func suggestions(_ query: String, units: UnitSystem, limit: Int) -> [ParsedFood] {
        FoodDatabase.shared.suggestions(query, units: units, limit: limit)
    }
}
