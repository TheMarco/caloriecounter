// DayProvenance: classify a day's logged food by where its numbers came from —
// all measured (exact), all estimated, or a mix. Provenance, never a value
// judgment; the calendar renders it as a subtle filled/hollow dot.

import Testing
@testable import NutritionCore

@Suite("DayProvenance")
struct DayProvenanceTests {

    @Test("a day with one estimated and one barcode entry is mixed")
    func mixed() {
        #expect(DayProvenance.from(confidences: [.estimated, .barcode]) == .mixed)
        #expect(DayProvenance.from(confidences: [.userEdited, .estimated]) == .mixed)
    }

    @Test("a day whose entries are all measured/adjusted is allExact")
    func allExact() {
        #expect(DayProvenance.from(confidences: [.barcode, .label]) == .allExact)
        #expect(DayProvenance.from(confidences: [.userEdited]) == .allExact)
    }

    @Test("a day of only estimates (or unknown/nil) is estimated")
    func estimated() {
        #expect(DayProvenance.from(confidences: [.estimated, .estimated]) == .estimated)
        #expect(DayProvenance.from(confidences: [.estimated, nil]) == .estimated)
        #expect(DayProvenance.from(confidences: [.unknown]) == .estimated)
    }

    @Test("a day with no entries has no provenance")
    func none() {
        #expect(DayProvenance.from(confidences: []) == DayProvenance.none)
    }
}
