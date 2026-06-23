# Plan 002 — Apple Health + Fiber/Sodium (+ Sugar)

> **For Claude:** Execute this plan using `/superbuild` skill.
> Run from repo root `/Users/marcovhv/projects/GIT/caloriecounter`. The iOS app lives under `apple/`.
> Build/test commands (run from `apple/`):
> - Package tests (fast, macOS): `cd apple/Packages/NutritionKit && swift test`
> - App build: `cd apple && xcodebuild -project CalorieCounter.xcodeproj -scheme CalorieCounter -destination 'platform=iOS Simulator,id=409B0B01-EAA4-4969-AF8F-F97EF3C31ADD' build`
> - UI tests: add `-only-testing:CalorieCounterUITests/<Suite>` and `test`. **If a newly added test method isn't discovered, run with `clean test` once** (known incremental-build quirk in this project).
> - After adding NEW files to the app target **or a new package target**: `cd apple && xcodegen generate`.

---

## Product Principle (non-negotiable)

> **Calories and macros are the interface. Fiber and sodium are context. Apple Health is infrastructure.**

No fiber/sodium rings. No micronutrient dashboard. No medical warnings. No new top-level tab. The Today screen hierarchy (calorie ring + 3 macro rings) stays primary. The app remains local-first, no-account, privacy-forward, on-device-first. The result must feel like the same app, only smarter.

## Decisions locked in (from interview)

1. **Weight import conflicts → prompt on conflict.** When a Health weight conflicts with an existing same-day local weight, present a conflict sheet (Use Apple Health / Keep current) per conflicting day. Non-conflicting days import silently.
2. **Remove-from-Health → implement now.** Settings includes a destructive "Remove this app's data from Apple Health" action (metadata-query bulk delete), separate from "Disconnect".
3. **Add the `NutritionConfidence` enum.** A first-class field on `Entry`/`ParsedFood` (label/barcode/userEdited/estimated/unknown) used to avoid pretending AI-estimated fiber/sodium is exact.

## Units (canonical)

- **Fiber:** grams (`Double?`).
- **Sugar:** grams (`Double?`).
- **Sodium:** **milligrams** (`Double?`) everywhere in the app/model/CSV. OpenFoodFacts returns sodium in **grams** → multiply by 1000. HealthKit stores sodium as a **mass** (grams) → convert mg→g at the HealthKit boundary only.
- `nil` = unknown, `0` = known zero. Never coerce unknown → zero in totals/trends.

---

## Architecture

### Layer graph (unchanged, one new module)

```
                         ┌───────────────┐
        ┌───────────────▶│ NutritionCore │◀───────────────┐
        │                └───────────────┘                │
┌───────────────┐ ┌───────────────┐ ┌──────────────┐ ┌───────────────┐
│ NutritionStore│ │ NutritionAPI  │ │ NutritionAI  │ │ NutritionHealth│ (NEW)
└───────────────┘ └───────────────┘ └──────────────┘ └───────────────┘
        ▲                ▲                ▲                ▲
        └────────────────┴───────┬────────┴────────────────┘
                          ┌──────────────┐
                          │   AppCore    │  (DI container wires all seams)
                          └──────────────┘
                                 ▲
                          ┌──────────────┐
                          │ CalorieCounter│ (app target: entitlement + Info.plist)
                          └──────────────┘
```

- **NutritionCore:** add fiber/sodium/sugar + `NutritionConfidence` + HealthKit sync metadata to `Entry`; optional aggregates on `MacroTotals`; `HealthKitSyncStatus` enum; the `HealthSyncing` seam + `HealthAuthorizationSummary`/`WeightConflict` value types.
- **NutritionHealth (NEW target):** `AppleHealthKitService: HealthSyncing` — the only code that imports `HealthKit`. Linked framework via `linkerSettings: [.linkedFramework("HealthKit")]`. Depends on `NutritionCore`.
- **AppCore:** `MockHealthSyncService` (no-op for previews/tests); `AppContainer` gains a `healthSync: any HealthSyncing` seam; `SettingsStore` gains the new persisted toggles; `NutritionSignals` + `WeeklyInsights` pure helpers; `MacroKind` gains `.fiber`/`.sodium`.
- **App target:** HealthKit entitlement + Info.plist usage strings; the new UI (Nutrition Signals card, Advanced Nutrition edit section, History signal selector, Apple Health settings, weight conflict sheet).

### Data flow for nutrient capture

```
Barcode  → OpenFoodFactsResolver → ParsedFood{fiber,sodium(mg),sugar, confidence=.barcode}
Label    → NutritionLabelParser  → ParsedFood{...,                  confidence=.label}
Voice/Text → NutritionInfo(@Generable)→ toParsedFood (rounds est.) → ParsedFood{..., confidence=.estimated}
Manual edit → user sets values                                     → Entry{..., confidence=.userEdited}
            → FoodConfirmModel/EditEntryView → Entry (persisted) → MacroTotals aggregates (nil-aware)
            → Today "Nutrition Signals" card / History signal trends / Apple Health write
```

### Apple Health write model

- One `HKCorrelation(type: .food)` per food entry, grouping `HKQuantitySample`s for energy/protein/carbs/fat/fiber/sodium/sugar (only for non-nil values).
- Metadata: `["CalorieCounterFoodEntryID": entry.id, "CalorieCounterAppVersion": version, HKMetadataKeyFoodType: entry.food]`.
- **Edit** = delete-by-metadata-query (predicate on `CalorieCounterFoodEntryID`) then recreate. **Delete** = delete-by-metadata-query. Never touch other apps' data.
- Sync state stored on the entry (`healthKitSyncedAt`/`healthKitSyncStatus`/`healthKitLastError`); failures are non-fatal.

---

## Phase Overview

| Phase | Name | Depends On | Parallel With | Est | Status |
|-------|------|------------|---------------|-----|--------|
| 1 | Data model: fiber/sodium/sugar + confidence + HK metadata + migration | — | — | 5 | ⬜ |
| 2 | CSV export/import for fiber/sodium/sugar (backward compatible) | 1 | 3,4 | 3 | ⬜ |
| 3 | Capture in parsers (OFF, label OCR, AI, heuristic) | 1 | 2,4 | 5 | ⬜ |
| 4 | Manual edit + confirm "Advanced Nutrition" UI | 1 | 2,3 | 3 | ⬜ |
| 5 | `MacroTotals` aggregates + Today "Nutrition Signals" card | 1 | 6 | 5 | ⬜ |
| 6 | Settings: Nutrition Signals (fiber target / sodium reference) | 1 | 5 | 3 | ⬜ |
| 7 | History fiber/sodium secondary trends | 1,5,6 | 8 | 5 | ⬜ |
| 8 | Weekly insights card | 1,5,6 | 7 | 5 | ⬜ |
| 9 | HealthKit architecture: seam + NutritionHealth target + mock + wiring | 1 | — | 5 | ⬜ |
| 10 | Apple Health nutrition write (correlation + edit/delete by metadata) | 9 | 11 | 8 | ⬜ |
| 11 | Apple Health weight read/write (+ prompt-on-conflict) | 9 | 10 | 5 | ⬜ |
| 12 | Apple Health Settings UI (toggles, repair, disconnect, remove-data) | 10,11 | — | 5 | ⬜ |
| 13 | Privacy/About copy + permission strings | 9 | — | 2 | ⬜ |
| 14 | Demo mode: fiber/sodium + high-sodium→weight-bump + insight | 1,3,8 | — | 3 | ⬜ |
| 15 | Final test sweep, build, concurrency/warning cleanup | all | — | 5 | ⬜ |

**Total ≈ 67 points.** Phase 1 and Phase 9 are the two roots. After Phase 1, Phases 2/3/4/5/6/9 are largely independent.

```
1 ──┬─▶ 2
    ├─▶ 3 ─────────────┐
    ├─▶ 4              │
    ├─▶ 5 ─┬─▶ 7 ─┐    │
    ├─▶ 6 ─┘      ├─▶ 8 ┘
    └─▶ 9 ─┬─▶ 10 ─┐
           └─▶ 11 ─┴─▶ 12
9 ─▶ 13
(1,3,8) ─▶ 14
all ─▶ 15
```

---

## Phase 1 — Data model for fiber/sodium/sugar + confidence + HealthKit metadata

**Goal:** Add the optional nutrient fields, the `NutritionConfidence` enum, and HealthKit sync metadata to the domain `Entry` and the SwiftData `EntryRecord`, with a clean lightweight migration (adding optional properties is non-breaking in SwiftData). Keep `nil`≠`0`.

### Tasks (TDD)

- [ ] **1.1 Add `NutritionConfidence` + `HealthKitSyncStatus` enums.** `NutritionCore/NutritionConfidence.swift (CREATE)`:
  ```swift
  import Foundation
  public enum NutritionConfidence: String, Codable, Sendable, CaseIterable {
      case label, barcode, userEdited, estimated, unknown
      /// Whether values from this source should be treated as exact (vs. rounded estimates).
      public var isExact: Bool { self == .label || self == .barcode || self == .userEdited }
  }
  public enum HealthKitSyncStatus: String, Codable, Sendable {
      case notSynced, synced, failed
  }
  ```
  Test (`NutritionCoreTests/NutritionConfidenceTests.swift`): round-trips rawValues; `isExact` true for label/barcode/userEdited, false for estimated/unknown.

- [ ] **1.2 Extend `Entry`** (`NutritionCore/Entry.swift:14-58`). Add stored properties after `confidence`:
  ```swift
  public var fiber: Double?      // grams (nil = unknown)
  public var sodium: Double?     // milligrams (nil = unknown)
  public var sugar: Double?      // grams (nil = unknown)
  public var nutritionConfidence: NutritionConfidence?
  public var healthKitSyncedAt: Date?
  public var healthKitSyncStatus: HealthKitSyncStatus?
  public var healthKitLastError: String?
  ```
  Update the `init` to accept all new params with **defaults** (`fiber: Double? = nil, … , healthKitSyncStatus: HealthKitSyncStatus? = nil, healthKitLastError: String? = nil`) so every existing call site keeps compiling. Test (`Entry` equatable/codable round-trip incl. nils; verify `nil` stays `nil` and `0` stays `0` through `Codable`).

- [ ] **1.3 Extend `ParsedFood`** (`NutritionCore/ParsedFood.swift:9-75`). Add `fiber/sodium/sugar: Double?` and `nutritionConfidence: NutritionConfidence?` with defaulted init params; thread them through `init(entry:)` and `makeEntry(...)`. Test: `makeEntry` carries fiber/sodium/sugar/confidence into the `Entry`; `init(entry:)` carries them back.

- [ ] **1.4 Extend `EntryRecord`** (`NutritionStore/EntryRecord.swift:19-83`). Mirror the new optional columns (`var fiber: Double?` … `var healthKitLastError: String?`; store `nutritionConfidence`/`healthKitSyncStatus` as `String?` rawValues to match the existing `method: String` convention). Update `init(from:)`, `update(from:)`, `toDomain()` to map them. Test (`NutritionStoreTests`): add an entry with fiber=3, sodium=850, sugar=nil, confidence=.barcode; fetch and assert exact round-trip; a second entry with all nutrient fields nil stays nil (not 0).

- [ ] **1.5 Migration check.** SwiftData lightweight migration covers added optional properties automatically (no schema version bump needed for purely additive optionals). Add a store test that opens an **on-disk** store, writes a pre-change-shaped entry via the public API, and verifies new fields read back as nil. Manually run the app with `-demo` after build to confirm existing/seed data loads (DoD functional test).

### Definition of Done
- [ ] `swift test` (package) passes incl. new model tests.
- [ ] App builds; `-demo` launches without migration crash.
- [ ] `nil` vs `0` verified distinct in store round-trip.
- [ ] No new warnings; Swift 6 strict-concurrency clean.

- [ ] **CHECKPOINT: Run `/compact focus on: Phase 1 complete — Entry/EntryRecord/ParsedFood now carry fiber(g)/sodium(mg)/sugar(g)/nutritionConfidence + HK sync metadata; NutritionConfidence + HealthKitSyncStatus enums added; migration verified. Phase 2 needs CSV columns, Phase 3 needs parser capture, Phase 5 needs MacroTotals aggregates.`**

```
PHASE 1 COMPLETE — Conventional Commit:
feat(ios): fiber/sodium/sugar + nutrition confidence + HealthKit sync metadata on entries

Add optional fiber(g)/sodium(mg)/sugar(g), a NutritionConfidence enum, and
HealthKit sync state to Entry/EntryRecord/ParsedFood. nil=unknown, 0=known zero.
Additive optional SwiftData migration; existing data loads unchanged.
```

---

## Phase 2 — CSV export/import

**Goal:** Per-entry CSV gains `fiber,sodium,sugar` columns before `method`; old CSVs (without them) still import; blanks → nil; idempotent; legacy daily-totals import still works.

New header:
```
date,time,food,quantity,unit,calories,fat,carbs,protein,fiber,sodium,sugar,method
```

### Tasks (TDD)
- [ ] **2.1** `AppCore/CSVExporter.swift`: update `entryHeader` and `entriesCSV` row builder to emit fiber/sugar in g (1 decimal) and sodium in mg (integer), writing **empty string for nil** (use a `optionalNumber(_ Double?) -> String` that returns "" for nil). Offset rows keep the same column count (empty nutrient cells). Test: an entry with fiber=3,sodium=850,sugar=nil → row has `...,3.0,850,,text`; nil fiber → empty cell.
- [ ] **2.2** `AppCore/CSVImporter.swift`: detect the per-entry format by header prefix `date,time,food` (unchanged); **map columns by header name**, not fixed index, so a 10-column old file (no fiber/sodium/sugar) and a 13-column new file both parse. Missing/blank cells → `nil` (not 0). Sodium parsed as mg. Keep deterministic ids → idempotent. Legacy daily-totals branch unchanged. Tests: (a) old 10-col CSV imports with fiber/sodium nil; (b) new 13-col CSV restores fiber/sodium/sugar; (c) blank fiber cell → nil; (d) round-trip `entriesCSV → parse` preserves a comma-named food + fiber/sodium; (e) re-import idempotent.
- [ ] **2.3** `CSVField` helpers unchanged (quoting). Confirm header-indexed parse tolerates quoted commas.

### Definition of Done
- [ ] Package tests pass (old import, new import/export, blank→nil, sodium mg, idempotent).
- [ ] Demo export still looks clean (manually inspect a `-demo` export or unit-assert).
- [ ] No regressions in existing CSV tests.

- [ ] **CHECKPOINT: Run `/compact focus on: Phase 2 complete — CSV header now date,time,food,...,protein,fiber,sodium,sugar,method; header-name-indexed import keeps old files working; blanks→nil; sodium mg. Independent of remaining phases.`**

```
PHASE 2 COMPLETE — feat(ios): CSV export/import carries fiber/sodium/sugar, backward-compatible
```

---

## Phase 3 — Capture fiber/sodium/sugar from existing logging methods

**Goal:** Populate the new fields from each source without new logging flows. AI estimates are rounded (no fake precision) and tagged `.estimated`; OFF tagged `.barcode`; label tagged `.label`.

### Tasks (TDD)
- [ ] **3.1 OpenFoodFacts** `NutritionAPI/OpenFoodFactsResolver.swift`. Extend the private `Nutriments` struct + `CodingKeys` + lenient decode with: `fiber100g/"fiber_100g"`, `fiberServing/"fiber_serving"`, `sugars100g/"sugars_100g"`, `sugarsServing/"sugars_serving"`, `sodium100g/"sodium_100g"`, `sodiumServing/"sodium_serving"`, `salt100g/"salt_100g"`, `saltServing/"salt_serving"`. In both `resolve()` returns set:
  - `fiber = perServing(fiberServing, fiber100g, servingGrams)`
  - `sugar = perServing(sugarsServing, sugars100g, servingGrams)`
  - `sodium = sodiumMg(...)` where sodium grams×1000; **if sodium nil and salt present**, `salt_g/2.5*1000`. Add helper `sodiumMilligrams(...)`.
  - `nutritionConfidence = .barcode`.
  Tests (`NutritionAPITests`, decode fixtures): (a) product with `sodium_serving` g → sodium mg = g×1000; (b) product with only `salt_100g` → sodium via /2.5; (c) fiber/sugar mapped; (d) absent → nil.
- [ ] **3.2 Label OCR** `NutritionAI/NutritionLabelParser.swift`. Add regex chains for fiber (`dietary fiber`/`fiber`), sodium (`sodium`, captured as mg), sugar (`total sugars`/`sugars`). Round fiber to nearest 1g, sodium to nearest 1mg (display normal). Set `nutritionConfidence = .label`. Tests: OCR line fixtures → fiber/sodium/sugar extracted; missing lines → nil; "Sodium 850mg" → 850.
- [ ] **3.3 AI parsing** `NutritionAI/NutritionInfo.swift`: add `@Guide` props `fiber`(range 0...100), `sodium`(0...10000, mg), `sugar`(0...500); update init. `toParsedFood()`: **round estimates** — `fiber→round to 1g`, `sodium→round to nearest 50mg`, `sugar→round to 1g`; set `nutritionConfidence = .estimated`; allow nil when the model returns 0-with-low-confidence is **not** inferred (keep simple: pass through rounded values, may be 0). `Prompts.foodInstructions`: add a short rule block: "Include dietary fiber (g), sodium (mg), and total sugars (g) when you can estimate them for the serving; round fiber to whole grams and sodium to the nearest 50 mg; it's fine to omit them if unsure." Heuristic parser (`HeuristicFoodParser`): extend `Portion` with `fiber/sodium/sugar` optional and leave nil for the generic fallbacks (don't fabricate); set `.estimated`. Tests (`NutritionAITests`): `NutritionInfo(fiber:3.27,sodium:873,...).toParsedFood()` → fiber 3, sodium 850 (nearest 50), confidence .estimated.
- [ ] **3.4** `FoundationModelsFoodParser`/`VisionLabelReader`/`CompositeBarcodeResolver` need **no change** (generic pass-through) — add a test asserting a stub barcode resolver returning fiber/sodium flows through the composite unchanged.

### Definition of Done
- [ ] Package tests pass (OFF mapping incl. salt→sodium, label regex, AI rounding + confidence).
- [ ] No fake precision: AI sodium is multiples of 50, fiber whole grams.
- [ ] Existing parser tests still pass.

- [ ] **CHECKPOINT: Run `/compact focus on: Phase 3 complete — OFF maps fiber/sugar(g)+sodium(mg, salt/2.5 fallback) tagged .barcode; label parser extracts fiber/sodium/sugar tagged .label; NutritionInfo rounds AI estimates (fiber 1g, sodium 50mg) tagged .estimated. Phase 4 surfaces these for manual edit.`**

```
PHASE 3 COMPLETE — feat(ios): capture fiber/sodium/sugar from barcode, label OCR, and AI parsing
```

---

## Phase 4 — Manual edit + confirm "Advanced Nutrition" UI

**Goal:** A quiet, visually-subordinate "Advanced Nutrition" section (Fiber/Sodium/Sugar) in both the edit and confirm forms. Editing sets `nutritionConfidence = .userEdited`.

### Tasks (TDD)
- [ ] **4.1** `AppCore/FoodConfirmModel.swift`: add editable `fiberText/sodiumText/sugarText` (String, seeded from the parsed values; empty when nil), computed `fiber/sodium/sugar: Double?` (nil when blank, scaled like macros by amount), and include them in `makeEntry()`; set `nutritionConfidence = .userEdited` only if the user changed a value, else keep the parser's. Tests (`AppCoreTests`): seeded from ParsedFood; blank → nil entry; edited value persists; scaling applies.
- [ ] **4.2** `CalorieCounter/Input/FoodConfirmView.swift`: after the "Nutrition (recalculated)" section, add a `Section("Advanced Nutrition")` with three `TextField`s (decimal/number pad) for Fiber (g), Sodium (mg), Sugar (g), styled `.font(.subheadline)`/secondary, with a footer "Optional — leave blank if unknown."
- [ ] **4.3** `CalorieCounter/Input/EditEntryView.swift`: same secondary section bound to local `@State` seeded from the `Entry`; on save, set the optional fields and `nutritionConfidence = .userEdited` when changed. Keep the existing macro section primary.
- [ ] **4.4** Reuse the keyboard "Done" affordance pattern already in Settings (a `safeAreaInset` floating glass pill) if these number pads need dismissal, OR rely on the sheet's existing Save/Cancel.

### Definition of Done
- [ ] Package tests for FoodConfirmModel pass.
- [ ] App builds; manually: edit a food, set fiber/sodium, save, reopen — values persist; blank stays blank.
- [ ] Today screen visual hierarchy unchanged (advanced fields are clearly secondary).

- [ ] **CHECKPOINT: Run `/compact focus on: Phase 4 complete — FoodConfirmModel + EditEntryView/FoodConfirmView have a secondary Advanced Nutrition section (fiber/sodium/sugar), editing sets .userEdited, blanks stay nil. Phase 5 builds the Today Nutrition Signals card from these values.`**

```
PHASE 4 COMPLETE — feat(ios): edit fiber/sodium/sugar in a quiet Advanced Nutrition section
```

---

## Phase 5 — `MacroTotals` aggregates + Today "Nutrition Signals" card

**Goal:** Nil-aware daily aggregates and a small, quiet, collapsible "Nutrition Signals" card below the rings. No rings. Hidden/quiet when no data. Context language, never warnings.

### Tasks (TDD)
- [ ] **5.1** `NutritionCore/MacroTotals.swift`: add `fiber/sodium/sugar: Double?` (nil = no contributing entry). Update `adding(_:)` with `combine(_ a: Double?, _ b: Double?) -> Double?` (nil+nil=nil, a+nil=a, nil+b=b, a+b=a+b). Add `entriesWithFiber`/coverage? Keep simple: also expose a pure helper `NutritionSignals.from(entries:)` that returns known totals + counts (total entries, entries-with-fiber, entries-with-sodium) so the card can express partial coverage. Tests: summing mixed nil/known → known sum; all-nil → nil; `+` operator updated.
- [ ] **5.2** `AppCore/NutritionSignals.swift (CREATE)`: a pure value type computing `fiberGrams: Double?`, `sodiumMg: Double?`, `sugarGrams: Double?`, `coverage` (how many entries had data), and **non-medical copy** given a fiber soft-target and a 7-day personal sodium baseline. Functions:
  - `fiberMessage(target: Double?) -> String?` ("Nice fiber day — you're at 28g so far." / "Fiber is a little lower than usual today.")
  - `sodiumMessage(baselineMg: Double?, enabled: Bool) -> String?` ("Sodium is higher than usual today — tomorrow's weight may tick up from water." / nil when off or no baseline). Never "too high"/"bad".
  Tests: deterministic copy selection by thresholds; nil when no data; sodium message nil when disabled.
- [ ] **5.3** `AppCore/TodayModel.swift`: expose `signals: NutritionSignals` computed in `load()` from `entries` (+ inject a sodium baseline from recent days if cheap; else compute in the view from HistoryModel later — keep v1 baseline = settings/Auto). 
- [ ] **5.4** `CalorieCounter/Today/NutritionSignalsCard.swift (CREATE)`: a `SoftCard` with a collapsed one-liner (DisclosureGroup) → expanded `Fiber: 17g · Sodium: 2,640mg · Sugar: 58g` (sugar only if present). Quiet empty state when no entries have data ("Fiber and sodium appear here as you log foods with that info."). Insert in `TodayView.dashboard` as a new `Section` **after** the food list (so rings stay primary), `.clearRow()`.
- [ ] **5.5** Respect Settings: hide the card's sodium line when sodium reference = Off (Phase 6 provides the flag; until then default Auto/on).

### Definition of Done
- [ ] Package tests: MacroTotals nil-aware aggregation; NutritionSignals copy logic.
- [ ] App builds; `-demo` shows a tasteful card; an empty day shows the quiet empty state.
- [ ] No new rings; rings remain the primary interface; card is visually secondary.

- [ ] **CHECKPOINT: Run `/compact focus on: Phase 5 complete — MacroTotals has nil-aware fiber/sodium/sugar aggregates; NutritionSignals pure helper generates non-medical copy; Today shows a quiet collapsible Nutrition Signals card below the food list. Phase 6 adds fiber target + sodium reference settings the card reads.`**

```
PHASE 5 COMPLETE — feat(ios): nil-aware nutrient totals + quiet Today Nutrition Signals card
```

---

## Phase 6 — Settings: Nutrition Signals (fiber target / sodium reference)

**Goal:** A small, non-clinical Settings section. Fiber target Auto/Custom; sodium reference Auto/Custom/Off. Defaults: fiber Auto (28g imperial / 30g metric); sodium Auto.

### Tasks (TDD)
- [ ] **6.1** `NutritionCore`: `FiberTargetMode { auto, custom }`, `SodiumReferenceMode { auto, custom, off }` enums (Codable). Add `Constants.defaultFiberTarget(units:) -> Double` (28 imperial / 30 metric). Sodium "reference" default baseline (e.g., 2300mg) but framed as reference, computed from personal 7-day average when available.
- [ ] **6.2** `AppCore/SettingsStore.swift`: add persisted `fiberTargetMode`, `customFiberTarget: Double`, `sodiumReferenceMode`, `customSodiumReference: Double` with `didSet` persistence + `Keys`. Add computed `effectiveFiberTarget(units:)` and `sodiumSignalEnabled`. Tests (`SettingsStoreTests`): defaults (fiber .auto, sodium .auto); persistence across instances; effectiveFiberTarget switches with units.
- [ ] **6.3** `CalorieCounter/Settings/SettingsView.swift`: new `Section("Nutrition Signals")` (placed after Daily Targets) — a fiber row (Picker Auto/Custom; when Custom, a number field reusing the existing tidy `targetField` chip + the floating Done pill) and a sodium row (Picker Auto/Custom/Off). Footer: "Used to add gentle context — not medical guidance." Wire the Today card + History to read these.

### Definition of Done
- [ ] Package tests: settings persistence + effective target.
- [ ] App builds; toggles persist; turning sodium Off hides the sodium signal on Today.
- [ ] Section reads non-clinical.

- [ ] **CHECKPOINT: Run `/compact focus on: Phase 6 complete — SettingsStore persists fiberTargetMode/customFiberTarget/sodiumReferenceMode/customSodiumReference; Settings has a non-clinical Nutrition Signals section; Today card honors them. Phase 7 adds fiber/sodium History trends using the fiber target.`**

```
PHASE 6 COMPLETE — feat(ios): Nutrition Signals settings (fiber target, sodium reference)
```

---

## Phase 7 — History fiber/sodium secondary trends

**Goal:** View fiber (g) and sodium (mg) trends without elevating them to macro status. Missing-data days are **gaps**, not zero bars.

### Tasks (TDD)
- [ ] **7.1** `AppCore/HistoryModel.swift`: extend `MacroKind` with `.fiber` (unit "g") and `.sodium` (unit "mg"); `value(in:)` returns 0 for safety but add `optionalValue(in:) -> Double?` returning `totals.fiber`/`totals.sodium` (nil for unknown days). `target(in:)` returns the fiber target for `.fiber`, and the sodium reference (or 0/none) for `.sodium`. Add a `signalSeries(_ kind:) -> [MacroSeriesPoint]` that **omits nil days** (gaps) — for fiber/sodium. Tests: a 7-day window with fiber on 3 days → series has 3 points (gaps elsewhere), not 7 zero bars; sodium axis uses mg.
- [ ] **7.2** `CalorieCounter/History/HistoryView.swift`: keep the 4-macro `.segmented` Picker primary. Add a quieter trailing **`Menu("More Signals")`** offering Fiber / Sodium; selecting one sets the active kind (and visually deselects the segmented control, e.g. via a separate `@State selectedKind`). When a signal is active, the chart uses `signalSeries` + the right unit; a small caption notes "shown for days with data."
- [ ] **7.3** `NutritionChart`: already unit-parameterized; ensure it renders sparse/gappy point sets cleanly (it plots provided points on a date scale — gaps are automatic). Add a quiet empty overlay "No fiber logged in this range yet."

### Definition of Done
- [ ] Package tests: signal series omits nil days; units g vs mg.
- [ ] App builds; `-demo` → Fiber/Sodium trends render with gaps, macros remain primary.
- [ ] No full-screen micronutrient dashboard; main history still emphasizes calories/macros/weight.

- [ ] **CHECKPOINT: Run `/compact focus on: Phase 7 complete — MacroKind has .fiber(g)/.sodium(mg) via a quiet More-Signals menu; signalSeries omits nil days (no misleading zero bars). Phase 8 adds the weekly insights card.`**

```
PHASE 7 COMPLETE — feat(ios): fiber/sodium History trends as a quiet secondary selector
```

---

## Phase 8 — Weekly insights

**Goal:** 2–4 deterministic, non-medical, local insights. Shown only for 7/30-day ranges with enough data. Sodium/weight correlation only when both exist.

### Tasks (TDD)
- [ ] **8.1** `AppCore/WeeklyInsights.swift (CREATE)`: pure `static func generate(days: [DayTotals], weights: [WeightPoint], targets: MacroTargets, fiberTarget: Double, sodiumEnabled: Bool) -> [String]`. Rules: protein-target hit count ("You hit your protein target 5 of 7 days."); avg calories; avg fiber (only if ≥N days have fiber); the **sodium→weight** correlation ("Your biggest weight jump followed a higher-sodium day. That may be temporary water weight.") only when a high-sodium day is immediately followed by a weight uptick AND both data exist. Cap at 4; return [] when insufficient data. Non-medical phrasing only.
- [ ] **8.2** Tests (`AppCoreTests/WeeklyInsightsTests.swift`): protein-days insight count; avg-calorie text; correlation appears only with both sodium+weight and a real jump; empty array with sparse data; never emits "too high"/"failed".
- [ ] **8.3** `CalorieCounter/History/WeeklyInsightsCard.swift (CREATE)`: a `SoftCard` listing the insight strings; render in `HistoryView` **only** when range is `.week`/`.month` and `insights` non-empty. `HistoryModel` exposes `insights` computed from loaded days + weight points.

### Definition of Done
- [ ] Package tests: insight rules incl. correlation gating.
- [ ] App builds; `-demo` (with the Phase 14 patterns) shows the sodium/weight insight.
- [ ] Card hidden when not enough data / on 90/All ranges.

- [ ] **CHECKPOINT: Run `/compact focus on: Phase 8 complete — WeeklyInsights pure generator + card on History (7/30-day ranges); sodium/weight correlation gated on both data present. Phases 9-12 add Apple Health.`**

```
PHASE 8 COMPLETE — feat(ios): lightweight local weekly insights card
```

---

## Phase 9 — Apple Health architecture (seam + module + mock + wiring)

**Goal:** HealthKit behind a `HealthSyncing` seam in a new `NutritionHealth` target; a mock for tests/previews; `AppContainer` wires it; entitlement + Info.plist + capability in place. App fully usable without Health permission.

### Tasks (TDD)
- [ ] **9.1** `NutritionCore/HealthSyncing.swift (CREATE)`: the seam + value types:
  ```swift
  public struct HealthAuthorizationSummary: Sendable, Equatable {
      public var nutritionWriteAuthorized: Bool
      public var weightReadWriteAuthorized: Bool
      public var isAvailable: Bool
  }
  public struct WeightConflict: Sendable, Equatable, Identifiable {
      public let date: String; public let localKg: Double; public let healthKg: Double
      public var id: String { date }
  }
  public protocol HealthSyncing: Sendable {
      func isAvailable() -> Bool
      func requestNutritionWriteAccess() async throws
      func requestWeightReadWriteAccess() async throws
      func syncFoodEntry(_ entry: Entry) async throws
      func deleteSyncedFoodEntry(id: String) async throws
      func syncWeightEntry(_ entry: WeightEntry) async throws
      func importWeights(daysBack: Int) async throws -> [WeightEntry]
      func removeAllAppData() async throws
      func authorizationSummary() async -> HealthAuthorizationSummary
  }
  ```
- [ ] **9.2** `NutritionHealth` target: add to `Package.swift` (`.target(name:"NutritionHealth", dependencies:["NutritionCore"], swiftSettings:[.swiftLanguageMode(.v6)], linkerSettings:[.linkedFramework("HealthKit")])` + `NutritionHealthTests`). Make `AppCore` depend on `NutritionHealth`. Create `NutritionHealth/AppleHealthKitService.swift` with the full `HealthSyncing` impl skeleton (methods present; nutrition write in Phase 10, weight in Phase 11). Guard everything on `HKHealthStore.isHealthDataAvailable()`.
- [ ] **9.3** `AppCore/MockHealthSyncService.swift (CREATE)`: in-memory no-op recording calls (for previews + tests): tracks synced ids, stored weights, `removeAllAppData` clears; `isAvailable()` configurable.
- [ ] **9.4** `AppCore/AppContainer.swift`: add `public let healthSync: any HealthSyncing` seam (designated init param + wire `AppleHealthKitService()` in `convenience init()`, `MockHealthSyncService()` when `isUITest`/`isDemo`). Update `AppContainerTests` stub container to pass a `MockHealthSyncService`.
- [ ] **9.5** App config: add `<key>com.apple.developer.healthkit</key><true/>` to `CalorieCounter/CalorieCounter.entitlements`; add `NSHealthShareUsageDescription` + `NSHealthUpdateUsageDescription` to `CalorieCounter/Info.plist`. Run `cd apple && xcodegen generate`.
- [ ] **9.6** Tests (`NutritionHealthTests` + `AppCoreTests`): `MockHealthSyncService` records sync/delete; AppContainer exposes `healthSync`; app builds with HealthKit linked; `isAvailable()` false path doesn't throw on init.

### Definition of Done
- [ ] Package tests pass (mock + container wiring).
- [ ] App builds & links HealthKit; launches without requesting Health (lazy).
- [ ] Works with Health unavailable (guard returns/throws cleanly).

- [ ] **CHECKPOINT: Run `/compact focus on: Phase 9 complete — HealthSyncing seam in NutritionCore; NutritionHealth target with AppleHealthKitService skeleton (HealthKit-linked); MockHealthSyncService in AppCore; AppContainer.healthSync wired; entitlement + Info.plist + xcodegen done. Phase 10 implements nutrition write, Phase 11 weight.`**

```
PHASE 9 COMPLETE — feat(ios): HealthKit seam + NutritionHealth module + entitlement/Info.plist
```

---

## Phase 10 — Apple Health nutrition write

**Goal:** Write each food entry as an `HKCorrelation(.food)` of nutrient samples with our metadata; edit = delete-by-metadata + recreate; delete = delete-by-metadata. Failures non-fatal; sync state stored.

### Tasks (TDD)
- [ ] **10.1** `AppleHealthKitService.syncFoodEntry`: request authorization (idempotent), build `HKQuantitySample`s for non-nil energy(kcal)/protein/carbs/fat/fiber/sugar(g) + sodium(**g** = mg/1000), group into `HKCorrelation(type: .food, metadata: [CalorieCounterFoodEntryID, CalorieCounterAppVersion, HKMetadataKeyFoodType])`, **delete existing by metadata predicate first** (so re-sync/edit can't duplicate), then save. Use exact identifiers: `dietaryEnergyConsumed, dietaryProtein, dietaryCarbohydrates, dietaryFatTotal, dietaryFiber, dietarySodium, dietarySugar`.
- [ ] **10.2** `deleteSyncedFoodEntry(id:)`: `HKSampleQuery`/`deleteObjects(of:predicate:)` with `HKQuery.predicateForObjects(withMetadataKey:operatorType:value:)` on `CalorieCounterFoodEntryID == id`, for each nutrient type + the correlation. Never delete other-app data (our metadata key scopes it).
- [ ] **10.3** Wire triggers (app side, gated on `settings.healthNutritionSyncEnabled` from Phase 12): after `store.add`/`update` in `FoodConfirmModel`/`EditEntryView`/Today edit → `try? await healthSync.syncFoodEntry(entry)` and persist `healthKitSyncedAt`/status; after delete → `deleteSyncedFoodEntry`. Failures set `.failed` + `healthKitLastError`, never block local save.
- [ ] **10.4** Tests via mock semantics (`NutritionHealthTests` with a test seam over a fake store of samples, or assert against `MockHealthSyncService` call log at the AppCore layer): sync new food records a correlation; editing the same id deletes then recreates (no dup); deleting removes matching; permission-denied path throws but local logging unaffected (AppCore test: `store.add` still succeeds when `healthSync.syncFoodEntry` throws).

### Definition of Done
- [ ] AppCore tests: local logging unaffected by sync errors; edit doesn't duplicate (mock call log).
- [ ] App builds; on a device with Health, manual smoke: log → appears in Health; edit → no dup; delete → removed.
- [ ] Sync status surfaced (quiet) and failures non-fatal.

- [ ] **CHECKPOINT: Run `/compact focus on: Phase 10 complete — AppleHealthKitService writes HKCorrelation(.food) with CalorieCounterFoodEntryID metadata; edit/delete via metadata-query delete; app triggers gated on settings, non-fatal. Phase 11 adds weight read/write with prompt-on-conflict.`**

```
PHASE 10 COMPLETE — feat(ios): write nutrition to Apple Health (correlation + metadata edit/delete)
```

---

## Phase 11 — Apple Health weight read/write (prompt-on-conflict)

**Goal:** Write body mass on weigh-in; import body mass with **prompt-on-conflict** for same-day differences; avoid duplicates; preserve sparse, one-per-day weight model.

### Tasks (TDD)
- [ ] **11.1** `AppleHealthKitService.syncWeightEntry`: write `HKQuantitySample(.bodyMass, kg)` with `CalorieCounterFoodEntryID`-style metadata (`CalorieCounterWeightDate = entry.date`) for de-dup; delete-by-metadata then save (re-log updates).
- [ ] **11.2** `importWeights(daysBack:)`: query `bodyMass` over the window, reduce to **one per local day** (newest sample that day), return `[WeightEntry]` (kg). Caller resolves conflicts.
- [ ] **11.3** Import flow (AppCore, e.g. `WeightImportCoordinator` or in a model): compare each Health day to local; **non-conflicting days added silently**; days where local exists AND differs beyond a small epsilon → collect `WeightConflict`s and surface a sheet. Apply user's per-day choice (Use Health updates local + re-syncs; Keep current leaves local). Tests (`AppCoreTests`): days with no local imported; equal days skipped; differing days produce a `WeightConflict`; applying "use health" updates the store; "keep" leaves it.
- [ ] **11.4** `CalorieCounter/History/WeightConflictSheet.swift (CREATE)`: lists conflicts with `Jun 23 — Health 81.2 / Local 81.5` and per-row `[Use Apple Health] [Keep current]` (or a single choice applied to all). Trigger from the "Import weight from Apple Health" action (Phase 12). Wire weight logging (`LogWeightSheet.save`) to also `try? await healthSync.syncWeightEntry` when enabled.

### Definition of Done
- [ ] AppCore tests: import dedup + conflict detection + apply choices.
- [ ] App builds; on device: app weigh-in appears in Health; Health/smart-scale weights import; same-day conflict prompts.
- [ ] Weight graph stays sparse + date-accurate.

- [ ] **CHECKPOINT: Run `/compact focus on: Phase 11 complete — bodyMass write on weigh-in (dedup by date metadata); importWeights one-per-day; prompt-on-conflict sheet + apply logic. Phase 12 builds the Apple Health settings that drive all sync + repair/disconnect/remove.`**

```
PHASE 11 COMPLETE — feat(ios): Apple Health weight write + import with prompt-on-conflict
```

---

## Phase 12 — Apple Health Settings UI

**Goal:** A clear "Apple Health" Settings section controlling sync, with repair, disconnect (stops sync, keeps data), and the destructive remove-app-data action.

### Tasks (TDD)
- [ ] **12.1** `SettingsStore`: persist `healthNutritionSyncEnabled`, `healthWeightSyncEnabled`, `healthWeightImportEnabled`, `healthLastSyncAt: Date?`. Tests: defaults off; persistence.
- [ ] **12.2** `CalorieCounter/Settings/AppleHealthSection.swift (CREATE)` (or inline in SettingsView): `Section("Apple Health")` with explanatory footer copy ("Save meals, macros, fiber, sodium, and weigh-ins to Apple Health. You choose what to share, and the app keeps working even if you skip this."). Rows:
  - Toggles: Sync nutrition / Sync weight / Import weight from Apple Health (each requests the right authorization on enable; reflect `authorizationSummary()`).
  - "Synced fields" → "Calories, protein, carbs, fat, fiber, sodium".
  - "Last sync" → `healthLastSyncAt`.
  - **Repair Sync** → re-sync entries from the last 30/90 days (iterate, `syncFoodEntry`), update `healthLastSyncAt`.
  - **Disconnect Apple Health** → set all toggles off; **does not** delete Health data.
  - **Remove this app's data from Apple Health** (destructive, confirmationDialog) → `healthSync.removeAllAppData()`.
  - Hide/disable the whole section when `!healthSync.isAvailable()`.
- [ ] **12.3** Tests (`AppCoreTests` with mock): enabling nutrition sync flips the flag + requests access; Repair re-syncs N entries (mock call count); Disconnect leaves mock's stored data intact; Remove clears it.

### Definition of Done
- [ ] Settings persistence + mock-driven behavior tests pass.
- [ ] App builds; section explains sharing clearly; disconnect ≠ delete; remove works and is confirmed.
- [ ] HealthKit-unavailable state hides the section without crashing.

- [ ] **CHECKPOINT: Run `/compact focus on: Phase 12 complete — Apple Health settings section (sync toggles, synced fields, last sync, Repair, Disconnect-keeps-data, Remove-app-data destructive); sync triggers honor the flags. Phase 13 updates privacy/About copy.`**

```
PHASE 12 COMPLETE — feat(ios): Apple Health settings (toggles, repair, disconnect, remove data)
```

---

## Phase 13 — Privacy/About copy + permission strings

**Goal:** About + permission strings reflect the optional Health integration; still accurately local-first.

### Tasks (TDD)
- [ ] **13.1** `CalorieCounter/Settings/AboutView.swift`: add a privacy line — "Apple Health integration is optional. When enabled, the app can save nutrition and weight to Apple Health and import weight entries you already have there. Your food entries, targets, weights, and settings remain stored on this device." Keep existing on-device messaging.
- [ ] **13.2** Confirm Info.plist `NSHealthShareUsageDescription`/`NSHealthUpdateUsageDescription` are clear (added in Phase 9); refine wording. No server/upload claims anywhere.
- [ ] **13.3** Update `apple/FEATURES.md` with an "Apple Health (optional)" section + fiber/sodium notes.
- [ ] **13.4** UI test (optional/light): About renders the new line.

### Definition of Done
- [ ] App builds; About shows the Health line; permission prompts read clearly.
- [ ] No copy implies cloud/sync-to-server.

- [ ] **CHECKPOINT: Run `/compact focus on: Phase 13 complete — About + Info.plist + FEATURES.md describe optional Apple Health; still local-first. Phase 14 enriches demo data with fiber/sodium + a sodium→weight bump.`**

```
PHASE 13 COMPLETE — docs(ios): About/permission/feature copy for optional Apple Health
```

---

## Phase 14 — Demo mode updates

**Goal:** Demo data shows the new features naturally — normal/low fiber days, higher-sodium restaurant days, a temporary weight bump after a high-sodium day, and the explaining insight. No clutter.

### Tasks (TDD)
- [ ] **14.1** `AppCore/AppContainer.swift` `seedDemoData()`: extend the `Meal` catalog rows with realistic `fiber/sodium/sugar` and `nutritionConfidence` (barcode/label for some, estimated for others, a few nil to exercise partial coverage). Designate ~2 "restaurant/takeout" high-sodium days; bump the **next day's** seeded weigh-in slightly to create the sodium→weight pattern WeeklyInsights detects.
- [ ] **14.2** Verify (`AppCoreTests` against the seeded in-memory store, or a dedicated demo test): demo days include fiber/sodium; at least one high-sodium day precedes a weight uptick; `WeeklyInsights.generate` over demo data yields the water-weight insight.
- [ ] **14.3** Manual: `-demo -screen-history` screenshots look clean (Nutrition Signals card, fiber/sodium trend, weekly insight).

### Definition of Done
- [ ] Demo seeding test passes (fiber/sodium present; bump pattern present).
- [ ] App `-demo` shows the features tastefully; not busier, just smarter.

- [ ] **CHECKPOINT: Run `/compact focus on: Phase 14 complete — demo seeds fiber/sodium/sugar, high-sodium days + a following weight bump, and the water-weight insight. Phase 15 is the final test/build/cleanup sweep.`**

```
PHASE 14 COMPLETE — feat(ios): demo mode shows fiber/sodium + sodium→weight insight
```

---

## Phase 15 — Final sweep: tests, build, concurrency/warnings

**Goal:** Everything green end to end; no warnings; Swift 6 strict-concurrency clean; UI regressions fixed.

### Tasks
- [ ] **15.1** Run full package suite: `cd apple/Packages/NutritionKit && swift test` — all green.
- [ ] **15.2** Run full UI suite: `xcodebuild ... -only-testing:CalorieCounterUITests test` (use `clean test` if a new method isn't discovered). Add/confirm UI tests: Today still shows calorie + macro rings primary; Nutrition Signals card appears only when appropriate; Settings toggles persist; HealthKit-unavailable state doesn't crash; weight conflict sheet appears on a seeded conflict.
- [ ] **15.3** Build app for simulator; resolve any warnings/concurrency diagnostics introduced.
- [ ] **15.4** Manual device smoke (user step): Health permission prompt, nutrition write, weight import/conflict, repair, disconnect, remove-data.

### Definition of Done
- [ ] All package + UI tests pass; clean build; zero new warnings.
- [ ] Final acceptance criteria (below) all satisfied.

- [ ] **CHECKPOINT: Run `/compact focus on: Phase 15 complete — full suite green, clean build, feature done. Ready for device QA + App Store HealthKit review notes.`**

```
PHASE 15 COMPLETE — test(ios): full fiber/sodium + Apple Health suite green; cleanup
```

---

## Testing strategy (pyramid)

- **Unit (≈80%, `swift test`):** model fields/migration, CSV header-indexed parse + nil-vs-0, OFF/label/AI mapping + rounding + confidence, MacroTotals nil-aware aggregation, NutritionSignals copy, settings persistence, MacroKind signal series gaps, WeeklyInsights rules, MockHealthSyncService + AppContainer wiring, weight import dedup/conflict, Settings Health flags + repair/remove via mock.
- **Integration (≈15%):** SwiftDataStore on-disk round-trip incl. new fields; CSV export→import round-trip; AppCore sync triggers don't block local save when `healthSync` throws.
- **UI/E2E (≈5%, XCUITest):** Today rings remain primary; Nutrition Signals card visibility; Settings Nutrition-Signals + Apple-Health toggles persist; weight conflict sheet; Health-unavailable no-crash.

HealthKit itself is exercised only through the `HealthSyncing` seam (mock) in automated tests; real HKHealthStore behavior is device-only manual QA.

---

## Final acceptance criteria

- [ ] App stores fiber (g) and sodium (mg) per food entry (sugar too), `nil`≠`0`.
- [ ] Barcode and label OCR populate fiber/sodium when available; AI estimates are rounded and tagged `.estimated`.
- [ ] Users can edit fiber/sodium/sugar in a quiet Advanced Nutrition section.
- [ ] CSV export/import supports the new fields without breaking old files; blanks stay nil.
- [ ] Today has a lightweight, non-medical Nutrition Signals card; **no new rings**; rings remain primary.
- [ ] History shows fiber/sodium as quiet secondary trends (g / mg) with gaps for missing days; macros/weight stay primary.
- [ ] Weekly insights generate locally (incl. the gated sodium→weight insight); non-medical language.
- [ ] Apple Health receives nutrition + weight from the app; weight imports from Health; edits/deletes don't duplicate Health data (metadata-query).
- [ ] Weight conflicts prompt the user; remove-from-Health and disconnect are distinct.
- [ ] The app works perfectly with Health permission denied/unavailable; sync failures are non-fatal.
- [ ] Local-first, no-account, privacy-forward positioning preserved; no server/upload claims.
- [ ] UI still feels like "everything you need and nothing you don't."
