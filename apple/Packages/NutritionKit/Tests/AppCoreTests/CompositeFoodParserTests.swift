// CompositeFoodParser is the Analyze pipeline as an ordered fall-through chain:
// database match → FM decomposition → single-food estimate. Each stage throws to
// hand off to the next; the first success wins.

import Testing
@testable import AppCore
import NutritionCore

@Suite("CompositeFoodParser")
struct CompositeFoodParserTests {

    private enum StubError: Error { case skip }

    /// A FoodParsing stub that returns a fixed result or throws (to simulate "skip").
    private struct Stub: FoodParsing {
        let result: ParsedFood?
        func parse(text: String, units: UnitSystem) async throws -> ParsedFood {
            guard let result else { throw StubError.skip }
            return result
        }
    }

    private func food(_ name: String) -> ParsedFood {
        ParsedFood(food: name, quantity: 1, unit: "serving", kcal: 100)
    }

    @Test("the first stage that succeeds wins; later stages aren't consulted")
    func firstSuccessWins() async throws {
        let parser = CompositeFoodParser([Stub(result: food("database")), Stub(result: food("decomposed")), Stub(result: food("single"))])
        #expect(try await parser.parse(text: "x", units: .metric).food == "database")
    }

    @Test("a database miss routes to decomposition when it can handle the meal")
    func fallsToDecomposition() async throws {
        let parser = CompositeFoodParser([Stub(result: nil), Stub(result: food("decomposed")), Stub(result: food("single"))])
        #expect(try await parser.parse(text: "grandma's stew", units: .metric).food == "decomposed")
    }

    @Test("database miss + decomposition unavailable falls through to the single-food estimate")
    func fallsToSingleFood() async throws {
        let parser = CompositeFoodParser([Stub(result: nil), Stub(result: nil), Stub(result: food("single"))])
        #expect(try await parser.parse(text: "mystery", units: .metric).food == "single")
    }

    @Test("if every stage skips, the composite throws")
    func allSkip() async {
        let parser = CompositeFoodParser([Stub(result: nil), Stub(result: nil)])
        await #expect(throws: (any Error).self) {
            _ = try await parser.parse(text: "x", units: .metric)
        }
    }
}
