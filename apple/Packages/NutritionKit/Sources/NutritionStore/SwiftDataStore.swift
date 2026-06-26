// SwiftData implementation of `NutritionStoring` (plan Phase 2). A `@ModelActor`
// so every `ModelContext` access is serialized on the actor's executor — safe
// under Swift 6 strict concurrency while parsers / network run concurrently.
//
// Local-only: the on-disk store has no CloudKit/iCloud configuration (security
// requirement — nutrition data never leaves the device). Query and aggregation
// semantics mirror `src/utils/idb.ts`.

import Foundation
import SwiftData
import NutritionCore

@ModelActor
public actor SwiftDataStore: NutritionStoring {

    // MARK: - Mutations

    public func add(_ entry: Entry) async throws {
        // Upsert on the unique id so a re-add never duplicates a row.
        let id = entry.id
        let descriptor = FetchDescriptor<EntryRecord>(predicate: #Predicate { $0.id == id })
        if let existing = try modelContext.fetch(descriptor).first {
            existing.update(from: entry)
        } else {
            modelContext.insert(EntryRecord(from: entry))
        }
        try modelContext.save()
    }

    public func update(_ entry: Entry) async throws {
        let id = entry.id
        let descriptor = FetchDescriptor<EntryRecord>(predicate: #Predicate { $0.id == id })
        guard let existing = try modelContext.fetch(descriptor).first else { return }
        existing.update(from: entry)
        try modelContext.save()
    }

    public func delete(id: String) async throws {
        let target = id
        let descriptor = FetchDescriptor<EntryRecord>(predicate: #Predicate { $0.id == target })
        for record in try modelContext.fetch(descriptor) { modelContext.delete(record) }
        try modelContext.save()
    }

    // MARK: - Day / range queries

    public func entries(on date: String) async throws -> [Entry] {
        let day = date
        let descriptor = FetchDescriptor<EntryRecord>(
            predicate: #Predicate { $0.date == day },
            sortBy: [SortDescriptor(\.timestamp, order: .reverse)]   // newest-first
        )
        return try modelContext.fetch(descriptor).map { $0.toDomain() }
    }

    public func entries(from startDate: String, to endDate: String) async throws -> [Entry] {
        let start = startDate, end = endDate
        let descriptor = FetchDescriptor<EntryRecord>(
            predicate: #Predicate { $0.date >= start && $0.date <= end },
            sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
        )
        return try modelContext.fetch(descriptor).map { $0.toDomain() }
    }

    // MARK: - Aggregation

    public func macroTotals(on date: String) async throws -> MacroTotals {
        MacroTotals.summing(try await entries(on: date))
    }

    public func dailyTotals(lastDays days: Int) async throws -> [DayTotals] {
        let keys = LocalDate.lastDays(days)               // oldest-first, [] if days <= 0
        guard let start = keys.first, let end = keys.last else { return [] }

        // One range fetch, grouped by day, instead of a query per day.
        let dayEntries = try await entries(from: start, to: end)
        var totalsByDate: [String: MacroTotals] = [:]
        for entry in dayEntries {
            totalsByDate[entry.date, default: .zero] = totalsByDate[entry.date, default: .zero].adding(entry)
        }

        // Offsets for the same window.
        let offsetDescriptor = FetchDescriptor<DayOffsetRecord>(
            predicate: #Predicate { $0.date >= start && $0.date <= end }
        )
        var offsetByDate: [String: Double] = [:]
        for record in try modelContext.fetch(offsetDescriptor) { offsetByDate[record.date] = record.offset }

        return keys.map { key in
            DayTotals(date: key, totals: totalsByDate[key] ?? .zero, offset: offsetByDate[key] ?? 0)
        }
    }

    // MARK: - Search (web `searchPreviousFood` over `getAllUniqueFood`)

    public func searchPreviousFoods(_ query: String, limit: Int) async throws -> [Entry] {
        guard query.count >= Constants.minSearchQueryLength else { return [] }
        let needle = query.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        guard !needle.isEmpty else { return [] }

        return try allUniqueFoods()
            .filter { $0.food.lowercased().contains(needle) }
            .prefix(limit)
            .map { $0 }
    }

    /// Distinct foods (deduped case-insensitively by name), each represented by its
    /// most-recent entry, ranked by frequency then recency. Port of `getAllUniqueFood`.
    private func allUniqueFoods() throws -> [Entry] {
        let all = try modelContext.fetch(FetchDescriptor<EntryRecord>()).map { $0.toDomain() }

        struct Bucket { var entry: Entry; var count: Int; var lastUsed: Date }
        var byName: [String: Bucket] = [:]
        for entry in all {
            let key = entry.food.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
            if let existing = byName[key] {
                byName[key] = Bucket(
                    entry: entry.timestamp > existing.entry.timestamp ? entry : existing.entry,
                    count: existing.count + 1,
                    lastUsed: max(existing.lastUsed, entry.timestamp)
                )
            } else {
                byName[key] = Bucket(entry: entry, count: 1, lastUsed: entry.timestamp)
            }
        }

        return byName.values
            .sorted { a, b in
                a.count != b.count ? a.count > b.count : a.lastUsed > b.lastUsed
            }
            .map { $0.entry }
    }

    // MARK: - Offsets (web `offset:{date}`)

    public func offset(on date: String) async throws -> Double {
        let day = date
        let descriptor = FetchDescriptor<DayOffsetRecord>(predicate: #Predicate { $0.date == day })
        return try modelContext.fetch(descriptor).first?.offset ?? 0
    }

    public func setOffset(_ value: Double, on date: String) async throws {
        let day = date
        let descriptor = FetchDescriptor<DayOffsetRecord>(predicate: #Predicate { $0.date == day })
        if let existing = try modelContext.fetch(descriptor).first {
            existing.offset = value
        } else {
            modelContext.insert(DayOffsetRecord(date: day, offset: value))
        }
        try modelContext.save()
    }

    // MARK: - Full wipe

    public func deleteAll() async throws {
        try modelContext.delete(model: EntryRecord.self)
        try modelContext.delete(model: DayOffsetRecord.self)
        try modelContext.delete(model: WeightRecord.self)
        try modelContext.save()
    }

    // MARK: - Body weight

    public func addWeight(_ entry: WeightEntry) async throws {
        let id = entry.id
        let descriptor = FetchDescriptor<WeightRecord>(predicate: #Predicate { $0.id == id })
        if let existing = try modelContext.fetch(descriptor).first {
            existing.update(from: entry)
        } else {
            modelContext.insert(WeightRecord(from: entry))
        }
        try modelContext.save()
    }

    public func weights(from startDate: String, to endDate: String) async throws -> [WeightEntry] {
        let start = startDate, end = endDate
        let descriptor = FetchDescriptor<WeightRecord>(
            predicate: #Predicate { $0.date >= start && $0.date <= end },
            sortBy: [SortDescriptor(\.date, order: .forward)]   // oldest-first for charting
        )
        return try modelContext.fetch(descriptor).map { $0.toDomain() }
    }

    public func latestWeight() async throws -> WeightEntry? {
        var descriptor = FetchDescriptor<WeightRecord>(sortBy: [SortDescriptor(\.date, order: .reverse)])
        descriptor.fetchLimit = 1
        return try modelContext.fetch(descriptor).first?.toDomain()
    }

    public func deleteWeight(id: String) async throws {
        let target = id
        let descriptor = FetchDescriptor<WeightRecord>(predicate: #Predicate { $0.id == target })
        for record in try modelContext.fetch(descriptor) { modelContext.delete(record) }
        try modelContext.save()
    }
}

// MARK: - Per-food correction memory (additive — see CorrectionRecord)

extension SwiftDataStore: FoodCorrectionStoring {
    /// Upsert a correction by its normalized key. Best-effort (memory, not data the
    /// user would miss), so a failure is swallowed rather than surfaced.
    public func remember(_ correction: FoodCorrection) async {
        let key = correction.key
        let descriptor = FetchDescriptor<CorrectionRecord>(predicate: #Predicate { $0.key == key })
        do {
            if let existing = try modelContext.fetch(descriptor).first {
                existing.update(from: correction)
            } else {
                modelContext.insert(CorrectionRecord(from: correction))
            }
            try modelContext.save()
        } catch {
            // Correction memory is a convenience; never let it break a save flow.
        }
    }

    public func correction(for key: String) async -> FoodCorrection? {
        let k = key
        let descriptor = FetchDescriptor<CorrectionRecord>(predicate: #Predicate { $0.key == k })
        return (try? modelContext.fetch(descriptor).first)?.toDomain()
    }
}

// MARK: - Verified-label memory (additive — see BarcodeLabelRecord)

extension SwiftDataStore: BarcodeLabelStoring {
    /// Upsert a verified label by its barcode. Best-effort like correction memory —
    /// a failure is swallowed rather than breaking the save flow.
    public func saveVerifiedLabel(_ label: VerifiedLabel) async {
        let code = label.barcode
        let descriptor = FetchDescriptor<BarcodeLabelRecord>(predicate: #Predicate { $0.barcode == code })
        do {
            if let existing = try modelContext.fetch(descriptor).first {
                existing.update(from: label)
            } else {
                modelContext.insert(BarcodeLabelRecord(from: label))
            }
            try modelContext.save()
        } catch {
            // Verified-label memory is a convenience; never let it break a save flow.
        }
    }

    public func verifiedLabel(for barcode: String) async -> VerifiedLabel? {
        let code = barcode
        let descriptor = FetchDescriptor<BarcodeLabelRecord>(predicate: #Predicate { $0.barcode == code })
        return (try? modelContext.fetch(descriptor).first)?.toDomain()
    }
}

public extension SwiftDataStore {
    /// The model types this store manages.
    static var schemaTypes: [any PersistentModel.Type] { [EntryRecord.self, DayOffsetRecord.self, WeightRecord.self, CorrectionRecord.self, BarcodeLabelRecord.self] }

    /// Build a store. `inMemory` for tests/previews; an explicit `url` overrides
    /// (used by the app to place the on-disk store under Application Support with
    /// OS Data Protection). Local-only — no CloudKit configuration.
    static func make(inMemory: Bool = false, url: URL? = nil) throws -> SwiftDataStore {
        let configuration: ModelConfiguration = {
            if let url { return ModelConfiguration(url: url) }
            return ModelConfiguration(isStoredInMemoryOnly: inMemory)
        }()
        let container = try ModelContainer(
            for: EntryRecord.self, DayOffsetRecord.self, WeightRecord.self, CorrectionRecord.self, BarcodeLabelRecord.self,
            configurations: configuration
        )
        return SwiftDataStore(modelContainer: container)
    }
}
