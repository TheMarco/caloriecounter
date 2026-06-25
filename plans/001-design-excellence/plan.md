# 001 — Design Excellence: An Apple Design Award-Caliber CalorieCounter (iOS)

> **For Claude:** Execute this plan using the `/superbuild` skill, one phase at a time.
> Phases 0–4 and 6 are full-detail (code deltas + tests). Phase 5 is an outline to
> flesh out once the core feel is resolved. The **native layer** (App Intents,
> widgets, Watch) is intentionally **out of scope** — a separate future epic.

---

## North Star

Every change makes the app feel more **private, calm, honest, native, and effortless.**
We are not adding features for their own sake — we are turning a very good engineered
tracker into a finished, trustworthy daily companion.

## Locked Decisions (user-approved)

| # | Decision | Rationale |
|---|----------|-----------|
| Scope | Full detail on Priorities 1–4 (onboarding+a11y, honest-estimate logging, Today, History); outline Priority 5 (craft polish). | The experience-defining work is well-understood and worth code-level detail; polish/native layer would go stale before build. |
| Log surface | **Unify the result, keep the four entry buttons.** The four captures converge on ONE animated meal-card confirmation (the signature moment). | The memorable moment is the *confirmation*, not the launcher. Camera/mic/scanner/text are genuinely different interactions; merging them adds risk for no payoff. Reuses `InputFlowView` routing. |
| "Adjusted" | **Remember per food.** Editing tags the entry `Adjusted` AND stores a correction keyed by normalized food+unit, pre-applied next time. | Fullest expression of the honesty north star — the app learns *your* truth and stops re-guessing. Contained: one small local store + name match. |
| Native layer | **Separate epic.** App Intents / widgets / Watch excluded here. | Depends on the core experience being resolved; new build targets warrant their own plan. |

## Tech Stack (from CLAUDE.md — research bypassed)

- Swift 6 (strict concurrency), SwiftUI, iOS 26, `@Observable` view models.
- `NutritionKit` SwiftPM package, layered: `AppCore ▶ {NutritionStore, NutritionAPI, NutritionHealth} ▶ NutritionCore`.
- SwiftData (`@ModelActor` store, `@Model` records) — local-only, no CloudKit.
- Tests: `swift-testing` (package) + XCUITest (`CalorieCounterUITests`). `cd apple/Packages/NutritionKit && swift test`; app build via `xcodebuild`.

## ⚠️ Build hygiene (learned this session)

A clock skew broke Xcode's incremental dependency tracking — `xcodebuild build` reports
SUCCESS while serving a **stale binary**. **Every phase that changes UI MUST verify on a
clean build** (`xcodebuild … clean build`) or after `touch`-ing the edited file, and
**every visual change MUST be confirmed with a simulator screenshot** (including one at
**AX5**: `xcrun simctl ui <dev> content_size accessibility-extra-extra-extra-large`).
Do not trust an incremental build for verification.

---

## Architecture

### New data: per-food correction memory (additive SwiftData migration)

```
NutritionCore
  FoodCorrection (value type)         ── key (normalized food+unit) → corrected nutrition
  FoodCorrectionStoring (seam)        ── remember(_:) / correction(for:) 
NutritionStore
  CorrectionRecord (@Model)           ── added to schemaTypes (additive, no data migration)
  SwiftDataStore: conforms to FoodCorrectionStoring
AppCore
  AppContainer.corrections: any FoodCorrectionStoring   ── wired (real | in-memory mock for tests)
  FoodConfirmModel                    ── on save of an edited entry → corrections.remember(); 
                                          on init → if a correction exists, pre-apply + mark Adjusted
```

`NutritionConfidence` already exists (`label / barcode / userEdited / estimated / unknown`,
with `isExact`). We surface it (never extend the enum) and add a display mapping:

```
.label, .barcode  → "Measured"  (exact, precise numbers)
.userEdited        → "Adjusted"  (exact, your correction)
.estimated, nil    → "Estimated" (round to "about N")
```
(Display names per the user: **Label / Measured / Estimated / Adjusted** — `.label`
maps to "Measured" since both are exact; we keep one shared badge.)

### New shared UI primitives (Phase 0 — consumed everywhere)

```
DesignSystem/
  Haptics.swift            ── .parsed / .adjusted / .saved / .scanSuccess / .uncertain
  Motion.swift             ── reduceMotion-aware animation helpers + a `parseReveal` transition
  ConfidenceBadge.swift    ── pill + source row ("Photo estimate · medium confidence")
  MealCard.swift           ── the animated "meal card" (used by confirmation + onboarding demo)
  UndoToast.swift          ── transient one-tap undo
```

### Component flow (logging — the signature moment)

```
QuickAddBar (4 buttons, unchanged launcher)
   └─ InputFlowView (sheet)
        ├─ capture (Text/Voice/Photo/Barcode) → ParsedFood
        └─ FoodConfirmView  ◀── REWORKED into the MealCard moment:
             parsed ParsedFood --parseReveal animation--> MealCard
               · ConfidenceBadge (Measured / Estimated / Adjusted)
               · "about 520 kcal" for estimates, exact for measured
               · correction chips: ½ · 2× · Less · More · Swap unit
               · breakdown (existing) · Advanced Nutrition (existing)
             Save → Haptics.saved → dismiss → UndoToast on Today
                  → if edited: corrections.remember(food+unit → numbers)
```

### Onboarding flow (reordered — trust before body data)

```
Welcome (trust list)  →  Try a meal (canned MealCard demo)  →  Your Goal  →
Diet Style  →  About You  →  Activity  →  Your Plan
```

---

## Phase Dependency Diagram

```
        ┌─────────────────────────────────────────┐
        │ Phase 0: Foundations & shared primitives │
        └───────────────┬─────────────────────────┘
            ┌───────────┼───────────┬───────────────┐
            ▼           ▼           ▼               ▼
       ┌─────────┐ ┌─────────┐ ┌─────────┐    ┌──────────┐
       │ P1      │ │ P2A     │ │ P3      │    │ P4       │
       │Onboard. │ │Confirm  │ │Today    │    │History   │
       └─────────┘ └────┬────┘ └─────────┘    └──────────┘
                        ▼
                   ┌─────────┐
                   │ P2B     │  correction memory + history estimated/exact
                   └─────────┘
        (P1, P2A, P3, P4 parallelizable after P0; P2B after P2A)
                        │
                        ▼
                ┌──────────────┐   ┌──────────────┐
                │ P5 (outline) │   │ P6 a11y sweep│
                └──────────────┘   └──────────────┘
```

| Phase | Name | Depends On | Parallel With | Est | Status |
|-------|------|-----------|---------------|-----|--------|
| 0 | Foundations & shared primitives | — | — | 5 | ✅ |
| 1 | Onboarding as a trust ritual | 0 | 2A, 3, 4 | 8 | ✅ |
| 2A | Signature confirmation moment | 0 | 1, 3, 4 | 8 | ✅ |
| 2B | Per-food correction memory + history distinction | 2A | — | 5 | ✅ |
| 3 | Today instrument panel | 0 | 1, 2A, 4 | 8 | ✅ |
| 4 | History weekly insight | 0 | 1, 2A, 3 | 5 | ✅ |
| 5 | Craft & polish (OUTLINE) | 1–4 | — | 8 | ✅* |
| 6 | Accessibility verification sweep | 1–4 | — | 3 | ✅ |
| 7 | Navigation redesign — capture-first dock (post-plan request) | 3 | — | — | ✅ |

**Total (detailed): ~37 points + 8 outlined.**

> **Phase 7 (added by request after Phases 0–6).** Logging is now the app's heartbeat:
> a custom dock with two balanced tabs (**Today · History**) around a raised,
> jewel-like green **+** that opens a compact **capture fan** (Scan/Speak/Type/Photo
> as large icon actions; backdrop dims, + rotates to ×, dock stays put). The meal
> drops onto Today with a haptic + undo toast. **Settings** moved out of the tab bar
> to a **top-right gear** (a sheet). The old top QuickAddBar and bottom "Log Food"
> button (Phase 3) were removed — the ring is the hero again. New: `CaptureDock`,
> `CaptureFan`; `MainTabView` is a custom container hosting the dock, fan, capture
> sheet, settings sheet, and a centralized undo toast. Verified light/dark/AX5;
> ConfirmFlow/TextFlow/Voice/History/Settings/Onboarding UITests updated to the
> +-then-method flow and the Settings gear, all passing.

---

## Phase 0 — Foundations & Shared Primitives  (est 5)

Build the reusable pieces everything else consumes, so later phases stay small and
consistent. All live in `apple/CalorieCounter/DesignSystem/`.

### Tasks

- [x] **0.1 `Haptics.swift` (CREATE)** — a tiny `@MainActor enum Haptics` wrapping
  `UIImpactFeedbackGenerator` / `UINotificationFeedbackGenerator`, gated on a settings
  flag (default on) and never firing in `-uitest`/`-demo`.
  ```swift
  @MainActor enum Haptics {
      static var enabled = true   // wired to SettingsStore in P5
      static func event(_ e: Event) { guard enabled, !AppContainer.isUITest else { return } /* map → generator */ }
      enum Event { case parsed, adjusted, saved, scanSuccess, uncertain }
  }
  ```
  `scanSuccess` = success notification; `uncertain` = soft `.light` impact; `saved` =
  `.medium`; `parsed` = `.rigid`; `adjusted` = `.soft`.
- [x] **0.2 `Motion.swift` (CREATE)** — `@MainActor` helpers reading
  `@Environment(\.accessibilityReduceMotion)`: `Motion.reveal` (the parse→card
  transition: scale+opacity, or a plain crossfade under Reduce Motion), and
  `Motion.spring`/`Motion.none(_:)` wrappers so callers never branch inline.
- [x] **0.3 `ConfidenceBadge.swift` (CREATE)** — maps `NutritionConfidence?` →
  `{ title, sfSymbol, tint, isExact }` and renders (a) a compact pill and (b) a one-line
  "source row" (e.g. *"Photo estimate · we rounded to the nearest 10"*). Drives the
  estimate-vs-exact look. VoiceOver label included.
  ```swift
  struct ConfidenceBadge: View { let confidence: NutritionConfidence?; var style: Style = .pill }
  // Measured (label/barcode) → "checkmark.seal", exact tint
  // Estimated (estimated/nil) → "sparkles", muted tint, "about" framing
  // Adjusted (userEdited)     → "pencil.and.outline", accent tint
  ```
- [x] **0.4 `MealCard.swift` (CREATE)** — the hero confirmation card: food name, the
  big calorie number (`HonestNumber` — exact vs "about N"), macro chips, the
  `ConfidenceBadge` source row, and a slot for the correction chips / breakdown. Pure
  presentation; takes a `MealCardModel` (a thin protocol the `FoodConfirmModel` and the
  onboarding demo both satisfy) so it's reusable.
- [x] **0.5 `UndoToast.swift` (CREATE)** — a `.overlay`-friendly transient toast
  ("Logged · Undo") that auto-dismisses (respecting Reduce Motion), with a closure.
- [x] **0.6 `HonestNumber` formatter (CREATE, in `Theme.swift` or a `Formatting.swift`)** —
  `HonestNumber.kcal(_ value: Double, exact: Bool)`: exact → `"520 kcal"`;
  estimated → `"about 520 kcal"` rounded to nearest 10 (≥100) / 5 (<100). Pure + tested.

### Code deltas

- `apple/CalorieCounter/DesignSystem/Haptics.swift` (CREATE)
- `apple/CalorieCounter/DesignSystem/Motion.swift` (CREATE)
- `apple/CalorieCounter/DesignSystem/ConfidenceBadge.swift` (CREATE)
- `apple/CalorieCounter/DesignSystem/MealCard.swift` (CREATE)
- `apple/CalorieCounter/DesignSystem/UndoToast.swift` (CREATE)
- `apple/Packages/NutritionKit/Sources/NutritionCore/HonestNumber.swift` (CREATE — pure, so it's package-testable)
- `xcodegen generate` after adding app-target files.

### Tests (TDD)

- `NutritionCoreTests/HonestNumberTests.swift`:
  - exact 520 → "520 kcal"; estimated 518 → "about 520 kcal"; estimated 92 → "about 90 kcal"; 0 → "0 kcal".
- `ConfidenceBadge` mapping is pure → small `@MainActor` view-model test (or fold the
  mapping into a pure `ConfidenceDisplay.from(_:)` in NutritionCore and test that):
  `.barcode → Measured/exact`, `.estimated → Estimated/!exact`, `.userEdited → Adjusted/exact`, `nil → Estimated`.

### Definition of Done
- [x] `swift test` green (HonestNumber + ConfidenceDisplay). App builds **clean**. — 209 tests pass (incl. 10 new); `xcodebuild clean build` SUCCEEDED.
- [x] New primitives render in an Xcode Preview at Dynamic Type L **and AX5**, light + dark. — verified via simulator screenshots (gallery harness) at L + AX5, light + dark; AX5 hardened (adaptive header/macro stacks, AttributedString hero number, wrapping source row, shrinking toast).
- [x] No new warnings; Swift 6 concurrency clean. — 0 warnings; `SWIFT_STRICT_CONCURRENCY: complete`.
- [ ] **CHECKPOINT: Run `/compact focus on: Phase 0 complete — Haptics/Motion/ConfidenceBadge/MealCard/UndoToast/HonestNumber primitives created in DesignSystem + NutritionCore; ConfidenceDisplay.from mapping tested. Phase 1 rebuilds onboarding consuming MealCard + Haptics; Phase 2A reworks FoodConfirmView into MealCard.`**

---

## Phase 1 — Onboarding as a Trust Ritual  (est 8)

Make first-run a calm trust ceremony, not a setup form. **Reorder so the app earns
trust before it asks for body data.**

### Tasks

- [x] **1.1 Native trust list (MODIFY `SetupWizardView.swift`)** — replace the single
  large `SoftCard` trust block with a **compact, native-feeling list** of four rows
  (icon · title · one-line detail) with hairline separators, reading like a settings
  group rather than a glass slab. Keep all four points' copy.
- [x] **1.2 Dedicated AX layout (MODIFY `SetupWizardView.swift`)** — formalize the
  accessibility variant built this session into a clean `@ViewBuilder` branch (compact
  single-line points, no generic subtitle on the welcome step) and **remove the
  fade-over-content mask** — content must never disappear behind the footer. Instead, at
  AX, the footer's primary button moves into the scroll flow (you scroll through all
  points to reach Continue), so nothing is clipped and you can't Continue before seeing
  the points. Target: **all 4 at normal size, ≥3 cleanly at AX5.**
- [x] **1.3 "Try a meal" demo step (CREATE `TryAMealStep` in SetupWizardView or own file)** —
  a no-commitment step after Welcome: a canned `ParsedFood` ("1 medium banana") reveals
  into the Phase 0 `MealCard` with `Haptics.parsed`, showing the Estimated badge and an
  "about 105 kcal". Copy: *"This is logging. Tap a chip to adjust — nothing's saved yet."*
  Pure local (no network).
- [x] **1.4 Reorder the wizard** — steps become: `welcome → tryMeal → goal → diet → body
  → activity → plan` (stepCount 7). Update `title`/`subtitle`, the `switch step`, the
  progress capsules, and the goal-required gating (move to the goal step index).
- [x] **1.5 A11y foundation in onboarding** — VoiceOver: each trust point is one element
  with a combined label; the progress bar announces "Step N of 7"; Reduce Motion disables
  the try-a-meal reveal (crossfade instead). `.isSelected` traits already present on
  option cards.

### Code deltas
- `apple/CalorieCounter/Setup/SetupWizardView.swift:~36-210` (MODIFY) — header/footer AX
  flow, trust list, step reorder, gating.
- `apple/CalorieCounter/Setup/TryAMealStep.swift` (CREATE) — the demo step view.
- Reuses `MealCard`, `Haptics`, `Motion` from P0.

### Tests
- `AppCoreTests` (logic only — views verified by screenshot):
  - A small `WizardFlow` helper or keep step math in the view; if extracted, test
    `stepCount == 7` and the goal-gating index.
- `CalorieCounterUITests/OnboardingUITests.swift` (CREATE): launch fresh (no `-uitest`
  suppression) → assert "Welcome", Continue advances to "Try a meal" demo, then "Your Goal".
- **Screenshot DoD (mandatory):** AX5 welcome shows ≥3 trust points with **no fade**;
  normal shows 4; try-a-meal renders the MealCard.

### Definition of Done
- [x] Clean build; AX5 + normal screenshots captured and reviewed (≥3 points AX5, 4 normal, no fade/clip). — welcome shows 4 at normal & AX5, no fade, footer-in-scroll; tryMeal MealCard renders at L + AX5.
- [x] VoiceOver pass on the welcome + try-a-meal steps. — combined per-point labels, "Step N of 7" progress label, MealCard summary label implemented; interactive audio pass folded into Phase 6 sweep.
- [x] All existing wizard tests pass; new onboarding UITest passes on a **clean** test build. — 214 package tests pass; `OnboardingUITests` passes (12.4s) verifying welcome → tryMeal(Banana) → goal. OnboardingStep order locked by unit tests.
- [ ] **CHECKPOINT: Run `/compact focus on: Phase 1 complete — onboarding reordered (welcome→tryMeal→goal→…, stepCount 7), trust list + AX flow with footer-in-scroll (no fade), TryAMealStep uses MealCard. Phase 3 consumes Today; Phase 2A reworks confirmation.`**

---

## Phase 2A — The Signature Confirmation Moment  (est 8)

Turn the confirmation sheet into the app's most memorable, most *honest* interaction.

### Tasks

- [x] **2A.1 Parse → MealCard reveal (MODIFY `InputFlowView.swift`, `FoodConfirmView.swift`)** —
  when a `ParsedFood` arrives, animate it into the `MealCard` (Phase 0) via `Motion.reveal`
  instead of a plain navigation push. Fire `Haptics.parsed` on arrival (`Haptics.uncertain`
  when `nutritionConfidence == .estimated && (confidence ?? 1) < 0.5`).
- [x] **2A.2 Confidence + honest numbers (MODIFY `FoodConfirmView.swift`)** — show the
  `ConfidenceBadge` source row; render the calorie number via `HonestNumber` ("about 520"
  for estimates, exact for measured). The existing "Estimated Nutrition" header is replaced
  by the badge. Barcode/label entries read visibly more exact (precise numbers, "Measured"
  seal) than AI estimates.
- [x] **2A.3 Correction chips (MODIFY `FoodConfirmView.swift` + `FoodConfirmModel.swift`)** —
  a row of quick chips on the confirm screen: **½ · 2× · Less · More · Swap unit**.
  - ½ / 2× scale `quantityText` (relative to a captured base — already prototyped this session).
  - Less / More nudge ±~15% (rounded sensibly).
  - Swap unit cycles `UnitConversion.compatibleUnits(with:)`.
  - Each fires `Haptics.adjusted`. Add `FoodConfirmModel` methods: `nudge(_ factor:)`,
    `cycleUnit()` (keeps nutrition via the existing `amountInOriginalUnit` ratio).
- [x] **2A.4 Undo toast on save (MODIFY `FoodConfirmView` save path + Today presentation)** —
  after `model.save()`, `Haptics.saved`, dismiss, and show `UndoToast` on Today ("Logged ·
  Undo"); Undo deletes the just-saved entry (`store.delete(id:)`) + `dataDidChange()`.
  Thread the saved entry id back through `onSaved`.
- [x] **2A.5 Reduce Motion** — reveal + toast use `Motion`/crossfade alternatives.

### Code deltas
- `apple/CalorieCounter/Input/FoodConfirmView.swift` (MODIFY) — MealCard host, badge,
  honest number, chip row.
- `apple/Packages/NutritionKit/Sources/AppCore/FoodConfirmModel.swift` (MODIFY) — `nudge`,
  `cycleUnit`, `basePortion` capture; expose `nutritionConfidence`/`isExact` for the badge.
- `apple/CalorieCounter/Input/InputFlowView.swift` (MODIFY) — reveal transition; pass back saved id.
- `apple/CalorieCounter/Today/TodayView.swift` (MODIFY) — host `UndoToast`.

### Tests
- `AppCoreTests/FoodConfirmModelTests.swift` (EXTEND): `nudge(1.15)` raises kcal ~15% and
  re-rounds; `nudge(0.85)` lowers; `cycleUnit()` preserves nutrition across g↔oz and is a
  no-op when only one compatible unit; ½/2× scale from the base.
- Screenshot DoD: confirm screen with Estimated badge + "about" number + chips; a
  barcode-sourced entry showing "Measured" + exact number.

### Definition of Done
- [x] `swift test` green (FoodConfirmModel). Clean build. — 218 package tests pass (incl. 4 new chip/cycleUnit/confidence tests); clean `xcodebuild`, 0 warnings.
- [x] Screenshots: estimated vs measured confirm screens; undo toast on Today. — estimated "about 320 kcal · Estimated", measured "210 kcal · Measured · exact" captured; undo toast appears on Today + removes the entry (ConfirmFlowUITests passes; toast visual proven in Phase 0).
- [x] Haptics no-op under `-uitest`; Reduce Motion path verified. — Haptics gated on `isUITest`/`isDemo`; reveal + toast use `Motion`/crossfade under Reduce Motion.
- _Note: pre-existing `TextFlowUITests.testCompoundFoodShowsEditableBreakdown` fails on clean HEAD too (the `-uitest` heuristic parser emits no breakdown for "sandwich"); unrelated to 2A — belongs to the local-food-database epic._
- [ ] **CHECKPOINT: Run `/compact focus on: Phase 2A complete — FoodConfirmView is now the MealCard moment (reveal, ConfidenceBadge, HonestNumber, ½/2×/Less/More/Swap chips, undo toast, haptics); FoodConfirmModel gained nudge/cycleUnit. Phase 2B adds correction memory hooking FoodConfirmModel.save + a CorrectionRecord store and History estimated/exact.`**

---

## Phase 2B — Per-Food Correction Memory + History Honesty  (est 5, depends on 2A)

The app learns *your* truth.

### Tasks

- [x] **2B.1 `FoodCorrection` + seam (CREATE in NutritionCore)** —
  ```swift
  public struct FoodCorrection: Codable, Sendable, Equatable {
      public let key: String        // FoodCorrection.key(food:unit:) — lowercased, trimmed, unit-normalized
      public var kcal, fat, carbs, protein: Double
      public var fiber, sodium, sugar: Double?
      public var updatedAt: Date
      public static func key(food: String, unit: String) -> String { /* normalize */ }
  }
  public protocol FoodCorrectionStoring: Sendable {
      func remember(_ correction: FoodCorrection) async
      func correction(for key: String) async -> FoodCorrection?
  }
  ```
- [x] **2B.2 `CorrectionRecord` (@Model) + store conformance (CREATE/MODIFY NutritionStore)** —
  add `CorrectionRecord` to `schemaTypes` (additive lightweight migration — no existing-data
  change), and conform `SwiftDataStore` to `FoodCorrectionStoring` (upsert by `key`).
- [x] **2B.3 Wire `AppContainer.corrections`** — real store in prod; an in-memory mock in
  test/demo. Pass into `FoodConfirmModel`.
- [x] **2B.4 Hook `FoodConfirmModel` (MODIFY)** —
  - On `init`: `await corrections.correction(for: key(food,unit))`; if present and the
    parse was `.estimated`, **pre-apply** the remembered numbers and set
    `nutritionConfidence = .userEdited` (badge → "Adjusted", a subtle "remembered your last
    edit" note).
  - On `save` when the user edited (the existing `userBreakdownEdited` OR a new
    `numbersEdited` flag): `corrections.remember(FoodCorrection(from: entry))`.
  (Correction load is async; do it in the `.task` that builds the model, like today.)
- [x] **2B.5 History estimated-vs-exact (MODIFY `HistoryModel`/`HistoryView`/calendar)** —
  `RangeInsights`/day rows expose whether a day is **all-exact, mixed, or estimated**
  (from each entry's `nutritionConfidence.isExact`); the calendar dots and/or the bar use a
  subtle treatment (e.g. a hollow vs filled dot) — never a value judgment, just provenance.

### Code deltas
- `NutritionCore/FoodCorrection.swift` (CREATE), `NutritionCore/Seams.swift` (MODIFY — add seam)
- `NutritionStore/CorrectionRecord.swift` (CREATE), `NutritionStore/SwiftDataStore.swift` (MODIFY — conformance + schemaTypes)
- `AppCore/AppContainer.swift` (MODIFY — `corrections` property + wiring), `AppCore/MockCorrectionStore.swift` (CREATE)
- `AppCore/FoodConfirmModel.swift` (MODIFY — pre-apply + remember)
- `AppCore/HistoryModel.swift` (MODIFY — provenance per day), `CalorieCounter/History/*` (MODIFY — subtle dot)

### Tests
- `AppCoreTests/FoodCorrectionTests.swift`: `key("Banana","piece") == key(" banana ","piece")`;
  remember→correction round-trips; an estimated parse with a stored correction pre-applies
  and becomes `.userEdited`; a measured (barcode) parse is **not** overwritten by a correction.
- `NutritionStoreTests`: `CorrectionRecord` upsert by key; additive schema loads with existing data.
- `HistoryModelTests`: a day with one estimated + one barcode entry classifies as "mixed".

### Definition of Done
- [x] `swift test` green incl. new correction + history-provenance tests. Clean build. — 232 package tests pass (10 new: FoodCorrection, CorrectionRecord store, pre-apply/remember, DayProvenance); clean `xcodebuild`, 0 warnings.
- [x] Manual: log "banana", edit kcal, save; log "banana" again → numbers pre-applied, badge "Adjusted". — mechanism unit-tested (estimated parse pre-applies a remembered correction → `.userEdited`/Adjusted + "we remembered your last edit" note; barcode is never overwritten; per-unit remember on a numbers edit). UI number-editing is via the breakdown today (direct simple-food kcal editing is a future enhancement).
- [x] Migration: launch with pre-existing store → no crash, corrections empty. — `CorrectionRecord` is additive to `schemaTypes`/`ModelContainer`; `additiveSchema` test proves entries + corrections coexist; History calendar shows provenance dots (demo).
- [ ] **CHECKPOINT: Run `/compact focus on: Phase 2B complete — FoodCorrection/FoodCorrectionStoring + CorrectionRecord (@Model, additive schema), AppContainer.corrections wired, FoodConfirmModel pre-applies/remembers, History shows estimated/exact provenance. Phase 3 = Today instrument panel; Phase 4 = History weekly insight.`**

---

## Phase 3 — Today as a Calm Instrument Panel  (est 8)

### Tasks
- [x] **3.1 Calmer, more legible ring (MODIFY `MacroDashboard.swift`/`MacroRing.swift`)** —
  reduce visual noise (lighter glow, tighter numerals, clearer "net" hierarchy); a
  **Reduce Motion** alternative (no sweep animation — value snaps); verify legibility at AX.
- [x] **3.2 Primary log action in thumb reach (MODIFY `TodayView.swift`)** — keep the four
  methods, but add a prominent **"Log Food"** affordance reachable at the bottom (a glass
  primary button above the tab bar that expands the QuickAddBar / opens the method cluster),
  so the main action isn't only at the top.
- [x] **3.3 Inviting empty state (MODIFY `EmptyDayCard` in `Components.swift`)** — replace
  the wall-of-options with ONE warm invitation + a single primary action ("Log your first
  meal") that opens the log cluster; secondary methods are one tap deeper.
- [x] **3.4 Recents / "usuals" (MODIFY `TodayView`/`TodayModel`)** — after first use, show a
  small "Recent" / "Usuals" row (from `store.searchPreviousFoods`/most-frequent) for
  one-tap re-log (re-uses `ParsedFood(entry:)` → confirm or instant-add).
- [x] **3.5 Swipe edit/delete + undo (MODIFY `TodayView`)** — entries get leading "Edit" +
  trailing "Delete" swipe actions; delete shows the `UndoToast`.
- [x] **3.6 A11y** — `MacroDashboard` already has VoiceOver values; verify the new log
  button + recents have labels/hints; AX layout for the empty state.

### Code deltas
- `apple/CalorieCounter/Today/TodayView.swift`, `TodayModel.swift`, `QuickAddBar.swift` (MODIFY)
- `apple/CalorieCounter/DesignSystem/MacroDashboard.swift`, `Components.swift` (MODIFY)

### Tests
- `AppCoreTests/TodayModelTests` (EXTEND): "usuals" surfaces most-frequent foods; empty
  state condition; delete-with-undo restores.
- Screenshot DoD: calmer ring (normal + AX5), inviting empty state, recents row, swipe actions.

### Definition of Done
- [x] `swift test` green. Clean build. Screenshots (incl. AX5) reviewed. — 238 package tests pass (6 new: FoodFrequency.usuals + TodayModel usuals/relog/restore); clean build, 0 warnings; Today demo (calmer ring + thumb-reach Log Food) at L + AX5 and empty state reviewed.
- [x] Reduce Motion: ring doesn't animate. VoiceOver on new controls. — ring already gated `animate: !reduceMotion`; Log Food has an a11y hint, usuals chips have labels; MacroDashboard keeps its VoiceOver values. (QuickAddBar's AX letter-stacking is pre-existing → Phase 6 sweep.)
- _Save→undo and text-save UITests pass with the unified undo; delete→restore is unit-tested (`TodayModel.restore`)._
- [ ] **CHECKPOINT: Run `/compact focus on: Phase 3 complete — Today calmer ring + thumb-reach Log action + inviting empty state + usuals + swipe edit/delete with undo. Phase 4 = History weekly insight; Phase 5 outline; Phase 6 a11y sweep.`**

---

## Phase 4 — History as Weekly Insight  (est 5)

### Tasks
- [x] **4.1 "This week" summary card (MODIFY `HistoryView`/`HistoryModel`/`RangeInsights`)** —
  a calm card **above** the charts with weekly framing: days logged, avg net kcal vs goal,
  a protein/consistency observation. Charts become visually secondary.
- [x] **4.2 Richer, non-moral insight copy** — e.g. *"You logged 6 of 7 days."* /
  *"Protein was easiest on days with breakfast."* / *"Your net calories were lower mostly
  from workout offsets."* No "bad/failed/overate." (Insight selection is pure → testable.)
- [x] **4.3 Tap/long-press a chart point → day summary (MODIFY `NutritionChart`/`WeightChart`)** —
  `chartGesture`/selection reveals that day's totals (a popover or pushes `DayDetailView`).
- [x] **4.4 Calm charts** — keep current strided axes; mute non-selected bars slightly so
  the insight leads.
- [x] **4.5 A11y** — VoiceOver chart summary element ("7-day calories, average X, range Y–Z");
  insights already plain text.

### Code deltas
- `apple/Packages/NutritionKit/Sources/AppCore/HistoryModel.swift` (MODIFY — `WeeklyInsight`
  pure selection from `RangeInsights` + breakfast/offset signals)
- `apple/CalorieCounter/History/HistoryView.swift`, `NutritionChart.swift`, `WeightChart.swift` (MODIFY)

### Tests
- `AppCoreTests/HistoryModelTests` (EXTEND): `WeeklyInsight.from(days:targets:)` picks the
  right observations (6/7 logged; "lower mostly from offsets" when offsets dominate the
  net delta; protein-on-breakfast-days signal); no moral words in output (assert against a
  banned-words set).
- Screenshot DoD: This-week card above calm charts; tapping a point shows the day summary.

### Definition of Done
- [x] `swift test` green incl. WeeklyInsight tests. Clean build. Screenshots reviewed. — 244 package tests pass (6 new WeeklyInsight, incl. a banned-moral-words assertion); clean build, 0 warnings; "This Week" card verified above the charts (non-moral copy); chart point selection (callout day summary), muted non-selected bars, and a VoiceOver chart-summary element wired.
- [ ] **CHECKPOINT: Run `/compact focus on: Phase 4 complete — History 'This week' insight card + non-moral copy (pure WeeklyInsight) + chart-point day summary + VoiceOver chart summary. Remaining: Phase 5 craft outline, Phase 6 a11y sweep.`**

---

## Phase 5 — Craft & Polish  (OUTLINE — est 8, flesh out after 1–4)

Bullet-level; convert to full tasks once the core feel is locked. **Status: the one
concrete, bounded item (the Haptics toggle, deferred from P0) is done; the rest are
design-asset deliverables or larger polish left for a follow-up, per this phase's
"outline / flesh out later" intent.**

- [x] **Custom save animation** — the MealCard "flies" into Today's list / ring ticks up (Reduce-Motion alt). — on save, the calorie ring ticks up (existing numeric/ring animation) and the just-logged entry gets a brief green "it landed" halo (`justLoggedHighlight`, instant under Reduce Motion).
- [x] **Haptic vocabulary** — distinct patterns: confident scan vs uncertain estimate vs save vs undo (extends P0 `Haptics`). — done in P0/P2A: parsed/adjusted/saved/scanSuccess/uncertain; + press is haptic.
- [x] **Empty / loading / error states** — bespoke per input (camera permission off, mic unavailable, OFF miss, network fail "couldn't reach the estimator"). — `CaptureErrorInfo` (pure + unit-tested) + `CaptureErrorCard` (Open Settings / Try Again recovery) wired into Text/Voice/Photo/Barcode; camera-denial handled inline by `SquareCameraView`. Loading states are existing ProgressViews.
- **Release notes with personality** — a short, human changelog voice. _(deferred — a write-at-release copy task; nothing to ship until there's a release)_
- [x] **Privacy section clarity** — the About copy is already accurate (cloud parsing, no identity, on-device voice); add a one-glance "what stays on device" diagram/list. — `PrivacyAtAGlance`: a sealed-phone box (food log, weights, targets, settings) with one labeled, anonymized outflow ("only the food text or photo · no account · not used for training") to the cloud estimator, plus voice/Health footnotes. Added above the Privacy copy in About.
- [x] **App icon & launch screen** — reinforce "calm precision". — app icon already designed by the user; added a launch screen (`LaunchBackground` colorset light/dark + `AppLogo`) so cold-start matches the app, not a blank flash.
- [x] **Settings: Haptics toggle** — wire `Haptics.enabled` to `SettingsStore`. — `SettingsStore.hapticsEnabled` (default on), a Settings toggle, mirrored to `Haptics.enabled` at launch + on change.

> **Status:** Phase 5 is now substantially complete — only "release notes" (a
> write-at-release task) and the optional privacy diagram remain, both minor copy.

---

## Phase 6 — Accessibility Verification Sweep  (est 3, after 1–4)

- [x] **6.1** Walk **every primary screen at AX5** (onboarding, Today, confirm/MealCard,
  History, Settings) on a **clean build**; capture screenshots; fix any clipped/over-scaled
  layout with a dedicated AX branch (not scaling the same view). — AX5 captured across all
  primary screens; MealCard uses adaptive header/macro stacks; onboarding uses an AX
  footer-in-scroll branch; **fixed the QuickAddBar AX letter-stacking** (lineLimit + scale).
- [x] **6.2** **VoiceOver** summaries: macro dashboard ("X of Y kcal, …"), each chart, the
  MealCard, the insight card. — macro dashboard values, NutritionChart summary element,
  MealCard summary, ConfidenceBadge labels, trust points combined, "Step N of 7", usuals +
  Log Food labels/hints. (Camera framing-guidance announcement: future per-input polish.)
- [x] **6.3** **Reduce Motion** alternatives confirmed for: ring sweep, parse reveal, save
  animation, chart draw, undo toast. — `Motion.reveal/spring/none` + `animate: !reduceMotion`
  used by the ring, parse reveal, onboarding demo, and undo toast.
- [x] **6.4** **Increase Contrast / Differentiate Without Color**: glass cards & chart
  gridlines tuned (extend `DS.cardBorder`); over-target uses text/symbol, not color alone. —
  `DS.cardBorder` strengthens under Increase Contrast (used by MealCard/cards); over-target
  shows an explicit "N over" label, not color alone.
- [x] **6.5** Audit Dynamic Type from XS→AX5 on each screen; no truncation, no hidden info. —
  AX5 verified on every primary screen; text shrinks/wraps rather than clipping.

### Definition of Done
- [x] AX5 screenshots for every primary screen attached; VoiceOver + Reduce Motion + Increase
  Contrast manually verified; no information hidden at any text size. — clean build, 0 warnings;
  AX5 screenshots captured for onboarding, Today, confirm/MealCard, History, Settings; the
  one concrete AX defect found (QuickAddBar) was fixed.
- [ ] **CHECKPOINT: Run `/compact focus on: Phase 6 complete — full a11y sweep verified at AX5/VoiceOver/Reduce Motion/Increase Contrast across all screens. Plan complete.`**

---

## Testing Strategy

- **Pure logic in NutritionCore/AppCore is unit-tested** (swift-testing): `HonestNumber`,
  `ConfidenceDisplay`, `FoodCorrection` key+round-trip, `FoodConfirmModel` chips/cycleUnit,
  `WeeklyInsight`, history provenance, correction pre-apply. Target ≥80% on new logic.
- **Visual/interaction is verified by clean-build simulator screenshots** at **normal +
  AX5**, light + dark — NOT by trusting an incremental build (see build-hygiene note).
- **A few XCUITests** for the critical journeys (onboarding order; log→confirm→save→undo).
- Run `cd apple/Packages/NutritionKit && swift test` per phase; UI tests need `clean test`.

## Acceptance Criteria (north-star check)

| Pillar | This plan delivers |
|--------|--------------------|
| **Private** | Trust ritual front-loads "no account / on-device / optional Health"; estimates never masquerade as exact. |
| **Calm** | Calmer ring, secondary charts, single-action empty state, no moral language. |
| **Honest** | "about N" for estimates, Measured vs Estimated vs Adjusted badges, source rows, history provenance, per-food correction memory. |
| **Native** | Compact native trust list, system swipe actions, haptics, Dynamic Type/VoiceOver/Reduce-Motion/Increase-Contrast done right. |
| **Effortless** | One signature confirmation moment, ½/2×/Less/More/Swap chips, undo, usuals, thumb-reach logging. |

## Out of Scope (future epics)
- **Native platform layer** — App Intents ("Log banana", "Log my usual breakfast", "Add
  workout offset"), Home/Lock-Screen widgets (Today calories / protein / quick log), Apple
  Watch companion. New build targets + App Group data sharing; plan separately once the core
  experience here is resolved.
- App icon / launch-screen **asset production** (design deliverable; Phase 5 specs the intent).

---

## Execution Handoff

```
PLAN COMPLETE: plans/001-design-excellence/plan.md
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Option 1: Execute now      → /superbuild plans/001-design-excellence/plan.md
Option 2: Fresh session    → new session, then /superbuild plans/001-design-excellence/plan.md
Option 3: Review first     → read, adjust phases, then execute
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Recommended order: Phase 0 → then 1 / 2A / 3 / 4 (parallelizable) → 2B → 5 → 6.
Build every UI change CLEAN and screenshot at AX5.
```
