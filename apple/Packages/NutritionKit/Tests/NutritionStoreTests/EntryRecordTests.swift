// Direct unit coverage for the EntryRecord ↔ Entry mapping, independent of the
// store. Locks the defensive fallback in `toDomain()`: a persisted row whose
// `method` string isn't a known `InputMethod` must still map to a usable entry
// (defaulting to `.text`) rather than being silently dropped.

import Testing
import Foundation
@testable import NutritionStore
import NutritionCore

@Suite("EntryRecord mapping")
struct EntryRecordTests {

    private func sampleEntry() -> Entry {
        Entry(
            id: "e1", date: "2026-06-22", timestamp: Date(timeIntervalSince1970: 123),
            food: "Oats", quantity: 50, unit: "g",
            kcal: 190, fat: 3.4, carbs: 33, protein: 6.8, method: .voice, confidence: 0.9
        )
    }

    @Test("from(_:) → toDomain() is a faithful round-trip")
    func roundTrip() {
        let original = sampleEntry()
        #expect(EntryRecord(from: original).toDomain() == original)
    }

    @Test("update(from:) overwrites all mutable fields but keeps identity")
    func updateInPlace() {
        let record = EntryRecord(from: sampleEntry())
        let replacement = Entry(
            id: "e1", date: "2026-06-23", timestamp: Date(timeIntervalSince1970: 999),
            food: "Granola", quantity: 60, unit: "g",
            kcal: 280, fat: 9, carbs: 40, protein: 7, method: .photo, confidence: nil
        )
        record.update(from: replacement)
        #expect(record.toDomain() == replacement)
        #expect(record.id == "e1")
    }

    @Test("toDomain() falls back to .text for an unknown method string")
    func unknownMethodFallback() {
        let record = EntryRecord(from: sampleEntry())
        record.method = "telepathy"        // not a valid InputMethod raw value
        #expect(record.toDomain().method == .text)
    }
}
