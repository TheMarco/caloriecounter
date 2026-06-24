// CompositeFoodParser is the Analyze pipeline: try the on-device database first,
// fall back to the model parser only when the database can't resolve the food.

import Testing
@testable import AppCore
import NutritionCore

@Suite("CompositeFoodParser")
struct CompositeFoodParserTests {

    private enum StubError: Error { case noMatch }

    /// A FoodParsing stub that returns a fixed result or throws (to simulate no-match).
    private struct Stub: FoodParsing {
        let result: ParsedFood?
        func parse(text: String, units: UnitSystem) async throws -> ParsedFood {
            guard let result else { throw StubError.noMatch }
            return result
        }
    }

    @Test("a database hit wins; the fallback is never consulted")
    func databaseWins() async throws {
        let dbResult = ParsedFood(food: "BLT", quantity: 1, unit: "serving", kcal: 243)
        let fallback = ParsedFood(food: "fallback", quantity: 1, unit: "g", kcal: 1)
        let parser = CompositeFoodParser(database: Stub(result: dbResult), fallback: Stub(result: fallback))
        #expect(try await parser.parse(text: "a BLT", units: .metric) == dbResult)
    }

    @Test("a database miss falls through to the model parser")
    func fallsBack() async throws {
        let fallback = ParsedFood(food: "Mystery Stew", quantity: 250, unit: "g", kcal: 400)
        let parser = CompositeFoodParser(database: Stub(result: nil), fallback: Stub(result: fallback))
        #expect(try await parser.parse(text: "grandma's mystery stew", units: .metric) == fallback)
    }
}
