# Plan 003 — Local Food Database + Compound-Food Reasoning

> **For Claude:** Execute this plan using `/superbuild` skill.
> Run from repo root `/Users/marcovhv/projects/GIT/caloriecounter`. The iOS app lives under `apple/`.
> Build/test commands (run from `apple/`):
> - Package tests (fast, macOS): `cd apple/Packages/NutritionKit && swift test`
> - App build: `cd apple && xcodebuild -project CalorieCounter.xcodeproj -scheme CalorieCounter -destination 'platform=iOS Simulator,id=409B0B01-EAA4-4969-AF8F-F97EF3C31ADD' build`
> - UI tests: add `-only-testing:CalorieCounterUITests/<Suite>` and `test`. **If a newly added test method isn't discovered, run with `clean test` once** (known incremental-build quirk).
> - After adding NEW files to the app target **or a new package target**: `cd apple && xcodegen generate`.
> - Data pipeline: `python3 apple/scripts/build_food_db.py` (regenerates the bundled slim DB from the raw USDA dumps).

---

## Goal

Make "type or say any food and get accurate nutrition" work **on-device**, as well as or better than the original cloud-LLM did — including compound descriptions like *"a BLT made with white bread"*.

The insight that shapes everything: **USDA already did the hard work.** The bundled datasets contain ~13,500 foods including thousands of *composite, prepared dishes* (FNDDS) — "Bacon, lettuce, tomato sandwich on white" is a literal database row with measured nutrition (231 kcal/100 g), a default portion ("1 sandwich = 105 g"), **and** its gram-weighted recipe (bacon 16 g, white bread 60 g, tomato 20 g, lettuce 8 g). So most "describe a food" requests become a *retrieval* problem against real data — faster, more accurate, and fully offline — and the local model is reserved for (a) matching intent and (b) decomposing the genuine long tail not already in the DB.

> The local model's job is to **itemize and portion**, never to do the nutrition math. Numbers come from the database; sums are computed in code.

## Product Principle (non-negotiable)

> **Calories and macros are the interface. The breakdown is power, not clutter.**

Preserve the simple Today screen. The component breakdown lives only in the **confirm/edit sheet**, collapsed by default ("BLT · 5 items · 243 kcal") with a tap to expand and adjust. The app remains local-first, no-account, privacy-forward, on-device-first. After save, an entry is a normal flat-total entry like today — no schema change to persisted data.

## Decisions locked in (from interview)

1. **Long-tail path → build both, DB first.** Phase 1–4 ship the database engine (the ~90% win). Phase 5 adds the Foundation Models decompose→ground→sum fallback for foods not in the DB. The fallback is a clean add-on that does not disturb the DB path.
2. **Breakdown UX → show, editable, collapsed by default.** FNDDS supplies the gram-weighted recipe for free; the same component UI renders both a known recipe and the AI's itemization. Per-line edit/remove, live total recalc.
3. **Bundle all three datasets**, deduped and slimmed (target a few MB). Prefer FNDDS rows for dish-style queries; SR Legacy / Foundation for raw ingredients.
4. **Components are transient (parse/confirm-time), not persisted as structured data.** On save we flatten to totals (+ an optional human-readable component summary in `notes`). No `Entry` schema migration.

## Units (canonical — consistent with Plan 002)

- Energy **kcal**; fiber/sugar **grams**; sodium **milligrams** everywhere in app/model.
- **USDA sodium (id 1093) is already milligrams** in these dumps (e.g. anchovies 5400 mg/100 g) — so, unlike OpenFoodFacts (grams → ×1000), **no conversion** is applied to DB sodium. Encode this carefully in the pipeline and assert it in tests.
- `nil` = unknown, `0` = known zero. Never coerce unknown → zero.
- Per-100 g densities in the DB; absolute macros = density × chosen grams, computed at match time.

---

## Source data (already in `apple/`, git-ignored)

| File | Top key | Foods | Energy (1008 kcal) | Portions | Recipe (`inputFoods`) | Role |
|------|---------|-------|--------------------|----------|-----------------------|------|
| `FNDDS.json` (63 MB) | `SurveyFoods` | 5,432 | 100% | 100% | ✅ gram-weighted | **Composite/prepared dishes** |
| `legacyfoods.json` (201 MB) | `SRLegacyFoods` | 7,793 | 100% | 7,533 | partial | Raw + branded ingredients |
| `USDA.json` (6.4 MB) | `FoundationFoods` | 321 (slimmed) | mixed¹ | some | — | Generic whole foods (already bundled) |

¹ Foundation energy falls back 1008 → 2048 → 2047 (existing logic in `build-usda-foods.py`).

Relevant USDA nutrient ids (per 100 g): energy `1008`, protein `1003`, fat `1004`, carbs `1005`, fiber `1079`, sodium `1093` (mg), sugars `2000`/`1063`. Portions live in `foodPortions[]` (`portionDescription`/`modifier` + `gramWeight`). FNDDS recipe lives in `inputFoods[]` (`ingredientDescription` + `ingredientWeight` grams).

---

## Architecture

### Layer graph (unchanged modules; NutritionAI gains the database)

```
                         ┌───────────────┐
        ┌───────────────▶│ NutritionCore │◀──────────────┐
        │                └───────────────┘               │
┌───────────────┐ ┌───────────────┐ ┌──────────────────────────┐ ┌────────────────┐
│ NutritionStore│ │ NutritionAPI  │ │       NutritionAI        │ │ NutritionHealth│
└───────────────┘ └───────────────┘ │  FoodDatabase (NEW)      │ └────────────────┘
        ▲                ▲          │  DatabaseFoodParser (NEW)│         ▲
        │                │          │  ComposedFood FM (Ph.5)  │         │
        │                │          └──────────────────────────┘         │
        └────────────────┴───────────────┬──────────────────────────────┘
                                   ┌──────────────┐
                                   │   AppCore    │  CompositeFoodParser wiring
                                   └──────────────┘
                                          ▲
                                   ┌──────────────┐
                                   │ CalorieCounter│  breakdown UI in confirm sheet
                                   └──────────────┘
```

- **NutritionCore:** `ParsedFood` gains transient `components: [FoodComponent]?`; new `FoodComponent` value type. No persisted-model change.
- **NutritionAI:** new `FoodDatabase` (loads the slim bundled DB, portion-aware fuzzy match, returns matches that produce a `ParsedFood` with portion + recipe). `USDAFoodIndex`'s reference-grounding role is folded into / backed by `FoodDatabase`. New `DatabaseFoodParser: FoodParsing`. Phase 5 adds `ComposedFood` (`@Generable`) + the decomposition resolver.
- **AppCore:** `CompositeFoodParser: FoodParsing` (DB → FM fallback) becomes `AppContainer.foodParser`. `FoodConfirmModel` gains editable components.
- **App target:** collapsed/expandable, editable component list in `FoodConfirmView` / `EditEntryView`. DB matches surfaced as tappable suggestions in `TextInputView` (alongside the OFF "Product matches").

### Resolution order for the type/voice "Analyze" action

```
1. OpenFoodFacts (branded)          ── already built (FoodSearching, shown as suggestions)
2. FoodDatabase direct match        ── NEW (Phase 3): dish or ingredient row + portion + recipe
3. FM decompose → ground → sum      ── NEW (Phase 5): novel combos not in the DB
4. FM single-food estimate          ── existing, now USDA/DB-grounded (fallback of fallback)
```

As the user types, **suggestions** (instant, tappable) come from OFF + FoodDatabase. The **Analyze** button runs the pipeline above.

---

## Phase Overview

| Phase | Name | Depends On | Est. | Status |
|-------|------|------------|------|--------|
| 1 | Data pipeline → slim bundled DB | — | 5 | ✅ |
| 2 | FoodDatabase index + portion-aware matching | 1 | 8 | ✅ |
| 3 | Database/Composite parsers + type-flow wiring | 2 | 8 | ✅ |
| 4 | Editable breakdown UI (confirm/edit sheet) | 3 | 5 | ⬜ |
| 5 | FM decomposition fallback (`ComposedFood`) | 3 | 8 | ⬜ |
| 6 | Demo data, performance/size validation, docs | 4,5 | 3 | ⬜ |

Total: 37 points. Phases are sequential (each builds on the prior); 5 may be developed in parallel with 4 since both depend only on 3.

---

## Phase 1 — Data pipeline → slim bundled DB

**Goal:** Preprocess the three raw dumps (270 MB) into one slim, bundled `FoodDB.json` (target a few MB) carrying name, type, 7 nutrients per 100 g, portions, and FNDDS recipes. Reproducible script; raw dumps git-ignored.

### Slim schema (compact keys, one row per food)

```json
{ "n": "Bacon, lettuce, tomato sandwich on white",
  "t": "dish",                      // "dish" (FNDDS) | "food" (SR Legacy / Foundation)
  "k": 231, "p": 9.4, "f": 11.6, "c": 23.1,
  "fi": 1.6, "so": 466, "su": 3.0,  // optional; omitted when USDA doesn't report
  "ps": [["1 sandwich, any size", 105], ["serving", 105]],   // portions: [label, grams]
  "r": [["Pork bacon, cooked", 16], ["Bread, white", 60], ["Tomatoes", 20], ["Lettuce", 8]] }  // recipe (FNDDS only)
```

### Tasks
- [x] Task 1.1: Create `apple/scripts/build_food_db.py` — read all three dumps, extract per-100 g `k/p/f/c/fi?/so?/su?` (energy chain 1008→2048→2047; **sodium kept mg, no conversion**), the best 1–3 portions (skip "Quantity not specified"; keep "1 sandwich"/"serving"/etc. with `gramWeight`), and FNDDS `inputFoods` → `r` (ingredientDescription trimmed, ingredientWeight g). Drop rows lacking name+energy+protein.
- [x] Task 1.2: Dedup across datasets by normalized name; when names collide, **prefer FNDDS (`dish`) then Foundation then SR Legacy** (source order). Tag `t` accordingly. Emit a single `FoodDB.json` sorted by name to `Packages/NutritionKit/Sources/NutritionAI/Resources/FoodDB.json`.
- [x] Task 1.3: Print counts + byte size → **2.98 MB, 13,355 foods** (5,431 dishes all with recipe; 12,827 with a portion). Well under the ~6 MB budget — no trimming needed.
- [x] Task 1.4: Keep `build-usda-foods.py`/`USDAFoods.json` in place for now; `FoodDB.json` is the superset the app will load in Phase 2, after which `USDAFoods.json` + `USDAFoodIndex` are removed. Added `FNDDS.json` + `legacyfoods.json` (and `*.pyc`) to `apple/.gitignore`.
- [x] Task 1.5: `FoodDB.json` generated and committable (slim file tracked; raw dumps ignored). *(Actual `git commit` is the user's to run.)*

### Tests (pipeline output is data; validate via a checked-in fixture + a Swift load test in Phase 2)
- [x] Test 1.a: `scripts/test_build_food_db.py` round-trips hand-built mini dumps → a dish with recipe + portion, an SR ingredient with sodium in mg + a modifier portion, a row dropped for missing energy/protein, the Foundation energy fallback chain. `python3 apple/scripts/test_build_food_db.py` → all 4 pass.
- [x] Test 1.b: Regenerating `FoodDB.json` twice is byte-identical (sorted, fixed rounding) — verified with `diff`.

### Definition of Done
- [x] `FoodDB.json` generated, committable, **2.98 MB** (< 6 MB), **13,355** foods (≥ 12,000), deterministic.
- [x] Raw dumps git-ignored; script reproduces the file exactly (byte-identical).
- [x] Sodium values verified in mg (anchovies 5400, range 0–38,800 mg — clearly not grams).
- [x] No app/package code depends on the new file yet (pure data drop; `USDAFoods.json` still the loaded resource).

- [x] **CHECKPOINT: Run `/compact focus on: Phase 1 complete, FoodDB.json slim schema (n/t/k/p/f/c/fi/so/su/ps/r) bundled in NutritionAI/Resources, sodium is mg, build_food_db.py reproducible; Phase 2 needs FoodDatabase loader + portion-aware fuzzy matching`**

---

## Phase 2 — FoodDatabase index + portion-aware matching

**Goal:** Load `FoodDB.json` once; fuzzy-match a free-text query over ~13.5 k foods; return ranked matches, each able to produce a `ParsedFood` with a sensible portion and (if present) its recipe components. Generalize the existing `USDAFoodIndex` scoring; back the FM reference-grounding with this database.

> **Note:** `FoodComponent` (Core) + `ParsedFood.components`/`totaledFromComponents()` (planned tasks 3.1–3.2) were **pulled forward into Phase 2** because `parsedFood(for:units:)` attaches components — a hard dependency. Phase 3 picks up from the parsers.

### Tasks
- [x] Task 2.1: `Sources/NutritionAI/FoodDatabase.swift` — `DBFood` (name; `kind .dish/.food`; per-100g k/p/f/c/fi?/so?/su?; `portions: [DBPortion]`; `recipe: [DBIngredient]`; `scaled(toGrams:)`). `public final class FoodDatabase: Sendable` loads `FoodDB.json` via `Bundle.module` (heterogeneous `["label", grams]` tuples decoded via a string-or-number enum); `init(foods:)` for tests; `shared`. **Also added** `Sources/NutritionCore/FoodComponent.swift` + `ParsedFood.components`/`totaledFromComponents()`.
- [x] Task 2.2: Ported `USDAFoodIndex` tokenization/stemming/filler scoring into `match(_:limit:) -> [DBMatch]`, plus: **type bias** (multi-word query + dish covering ≥2 query words → +0.3; single-word → concise `.food` +0.2), primary-token + whole-phrase bonuses, and **acronym alias expansion** ("blt" → "bacon lettuce tomato sandwich") for direct hits on common nicknames. Quantity words ("couple", "few"…) added to filler.
- [x] Task 2.3: `parsedFood(for:units:) -> ParsedFood` — picks the first portion (else 100 g), scales density, attaches `components` from the recipe (each ingredient grounded against the DB where it resolves, else grams-only; verbose USDA names trimmed to the head noun), `nutritionConfidence = .estimated`, `notes = "Per serving: <label> (<g> g)"`. `resolve(_:units:)` = confident match → parsedFood.
- [x] Task 2.4: `bestConfidentMatch(_:minScore:)` + `referenceFoods(_:)` retained for grounding. `FoundationModelsFoodParser` + `HeuristicFoodParser` + `Prompts.foodInstructions/referenceBlock` now draw from `FoodDatabase`/`DBFood` (was `USDAFoodIndex`/`USDAFood`); single-food behavior unchanged. **Deleted** `USDAFoodIndex.swift` + `USDAFoods.json` + `USDAFoodIndexTests.swift`.

### Tests (`Tests/NutritionAITests/FoodDatabaseTests.swift`)
- [x] Test 2.a: Injected mini-DB — `"bacon lettuce tomato sandwich"` ranks the `.dish` row first with its 4-item recipe; `"a BLT"` resolves via alias expansion.
- [x] Test 2.b: `"apple"` ranks the concise `.food` row over `"Apple pie"`; filler/plurals (`"a couple of apples"`) handled.
- [x] Test 2.c: `resolve` scales density × 105 g portion (231 → 243 kcal); sodium stays mg (→550); `notes` carries the portion; recipe → grounded components (bread 270/100g × 60g → 162 kcal).
- [x] Test 2.c′: an ingredient resolves with its portion; unknown nutrients stay `nil`; no components.
- [x] Test 2.d: bundled `FoodDatabase.shared` loads (> 12,000) and a real dish query returns components.
- [x] Test 2.e: existing `PromptsAndMappingTests` / `HeuristicFoodParserTests` pass against `FoodDatabase`-backed grounding (updated to `DBFood`).

### Definition of Done
- [x] Build + all 212 package tests pass (new and existing); app builds with the 3 MB DB bundled.
- [x] `USDAFoodIndex`/`USDAFoods.json` removed with no dangling refs; `FoodDatabase` is the single source.
- [x] Match latency trivially fast — a 1,000-query loop over the shipped ~13 k foods runs inside the suite (`performance` test) with the whole suite under 10 s.

- [x] **CHECKPOINT: Run `/compact focus on: Phase 2 complete, FoodDatabase loads FoodDB.json with portion-aware match()/bestConfidentMatch()/resolve() and parsedFood(for:units:) attaching recipe components; FoodComponent + ParsedFood.components pulled forward; USDAFoodIndex retired; Phase 3 needs DatabaseFoodParser + CompositeFoodParser wiring + DB suggestions in type flow`**

---

## Phase 3 — `ParsedFood.components` + Database/Composite parsers + wiring

**Goal:** Carry a breakdown through the parse, make the DB the primary generic resolver behind the "Analyze" action, and surface DB matches as tappable suggestions.

### Tasks
- [x] Task 3.1: `Sources/NutritionCore/FoodComponent.swift` — `FoodComponent: Codable, Sendable, Equatable, Hashable { name; grams; kcal/fat/carbs/protein; fiber?/sodium?/sugar? }` + `scaled(toGrams:)` + an `Array.summed(_:)` optional-aware reducer. *(Done in Phase 2.)*
- [x] Task 3.2: `ParsedFood` gained `components: [FoodComponent]?` (defaulted `nil`; `init(entry:)`/`makeEntry` leave it out → flattened on save) + `totaledFromComponents()`. **Not** added to `Entry`/`EntryRecord`. *(Done in Phase 2.)*
- [x] Task 3.3: `Sources/NutritionAI/DatabaseFoodParser.swift` — `DatabaseFoodParser: FoodParsing` over `FoodDatabase`: a confident `resolve(_, keepingName: query)` returns the measured nutrition **keeping the user's wording** ("a BLT" stays "a BLT"); no match throws `DatabaseLookupError.noMatch`.
- [x] Task 3.4: `Sources/AppCore/CompositeFoodParser.swift` — try the DB parser, fall back to the model parser on no-match. Wired `AppContainer.foodParser = CompositeFoodParser(database: DatabaseFoodParser(), fallback: makeFoodParser())`. DB participates in `-uitest` (deterministic, offline); the `testTypingAFoodSavesItToToday` UI test stays green because the entry keeps the typed word "apple".
- [x] Task 3.5: `TextInputModel` gained `dbMatches: [ParsedFood]` via `searchDatabase()` (offloaded to a detached task so the ~13k scan never janks typing; recipe grounding is O(1) via a name index). `AppContainer` exposes `foodDatabase: any FoodDatabaseQuerying` (seam in NutritionCore; `FoodDatabase.shared` real, `StaticFoodDatabase` stub for tests). `TextInputView` shows a "Foods" section (DB) above "Product matches" (OFF) and "Recent foods"; the macro subtitle shows "· N items" when a match carries a breakdown. A tapped suggestion keeps the canonical DB name.

### Tests
- [x] Test 3.a (`NutritionCoreTests/FoodComponentTests`): `FoodComponent` Codable round-trip + `scaled()`; `totaledFromComponents()` sums macros and leaves a context nutrient `nil` unless ≥1 component reports it; no-components → unchanged.
- [x] Test 3.b (`NutritionAITests/DatabaseFoodParserTests`): `parse("a BLT")` resolves to 243 kcal with components, food == "a BLT"; `parse("zzqq gibberish plate")` throws `.noMatch`.
- [x] Test 3.c (`AppCoreTests/CompositeFoodParserTests`): DB hit wins (fallback untouched); DB miss falls through to the model parser.
- [x] Test 3.d (`AppCoreTests/InputFlowModelTests`): `searchDatabase()` populates `dbMatches` for a settled query and clears them for a short one (via `StaticFoodDatabase`).

### Definition of Done
- [x] Build + all 221 package tests pass; app builds; `TextFlowUITests.testTypingAFoodSavesItToToday` green (no `xcodegen` needed — all new files are in the package).
- [x] "Analyze" on a BLT-style query yields a grounded total with components from the DB (verified against the mini DB and `FoodDatabase.shared`).
- [x] No persisted-model change; CSV import/export untouched.

- [x] **CHECKPOINT: Run `/compact focus on: Phase 3 complete, CompositeFoodParser(DatabaseFoodParser→FM) is AppContainer.foodParser, DB suggestions ("Foods" section) in TextInputView, foodDatabase seam; Phase 4 needs editable collapsed component breakdown in FoodConfirmModel/View with live total recalc + notes summary on save`**

---

## Phase 4 — Editable breakdown UI (confirm/edit sheet)

**Goal:** Show the component breakdown in the confirm sheet, collapsed by default, with per-line edit/remove and live total recalculation. Same UI for DB recipes and (Phase 5) AI itemizations.

### Tasks
- [ ] Task 4.1: `FoodConfirmModel` gains `components: [FoodComponent]` (seeded from `parsed.components ?? []`), `componentsExpanded: Bool = false`, and edit ops: `updateComponentGrams(_:at:)`, `removeComponent(at:)`, `addComponent(...)`. When components change, recompute the top-line macros via `totaledFromComponents()` and flip `nutritionConfidence = .userEdited`. When the top-line quantity changes and components exist, scale all components proportionally (or detach with a clear note — pick proportional scaling; cover in tests).
- [ ] Task 4.2: `FoodConfirmView` (+ `EditEntryView`) — a collapsed `DisclosureGroup`/section "Breakdown · N items" listing each component (name + grams + kcal), tap-to-edit grams, swipe-to-remove, an "Add item" row. Hidden entirely when `components` is empty. Styling subordinate to the primary calorie/macro fields (product principle).
- [ ] Task 4.3: On save, flatten: persist top-line totals as today; write a compact `notes` summary ("Bacon 16g, White bread 60g, …") when components exist and `notes` is empty, so the breakdown isn't lost from the log.

### Tests
- [ ] Test 4.a (`AppCoreTests/InputFlowModelTests`): seeding components from a parsed dish; editing one grams value rescales that line and updates the total; removing a line lowers the total; both flip `.userEdited`.
- [ ] Test 4.b: changing the top-line quantity proportionally scales components (total stays consistent).
- [ ] Test 4.c: empty components → no breakdown, behaves exactly like today's flow (`makeEntry` unchanged).
- [ ] Test 4.d (UI, `CalorieCounterUITests`): a smoke test that the breakdown disclosure appears for a seeded demo dish and expands. (Use `clean test` if the new method isn't discovered.)

### Definition of Done
- [ ] Build + all tests pass. App builds; UI smoke test green.
- [ ] Breakdown is collapsed by default and visually subordinate; absent for single foods.
- [ ] Saving an entry with an edited breakdown stores correct totals + a notes summary; editing later via `EditEntryView` still works.

- [ ] **CHECKPOINT: Run `/compact focus on: Phase 4 complete, editable collapsed breakdown in FoodConfirmModel/View with proportional scaling + notes summary on save; Phase 5 needs ComposedFood @Generable decompose→ground vs FoodDatabase→sum, slotted into CompositeFoodParser between DB match and FM single-food estimate`**

---

## Phase 5 — Foundation Models decomposition fallback (`ComposedFood`)

**Goal:** For a described food **not** in the DB, have the local model itemize it into components with portions; ground each component against `FoodDatabase`; sum in code. Renders in the Phase 4 component UI. This is the "describe literally any food" path.

### Tasks
- [ ] Task 5.1: `Sources/NutritionAI/ComposedFood.swift` — `@Generable struct ComposedFood { dishName; components: [Ingredient] }`, `@Generable struct Ingredient { food; quantity; unit; grams }` with `@Guide`s steering realistic portions and **grams per ingredient** (the model's strength). No nutrition numbers requested from the model.
- [ ] Task 5.2: `Sources/NutritionAI/DecomposingFoodParser.swift` — `FoodParsing` that: (1) one FM call → `ComposedFood`; (2) for each ingredient, `FoodDatabase.bestConfidentMatch(food)` → scale to `grams`, else fall back to an FM/heuristic single-food estimate for that ingredient; (3) build `ParsedFood` with `components` + summed top-line via `totaledFromComponents()`; `notes = "Estimated from N components"`. Guard `FoundationModelsFoodParser.isAvailable`; throw `.unavailable` otherwise so the composite skips it.
- [ ] Task 5.3: Insert into `CompositeFoodParser`: DB direct match → **DecomposingFoodParser** (when FM available) → FM single-food estimate. Keep the chain explicit and unit-tested with stubs.
- [ ] Task 5.4: Heuristic-only decomposition is **out of scope** (the heuristic can't itemize); when FM is unavailable the chain is DB → FM single-food (already grounded). Document this.

### Tests
- [ ] Test 5.a (`NutritionAITests`): `ComposedFood.toParsedFood`-style mapping — given a fixed `ComposedFood` (no live model) and an injected `FoodDatabase`, each ingredient grounds to DB density × grams and the total = Σ components; unknown ingredients fall back without crashing.
- [ ] Test 5.b: `DecomposingFoodParser` throws `.unavailable` when FM is unavailable (host without Apple Intelligence — mirrors existing availability tests), so the composite falls through deterministically.
- [ ] Test 5.c (`AppCoreTests`): `CompositeFoodParser` order — DB hit short-circuits; DB miss + FM-available routes to decomposition (stub); DB miss + FM-unavailable routes to single-food fallback.

### Definition of Done
- [ ] Build + all package tests pass.
- [ ] Decomposition path produces components that render in the Phase 4 UI (verified by a model test asserting `ParsedFood.components` is populated and summed).
- [ ] No live-model calls in tests (deterministic); on-device behavior guarded by `isAvailable`.

- [ ] **CHECKPOINT: Run `/compact focus on: Phase 5 complete, ComposedFood decomposition fallback grounded vs FoodDatabase and summed in code, wired into CompositeFoodParser; Phase 6 needs demo data refresh, perf/size validation, and docs/About update`**

---

## Phase 6 — Demo data, performance/size validation, docs

**Goal:** Make sure it's fast, small enough, demonstrable, and documented.

### Tasks
- [ ] Task 6.1: Add 1–2 compound demo entries (e.g. a BLT with its breakdown) to `AppContainer.seedDemoData()` so the breakdown UI is visible in `-demo` screenshots.
- [ ] Task 6.2: Performance/size validation — measure `FoodDatabase.shared` load time and memory (lazy/once), and `FoodDB.json` bundle size; if load is slow, decode off the main actor at startup (the index is already `Sendable`). Record numbers in the plan.
- [ ] Task 6.3: Update `AboutView` (a line: "Generic foods use an on-device USDA database; nothing leaves your device") and `CLAUDE.md`/package README notes for the data pipeline + `build_food_db.py`.

### Tests
- [ ] Test 6.a: a load-time/perf assertion test (decode + 100 queries under a fixed budget).
- [ ] Test 6.b: demo seed includes a component-bearing entry (assert in an `AppCore` test).

### Definition of Done
- [ ] All tests pass; app builds; `-demo` shows a breakdown.
- [ ] Bundle size + load time documented and acceptable.
- [ ] Docs updated.

- [ ] **CHECKPOINT: Run `/compact focus on: Plan 003 complete — on-device food database with compound-food reasoning shipped; record final bundle size + match latency`**

---

## Risks & mitigations

- **Bundle size (a few MB):** acceptable for the coverage; mitigations are fewer portions, coarser rounding, or gzip-in-bundle decoded at load. Measured in Phase 1/6.
- **False matches (precision):** the type bias + primary-token weighting + a confidence floor keep junk out; DB matches are *suggestions* and the Analyze fallback degrades gracefully. Tuned via the test corpus in Phase 2.
- **Recipe ingredient grounding depth:** FNDDS recipe ingredient names are USDA-style ("Tomatoes, for use on a sandwich") and may not re-match cleanly; acceptable — the dish row already has correct totals, the recipe is for *display/editing*, so per-ingredient kcal can use the recipe's own gram weights × the ingredient's own DB density when it resolves, else show grams only.
- **Latency of the decomposition path (Phase 5):** one FM call + local lookups; only fires on DB miss. Acceptable and clearly the minority case.
- **No persisted-model change** keeps CSV/import/Health sync untouched — lowest-risk integration.

## Out of scope (this plan)

- Persisting structured component lists per entry (we flatten on save).
- Branded composite dishes beyond what OFF/FNDDS already provide.
- Multi-language food matching.
- Replacing the OpenFoodFacts barcode/brand path (unchanged).
- Heuristic (non-FM) decomposition.
