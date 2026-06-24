// Diagnostic harness for the food-matching quality sweep. Reads one query per line
// from apple/scripts/sweep-queries.txt and emits, for each, the matched food + its
// per-100g calories + whether the query's head noun appears in the match name. No
// file (the normal case) → no-op, so the committed suite stays green. Output is
// surfaced via Issue.record (Swift Testing swallows stdout for passing tests).

import Testing
import Foundation
@testable import NutritionAI

@Suite("SweepHarness")
struct SweepHarness {
    @Test("emit matcher results for sweep-queries.txt (diagnostic; no file → no-op)")
    func emit() {
        let path = "/Users/marcovhv/projects/GIT/caloriecounter/apple/scripts/sweep-queries.txt"
        guard let text = try? String(contentsOfFile: path, encoding: .utf8) else { return }
        let queries = text.split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        guard !queries.isEmpty else { return }

        let db = FoodDatabase.shared
        var out = "\n"
        for q in queries {
            guard let f = db.bestConfidentMatch(q) else {
                out += "RESULT ||| \(q) ||| NONE ||| -1 ||| 0\n"
                continue
            }
            let raw = FoodDatabase.expandAliases(FoodDatabase.tokenize(q))
            let qf = raw.filter { !FoodDatabase.fillerWords.contains($0) }
            let connIdx = raw.firstIndex { FoodDatabase.connectors.contains($0) }
            let head = connIdx.map { raw[..<$0].last { !FoodDatabase.fillerWords.contains($0) } ?? qf.first } ?? qf.last
            let headIn = (head != nil && Set(FoodDatabase.tokenize(f.name)).contains(head!)) ? "1" : "0"
            out += "RESULT ||| \(q) ||| \(f.name) ||| \(Int(f.kcal)) ||| \(headIn)\n"
        }
        Issue.record(Comment(rawValue: out))
    }
}
