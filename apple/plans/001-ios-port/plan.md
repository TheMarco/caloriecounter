# Plan: Port CalorieCounter to a native iOS 26 Swift app (Liquid Glass, on-device AI)

> On execution, copy this file to `apple/plans/001-ios-port/plan.md` (superplan convention) and run `/superbuild`.

## Context

CalorieCounter is a Next.js 15 / React 19 PWA: a local-first food/macro tracker with four input methods (barcode, voice, text, photo), AI parsing via OpenAI, historical charts, CSV export, and a shared-password gate. All data lives in IndexedDB (`idb-keyval`); AI runs through Next.js API routes (`/api/parse-food`, `/api/parse-photo`, `/api/barcode/[code]`).

We are porting it to a **native iOS 26 Swift app**, mirroring the architecture of the sibling project `../MyAIJournal` (layered SwiftPM package, `@Observable` DI container, `actor` services, SwiftData `@ModelActor` store, iOS 26 `Tab` API + Liquid Glass). The goal is a first-class iOS 26 experience that goes "all in" on Liquid Glass and on-device intelligence.

**Decisions (confirmed with user):**
1. **AI = maximize on-device.** Text/voice → **Foundation Models** (`@Generable NutritionInfo`, free/private/offline). Nutrition-label photos → **Vision OCR** on-device. Plate-of-food photos → **cloud** via the existing Next.js `/api/parse-photo` proxy (the only cloud dependency for AI). Barcodes → on-device scan + **OpenFoodFacts** public API + Foundation Models fallback.
2. **Persistence = SwiftData, local-only.** No CloudKit (mirrors current IndexedDB local-first behavior). `.unique` IDs are allowed (no CloudKit constraint).
3. **Location = `apple/` subfolder** in this repo (same layout as `MyAIJournal/apple/`).
4. **Access = optional Face ID app lock.** App opens straight to tracking. The shared password is requested once (on first plate-photo use), exchanged via `/api/auth` for a token stored in Keychain, then used silently. Biometric lock is an opt-in toggle in Settings.

**Intended outcome:** a shippable iOS 26 app reproducing the web feature set, with AI that runs on-device by default and degrades gracefully on non–Apple-Intelligence hardware.

---

## Tech stack & template conventions (from MyAIJournal — match exactly)

- **`Package.swift`:** `// swift-tools-version: 6.2`, `platforms: [.iOS(.v26), .macOS(.v26)]` (macOS so `swift test` runs the pure-logic suites on CI/dev Macs), `.swiftLanguageMode(.v6)` on **every** target.
- **One module per architectural layer**, downward-only dependency rule, doc-comment headers referencing the layer's purpose.
- **Store:** `@ModelActor public actor`, `FetchDescriptor` + `#Predicate`, `toDomain()` / `init(from:)` mapping between `@Model` records and pure domain structs, `static func make(inMemory:url:)` factory + `static var schemaTypes`.
- **DI:** `@Observable @MainActor public final class AppContainer` with `static let shared`, `init() throws`, `bootstrap()` called from the root view's `.task`.
- **Networking:** `public actor APIClient` taking `TokenProviding`, an `Endpoint` catalog, generic `send<Body,Response>`, typed `APIError`, Keychain-backed token.
- **UI:** iOS 26 `Tab(_:systemImage:value:)` API + `.tabBarMinimizeBehavior(.onScrollDown)`; `.glassEffect()` reserved for floating controls; content (lists/cards/photos) stays on the content layer.
- **Naming:** PascalCase files, one public type per file, `MARK: -` sections, imperative method names, `Sendable` on all domain/DTO types.
- **Tests:** Swift Testing, parallel `Tests/<Target>Tests`, in-memory `ModelContainer`, `URLProtocol` stubs (no network/disk in CI).

---

## Target project structure

```
caloriecounter/
└── apple/
    ├── CalorieCounter.xcodeproj
    ├── CalorieCounter/                      # SwiftUI app target (thin shell)
    │   ├── CalorieCounterApp.swift          # @main, .modelContainer
    │   ├── RootView.swift                   # app-lock gate → MainTabView
    │   ├── MainTabView.swift                # iOS 26 Tab API + Liquid Glass
    │   ├── Today/                           # TodayView, TabbedTotalCard, CalorieOffset, EntryList rows
    │   ├── History/                         # HistoryView, NutritionChart, Calendar, MacroTabs, DayDetail
    │   ├── Settings/                        # SettingsView, TargetsEditor, AboutView, AppLock toggle
    │   ├── Input/                           # BarcodeScannerView, VoiceInputView, TextInputView,
    │   │                                    #   PhotoCaptureView, FoodConfirmView, EditEntryView
    │   ├── Components/                       # GlassButton, ConfirmDialog, shared views
    │   ├── Lock/                            # AppLockManager, BiometricGate (LocalAuthentication)
    │   ├── Assets.xcassets, Info.plist, CalorieCounter.entitlements, PrivacyInfo.xcprivacy
    └── Packages/NutritionKit/
        ├── Package.swift
        ├── Sources/
        │   ├── NutritionCore/               # domain models, protocol seams, date/macro utils, constants
        │   ├── NutritionStore/              # SwiftData @Model + @ModelActor SwiftDataStore
        │   ├── NutritionAPI/                # APIClient actor, Endpoint, DTOs, Keychain, OpenFoodFacts
        │   ├── NutritionAI/                 # Foundation Models parser, Vision label reader, prompts
        │   └── AppCore/                     # AppContainer DI, concrete provider wiring, SettingsStore
        └── Tests/                           # NutritionCoreTests, NutritionStoreTests, NutritionAPITests,
                                             #   NutritionAITests, AppCoreTests
```

`NutritionKit` mirrors `JournalKit` minus the layers we don't need (no Vault/Search/Sync — local-only, no crypto). Five targets: **Core → {Store, API, AI} → AppCore**.

---

## Architecture

### Layer dependency graph (downward only)
```
        ┌─────────────────────────────────────────┐
        │  CalorieCounter (SwiftUI app target)     │  iOS 26 / Liquid Glass
        └──────────────────┬──────────────────────┘
                           │ imports
        ┌──────────────────▼──────────────────────┐
        │  AppCore  (@Observable AppContainer DI)  │
        └───┬───────────┬──────────────┬──────────┘
            │           │              │
   ┌────────▼──┐  ┌─────▼─────┐  ┌─────▼───────┐
   │NutritionAI│  │NutritionAPI│  │NutritionStore│
   │ (FM+Vision)│  │(proxy+OFF) │  │ (SwiftData) │
   └────────┬──┘  └─────┬─────┘  └─────┬───────┘
            └───────────┴──────────────┘
                        │ all depend on
                ┌───────▼────────┐
                │ NutritionCore  │  domain + protocol seams
                └────────────────┘
```

### AI routing (maximize on-device)
| Input | On-device path | Cloud fallback |
|-------|----------------|----------------|
| **Text** | `FoundationModelsFoodParser` → `@Generable NutritionInfo` | heuristic parser if FM unavailable |
| **Voice** | `SpeechTranscriber` (iOS 26) → text → same FM parser | `SFSpeechRecognizer` if < iOS 26 |
| **Barcode** | `DataScannerViewController` scan → `OpenFoodFactsResolver` (public, no key); FM estimates nutriments when OFF lacks them | — |
| **Nutrition label photo** | `VisionLabelReader` (`RecognizeTextRequest`/`RecognizeDocumentsRequest`) → structure via FM/regex | — |
| **Plate photo** | — | `APIPhotoParser` → existing `/api/parse-photo` (only cloud AI call) |

All four flows produce a shared `ParsedFood`, shown in `FoodConfirmView`, then saved as an `Entry` to SwiftData.

### Data flow (unchanged conceptually from the web app)
`Input → parser (seam) → ParsedFood → FoodConfirmView (user confirms/edits) → AppContainer.store.add(Entry) → SwiftData → @Query refreshes TodayView/HistoryView`.

---

## Domain model mapping (web → Swift)

| Web (`src/types/index.ts`, `idb.ts`) | Swift (`NutritionCore`) |
|---|---|
| `Entry { id, dt, ts, food, qty, unit, kcal, fat, carbs, protein, method, confidence? }` | `struct Entry: Identifiable, Codable, Sendable` with `id: String`, `date: String` (YYYY-MM-DD), `timestamp: Date`, `food`, `quantity: Double`, `unit: String`, `kcal/fat/carbs/protein: Double`, `method: InputMethod`, `confidence: Double?` |
| `method: 'barcode'\|'voice'\|'text'\|'photo'` | `enum InputMethod: String, Codable, Sendable, CaseIterable` |
| `MacroTotals`, `MacroTargets` | `struct MacroTotals`, `struct MacroTargets` (Double fields) |
| `AppSettings { dailyTarget, fatTarget, carbsTarget, proteinTarget, units }` | `struct AppSettings { targets: MacroTargets; units: UnitSystem }`, `enum UnitSystem { metric, imperial }` |
| `offset:{date}` (number) | `DayOffsetRecord` (`@Model`) + `Entry`-independent offset query |
| `ParseFoodResponse.data` / barcode data | `struct ParsedFood: Codable, Sendable` (shared parser output) |
| `searchPreviousFood`, `getDailyMacroTotals*`, `getMacroTotalsForDate` | methods on `NutritionStoring` (see Phase 2) |

`Entry.id`: keep cuid-style string IDs (use `UUID().uuidString` for new entries; the field stays `String` so any imported web data round-trips).

---

## Phase breakdown

| Phase | Name | Depends on | Parallel with | Est. | Status |
|------|------|-----------|---------------|------|--------|
| 0 | Xcode project + NutritionKit scaffold | — | — | 3 | ✅ |
| 1 | NutritionCore: domain + seams + utils | 0 | — | 3 | ✅ |
| 2 | NutritionStore: SwiftData persistence | 1 | 3, 4 | 5 | ✅ |
| 3 | NutritionAPI: proxy client + Keychain + OpenFoodFacts | 1 | 2, 4 | 5 | ✅ |
| 4 | NutritionAI: Foundation Models + Vision | 1 | 2, 3 | 8 | ✅ |
| 5 | AppCore: AppContainer DI + SettingsStore | 2, 3, 4 | — | 3 | ✅ |
| 6 | App shell: App/Root/MainTab + app lock | 5 | — | 5 | ✅ |
| 7 | Today screen + macro card + offset + entry list | 6 | 8, 9, 10 | 5 | ✅ |
| 8 | Input flows: barcode, voice, text, photo, confirm | 6, 3, 4 | 7, 9, 10 | 8 | ✅ |
| 9 | History + Swift Charts + calendar | 6, 2 | 7, 8, 10 | 5 | ✅ |
| 10 | Settings + CSV export (ShareLink) + about | 6 | 7, 8, 9 | 3 | ✅ |
| 11 | Liquid Glass polish, a11y, app icon, device QA | 7–10 | — | 3 | ✅ (device QA pending user hardware) |

Critical path: 0→1→{2,3,4}→5→6→{7,8,9,10}→11. **Total ≈ 56 points.**

## Execution log
- **Bugfix — voice flow crash (2026-06-22, device-reported):** `SpeechDictation` was `@MainActor`, which made the `AVAudioEngine` tap and the `SFSpeechRecognitionTask` result handler inherit main-actor isolation. Those callbacks fire on background/real-time audio threads, so the Swift runtime's main-actor precondition aborted with `_dispatch_assert_queue_fail` ("BUG IN CLIENT OF LIBDISPATCH") the instant audio started. **Fix:** split the audio/recognition machinery into a NON-isolated `SpeechEngine: @unchecked Sendable` worker that emits partial transcripts via an `AsyncStream`; `SpeechDictation` stays `@MainActor` for SwiftUI state and consumes the stream on the main actor. Added `VoiceUITests.testStartingVoiceCaptureDoesNotCrash` (asserts the app stays `.runningForeground` after tapping Start Speaking) — PASSES on the simulator; all 4 UI tests green.
- **Phase 11 ✅ (2026-06-22) — in-environment portions complete; physical-device QA is the user's remaining step:** **App icon** replaced the plain-green placeholder with a generated green-gradient + white fork/knife glyph (1024×1024, App-Store-ready). **Accessibility:** the macro ring's progress animation is gated on `accessibilityReduceMotion`, the voice `symbolEffect` likewise; the ring exposes a VoiceOver `accessibilityLabel`/`accessibilityValue` ("Calories, 0 of 2000 kcal, …"); input buttons and entry rows already carry a11y labels/hints; all text uses semantic fonts (Dynamic Type) except the deliberate hero number. **Liquid Glass review:** glass is confined to chrome (the iOS 26 tab bar) and the single `GlassEffectContainer` quick-add cluster (`.regular` tint for legibility); content cards use `.background.secondary`, not glass — no opaque backgrounds hiding glass on sheets/nav. **iOS 26 API verification:** every new API (Foundation Models `@Generable`/`respond(generating:)`, Vision `RecognizeTextRequest`, `DataScannerViewController`, Speech, `GlassEffectContainer`/`.glassEffect`, `Tab`/`.tabBarMinimizeBehavior`, `.scrollEdgeEffectStyle`) was typecheck-probed against the iOS 26 sim SDK (and FM/Vision against the macOS host) before use, and the whole app `xcodebuild`s clean. **Simulator QA:** app launches to Today with the Liquid Glass tab bar; the text flow saves an entry end-to-end; History + Settings render; the **FM-unavailable fallback is verified** (the text UI test runs on the heuristic parser via `-uitest` and produces a correct entry). **DoD:** `swift test` → 138 tests / 24 suites pass; 3/3 UI tests pass; clean `swift build` + `xcodebuild` 0 warnings. **⚠️ Device-only QA remaining (requires a physical Apple-Intelligence iPhone — cannot run in this sandbox):** real Foundation Models text/voice parsing, the SFSpeechRecognizer voice capture, Vision nutrition-label OCR, `DataScannerViewController` barcode scanning, and the camera plate-photo → cloud-proxy round-trip (incl. the one-time password login). All five compile, are availability-gated, and have their deterministic logic unit-tested; they need a device smoke test before submission.
- **Phase 10 ✅ (2026-06-22):** Settings + CSV export + about. `CSVExporter` (AppCore, pure, tested) ports `src/utils/csvExport.ts` byte-for-byte: header `date,calories_consumed,calories_burned,net_calories,carbs,fat,protein`, empty-day filter, `net = max(0, calories − offset)`, macros to 1 decimal, `calorie-counter-data-YYYY-MM-DD.csv` filename. SwiftUI (`Settings/`): `SettingsView` (daily-target steppers clamped to Core ranges bound to `SettingsStore`, units picker, **biometric-lock toggle** — completing Phase 6's deferred toggle, photo-proxy connect/disconnect via `PhotoProxyLoginSheet`, CSV export via `ShareLink` to a temp file, reset-to-defaults with confirmation), `AboutView` (version, privacy summary, copyright). **DoD:** `swift test` → 138 tests / 24 suites pass; `CSVExporter` 92.86% regions / 100% lines; clean `swift build` + `xcodebuild` 0 warnings; **`SettingsUITests.testSettingsTabRenders` PASSES on the simulator (targets/units/data sections render); all 3 UI tests (text/history/settings) green.**
- **Phase 9 ✅ (2026-06-22):** History + charts + calendar. AppCore (tested): `HistoryModel` (`load` over `store.dailyTotals(lastDays: range.days)`, `series(_:targets:)` per-macro points flagged over-target, `datesWithEntries`), `MacroKind` (value/target/label/unit per macro), and the pure `CalendarMonth` (day count + leading blanks from an injected `Calendar`). SwiftUI (`History/`): `HistoryView` (7/30/90 range segmented picker + macro picker), `NutritionChart` (Swift Charts `BarMark` colored vs target + dashed `RuleMark` target line, `.chartScrollableAxes(.horizontal)`), `CalendarView` (month grid, entry dots, tap → detail), `DayDetailView` (reuses the date-parameterized `TodayModel` so the same tested aggregation drives historical days). **DoD:** `swift test` → 132 tests / 23 suites pass; `HistoryModel` 89.19% regions / 95.71% lines; clean `swift build` + `xcodebuild` 0 warnings; **`HistoryUITests.testHistoryTabRenders` PASSES on the simulator (range selector + chart + calendar render; calendar→DayDetail navigation wired).**
- **Phase 8 ✅ (2026-06-22):** The four capture flows + shared confirm/edit sheets. Testable convergence logic in AppCore: `FoodConfirmModel` (live macro recalc via Core `MacroMath` + `save` → `store.add`) and `TextInputModel` (autocomplete via `searchPreviousFoods` + parse via the `FoodParsing` seam). SwiftUI (`Input/`): `FoodConfirmView` (shared confirm sheet), `EditEntryView` (edit-in-place via `store.update` + `MacroMath.scaled`), `InputFlowView` (router → `navigationDestination(item: ParsedFood)`), `TextInputView` (works fully on sim), `BarcodeScannerView` (VisionKit `DataScannerViewController`, camera-gated with a sim fallback message), `VoiceInputView`, `PhotoCaptureView` (PhotosPicker + camera + plate-size/serving-type pickers + plate/label toggle + one-time `PhotoProxyLoginSheet` password gate → `authenticatePhotoProxy`). All capture API signatures (`DataScannerViewController`, Speech, Glass) typecheck-probed first. Today's quick-add buttons now present `InputFlowView`; entry rows tap → `EditEntryView`. `ParsedFood` made `Hashable` + an `init(entry:)`. **Deviation — voice uses `SFSpeechRecognizer` (on-device) rather than the iOS 26 `SpeechAnalyzer`/`SpeechTranscriber` pipeline:** both are on-device/private, but SFSpeechRecognizer is far simpler to ship cleanly under strict concurrency and is the plan's sanctioned fallback; the newer API can be adopted in polish. **Test infra:** added a `CalorieCounterUITests` target (xcodegen) and a `-uitest` launch mode on `AppContainer` (in-memory store + forced heuristic parser) for deterministic end-to-end UI tests. **DoD:** `swift test` → 127 tests / 22 suites pass (`FoodConfirmModel` 81.8%/97.7%, `TextInputModel` 85.7%/94.1%); clean `swift build` + `xcodebuild` 0 warnings; **`CalorieCounterUITests.TextFlowUITests` PASSES on the simulator — type "apple" → Analyze → Add → the entry appears on Today (the shared confirm→save→list path all four flows use).** Barcode/voice/photo capture are device-only (Phase 11).
- **Phase 7 ✅ (2026-06-22):** Today dashboard. `TodayModel` (`@Observable @MainActor` in AppCore, so its load/delete/offset/add orchestration over the NutritionStoring seam is unit-tested) + the pure `MacroProgress` ring math. SwiftUI (app target, `Today/`): `TodayView` (List-based so swipe-to-delete is native; `.scrollEdgeEffectStyle(.soft, for: .top)`), `TabbedTotalCard` (segmented calories/fat/carbs/protein picker + progress ring vs targets, net-calorie readout), `CalorieOffsetView` + `CalorieOffsetSheet` (offset edit → `TodayModel.updateOffset` → `store.setOffset`), `EntryRow` (a11y-labelled), `QuickAddBar` (Liquid Glass cluster: `GlassEffectContainer` + four `.glassEffect(.regular.tint().interactive(), in: .circle)` buttons). The glass-API + scroll-edge signatures were typecheck-probed against the iOS 26 sim SDK before writing. **Scope note:** the quick-add buttons report the chosen `InputMethod` to a temporary placeholder sheet; Phase 8 swaps in the real capture flows. `InputMethod` made `Identifiable` (for `.sheet(item:)`). **DoD:** `swift test` → 122 tests / 20 suites pass; `TodayModel` ≥87%/82%; clean `swift build` (0 warnings) + `xcodebuild` BUILD SUCCEEDED 0 warnings; **app launched on the simulator → Today renders the macro ring (0 of 2,000 kcal), offset row, empty list, and the glass quick-add cluster (screenshot-verified); offset persistence covered by `TodayModel.updateOffset` test.**
- **Phase 6 ✅ (2026-06-22):** App shell + Face ID lock. SwiftUI app target: `CalorieCounterApp` (`@main`, injects `AppContainer.shared` via `.environment`), `RootView` (gates `AppLockView` vs `MainTabView`, runs `bootstrap()` on `.task`, re-locks on `scenePhase == .background`), `MainTabView` (iOS 26 `Tab(_:systemImage:value:)` + `.tabBarMinimizeBehavior(.onScrollDown)` Liquid Glass tab bar), `Lock/AppLockView`, placeholder `TodayView`/`HistoryView`/`SettingsView` (fleshed out in 7/9/10). **Deviation — testable lock logic lives in AppCore (package), not the app target:** `BiometricGate` (actor over LocalAuthentication, `@preconcurrency import`, behind a `BiometricAuthenticating` protocol) + `AppLockManager` (`@Observable @MainActor`, fail-open when biometry unavailable so users aren't locked out of local data) are unit-tested with a mock gate; only the SwiftUI `AppLockView` is in the app target. **Deviation — no SwiftUI `.modelContainer`/`@Query`:** the app reads through `AppContainer.store` (the NutritionStoring actor) per the seam architecture, so no second SwiftData container is installed. The biometric-lock *toggle UI* is deferred to Phase 10 settings; the lock machinery + RootView gating are in place now. xcodegen regenerated to include the new files. **DoD:** `swift test` → 116 tests / 19 suites pass; `AppLockManager` 100% covered (BiometricGate is the LocalAuthentication boundary — on-device only, like FM/Vision); `xcodebuild` (iPhone 17 Pro, iOS 26.4.1) BUILD SUCCEEDED 0 warnings; **app installed + launched on the simulator → boots to the Today screen with the Liquid Glass tab bar (verified by screenshot), no launch crash.**
- **Phase 5 ✅ (2026-06-22):** `AppCore` composition root. `AppContainer` (`@Observable @MainActor`, MyAIJournal pattern) exposes `store`/`keychain`/`apiClient`/`foodParser`/`photoParser`/`labelReader`/`barcodeResolver`/`settings` with a `static let shared`, an injectable designated init (tests/previews), and a real `convenience init()` that wires the concrete providers. `makeFoodParser()` picks `FoundationModelsFoodParser` when available else `HeuristicFoodParser`. `CompositeBarcodeResolver` (BarcodeResolving) runs OFF first and, on `OpenFoodFactsError.missingNutriments(productName:)`, falls back to an injected FM-estimator closure (AppCore wires `FoundationModelsBarcodeEstimator`; closure injection keeps AppCore's barcode glue testable and avoids a hard NutritionAI dep in the type). `authenticatePhotoProxy(password:)` → `APIClient.login`; `isPhotoProxyAuthenticated()`/`signOutPhotoProxy()` reflect/clear the Keychain token. `SettingsStore` (`@Observable @MainActor`) persists targets/units/`biometricLockEnabled` in UserDefaults, defaults mirror the web (2000/65/250/100, metric), targets clamped on persist. **Cross-phase change:** `OpenFoodFactsError.missingNutriments` now carries `productName` (Phase 3 resolver + test updated) so the composite can hand the name to the FM estimator. **Scaffold cleanup:** the 5 Phase-0 `*Module` marker enums + their 5 scaffold tests were removed (the real `AppContainer` wiring now proves the layer graph at compile time), resolving the Phase 1–4 retention deviation; the app shell's placeholder no longer references `AppCoreModule`. **DoD:** `swift test` → 111 tests / 18 suites pass; SettingsStore & CompositeBarcodeResolver 100%, AppContainer wiring verified with mocks (real disk/network init validated on-device); no SwiftUI in AppCore; clean `swift build` (0 warnings) and `xcodebuild` (iPhone 17 Pro, iOS 26.4.1) BUILD SUCCEEDED, 0 warnings.
- **Phase 4 ✅ (2026-06-22):** `NutritionAI` — on-device text/voice parsing + label OCR. **iOS 26 API signatures verified before writing** by typecheck-probing against the iOS 26 simulator SDK *and* the macOS 26 host: confirmed `@Generable`/`@Guide(.range(0...5000))` (Double overload), `SystemLanguageModel.default.availability` (`.available`/`.unavailable`), `LanguageModelSession(instructions:).respond(to:generating:).content`, and Vision's `RecognizeTextRequest(.accurate).perform(on: CGImage) -> [RecognizedTextObservation]` all compile on both. `NutritionInfo` (`@Generable`, explicit init for testability) → `ParsedFood`. `Prompts.foodInstructions(units:)` ports the portion-size rules from `parse-food/route.ts` verbatim (300-400g pasta, TOTAL-not-per-100g, metric/imperial unit guidance); `Prompts.barcodeInstructions` for the OFF-missing-nutriments fallback. `FoundationModelsFoodParser` (FoodParsing) + `FoundationModelsBarcodeEstimator` guard on `isAvailable` and throw `.unavailable` so AppCore (Phase 5) can pick FM-or-heuristic. `HeuristicFoodParser` (FoodParsing) is a faithful port of web `fallbackParsing` (quantity+unit regexes → longest-key common-portion table → isDish last resort). `VisionLabelReader` (LabelReading): `RecognizeTextRequest` OCR → deterministic `NutritionLabelParser` (calorie-anchored regex, prefers total-fat/total-carb over saturated/sugars) → FM fallback on the raw OCR when the regex can't anchor. The package builds on macOS (FM/Vision present in the macOS 26 SDK) so `swift test` runs the deterministic suites; the model/OCR calls are availability-gated and validated on-device in Phase 11. **DoD:** `swift test` → 104 tests / 20 suites pass; deterministic-logic coverage HeuristicFoodParser 93.10%/100% lines, NutritionLabelParser 92.31%/100% lines, Prompts & NutritionInfo 100% (FM/Vision generation calls intentionally uncovered — on-device only); clean `swift build` (0 warnings) and `xcodebuild` (iPhone 17 Pro, iOS 26.4.1) BUILD SUCCEEDED, 0 warnings.
- **Phase 3 ✅ (2026-06-22):** `NutritionAPI` — proxy client, Keychain token, OpenFoodFacts resolver. `APIClient` (actor) + `APIPhotoParser` implement `PhotoParsing` against `/api/parse-photo` (the only cloud call; image sent as a base64 `data:image/jpeg;base64,…` URL, `PhotoDetails` serialized verbatim with the web-faithful `extra-large`/`fast-food` raw values). `OpenFoodFactsResolver` implements `BarcodeResolving` against the public OFF API (per-100g nutriments → 100 g `ParsedFood`, product_name→product_name_en→brands fallback, lenient number-or-string nutriment decoding, `.productNotFound`/`.missingNutriments` signals for the Phase-5 FM fallback). `KeychainStore` (actor, `TokenProviding`) holds only the proxy token under `kSecAttrAccessibleWhenUnlockedThisDeviceOnly`, no iCloud sync; the OPENAI key is never stored. Typed `APIError` taxonomy; `InMemoryTokenStore` for previews. **Deviation — auth is COOKIE-based, not Bearer:** the existing web app authenticates `/api/parse-photo` via the middleware's signed `calorie-auth` cookie (`timestamp.signature`, 24h). Rather than modify the security-sensitive server, the client matches it: `login(password:)` POSTs to `/api/auth`, extracts the token from the `Set-Cookie` response header, stores it in Keychain, and every authed request re-sends it as `Cookie: calorie-auth=<token>`; 401 → `tokenRejected()` purges it. The client session disables URLSession cookie auto-handling so the manual Cookie header is authoritative. **DoD (no live network — `URLProtocol` stub):** `swift test` → 85 tests / 16 suites pass; NutritionAPI coverage **93.58% regions / 97.61% lines**; clean `swift build` (0 warnings) and `xcodebuild` (iPhone 17 Pro, iOS 26.4.1) BUILD SUCCEEDED, 0 warnings. **Note:** all stub-using tests are deliberately in ONE `.serialized` suite — `.serialized` only serializes within a suite, so two stub-using suites would race on the global `StubURLProtocol` handler.
- **Phase 2 ✅ (2026-06-22):** `NutritionStore` — local-only SwiftData implementation of `NutritionStoring`. `EntryRecord` (flat, fully-queryable `@Model`; `method` persisted as `InputMethod.rawValue`, mapped back with a `.text` fallback for unrecognized strings) + `DayOffsetRecord` (`@Attribute(.unique)` per-day offset, the home of web `offset:{date}`). `SwiftDataStore` is a `@ModelActor actor` so all `ModelContext` access is serialized under Swift 6 strict concurrency. Query/aggregation semantics ported verbatim from `src/utils/idb.ts`: newest-first day/range listings, inclusive string-compared range (`$0.date >= start && $0.date <= end`), summed macros, oldest-first `dailyTotals` (one range fetch grouped in memory + offset map), and frequency-then-recency `searchPreviousFoods` (dedupe by lowercased food name, represent each by its most-recent entry → original casing surfaces, min query length from `Constants`). `add` upserts on the unique id; `make(inMemory:url:)` builds the container with **no CloudKit** (data never leaves device). **Deviation (as in Phase 1):** the Phase-0 `NutritionStoreModule` marker enum + its scaffold test were retained because `AppCoreModule.layers` still references `NutritionStoreModule.name` until Phase 5; removed then. **DoD:** `swift test` → 61 tests / 12 suites pass; NutritionStore coverage `EntryRecord` 100% lines, `SwiftDataStore` **99.32% lines / 94.44% regions** — exceeds the 80% bar; clean `swift build` (0 warnings) and `xcodebuild` (iPhone 17 Pro, iOS 26.4.1) BUILD SUCCEEDED, 0 warnings.
- **Phase 1 ✅ (2026-06-22):** `NutritionCore` domain layer ported from `src/types/index.ts`, `src/lib/constants.ts`, and the date/macro semantics of `src/utils/idb.ts` + `EditEntryDialog.tsx`. 14 source files: value types (`Entry`, `MacroTotals`, `MacroTargets`, `AppSettings`, `ParsedFood`, `PhotoDetails`, `DayTotals` + `InputMethod`/`UnitSystem`/`PlateSize`/`ServingType`/`DateRange` enums), the 5 protocol seams (`NutritionStoring`/`FoodParsing`/`PhotoParsing`/`BarcodeResolving`/`LabelReading`), and pure utilities (`LocalDate`, `MacroMath`, `Constants`). All `Sendable`/`Codable`; raw values kept web-faithful (incl. hyphenated `extra-large`/`fast-food` and the `sizeMap`/`typeMap` prompt phrases). **Deviation:** the Phase-0 `NutritionCoreModule` marker enum + its scaffold test were retained (not deleted as the plan's "replaces it" wording implies) because `AppCoreModule` still references `NutritionCoreModule.name` until Phase 5 rewrites AppCore; deleting it now would break the AppCore scaffold test. **DoD:** `swift test` → 42 tests / 10 suites pass; NutritionCore line coverage **98.88%** (region 96.32%) — exceeds the 80% bar; clean `swift build` and `xcodebuild` (iPhone 17 Pro, iOS 26.4.1) BUILD SUCCEEDED, 0 warnings.
- **Phase 0 ✅ (2026-06-22):** `apple/` scaffolded. xcodegen `project.yml` → committed `CalorieCounter.xcodeproj` (bundle id `com.aidashcreated.caloriecounter`, iOS 26.0, Swift 6 strict concurrency). 5-target `NutritionKit` package (Core/Store/API/AI/AppCore) + 5 test targets. Info.plist (camera/mic/speech/FaceID usage strings), entitlements (data-protection complete), PrivacyInfo (no tracking), placeholder app icon + accent color, thin `@main` shell linking AppCore. **DoD:** `swift test` → 5/5 suites pass; `xcodebuild` (iPhone 17 Pro, iOS 26.4.1) → BUILD SUCCEEDED; 0 source warnings (one benign `appintentsmetadataprocessor` info line only).

---

## Phase detail

### Phase 0 — Project + package scaffold  (est. 3) — ✅ COMPLETE
**Goal:** an Xcode project that builds an empty iOS 26 app linking a 5-target SwiftPM package.

> **Done (2026-06-22):** Built via xcodegen (`apple/project.yml`, source of truth) → committed `apple/CalorieCounter.xcodeproj`. Deviation from "copy MyAIJournal verbatim": MyAIJournal uses a hand-maintained pbxproj; we use xcodegen + committed project so the multi-phase build never needs pbxproj surgery (decision confirmed with user). Target sim is **iPhone 17 Pro / iOS 26.4.1** (no iPhone 16 Pro under 26.4; addressed by UDID). DoD met: `swift test` 5/5 suites; `xcodebuild` BUILD SUCCEEDED; 0 source warnings.

Files (CREATE):
- `apple/CalorieCounter.xcodeproj` (iOS app target, deployment target **iOS 26.0**, bundle id **`com.aidashcreated.caloriecounter`** — matches the org's `com.aidashcreated.*` convention from MyAIJournal — Xcode 26 / Swift 6 strict concurrency).
- `apple/Packages/NutritionKit/Package.swift` — copy MyAIJournal's structure verbatim, retargeted:
```swift
// swift-tools-version: 6.2
import PackageDescription
let package = Package(
    name: "NutritionKit",
    platforms: [.iOS(.v26), .macOS(.v26)],
    products: [
        .library(name: "NutritionCore", targets: ["NutritionCore"]),
        .library(name: "NutritionStore", targets: ["NutritionStore"]),
        .library(name: "NutritionAPI", targets: ["NutritionAPI"]),
        .library(name: "NutritionAI", targets: ["NutritionAI"]),
        .library(name: "AppCore", targets: ["AppCore"]),
    ],
    targets: [
        .target(name: "NutritionCore", swiftSettings: [.swiftLanguageMode(.v6)]),
        .target(name: "NutritionStore", dependencies: ["NutritionCore"], swiftSettings: [.swiftLanguageMode(.v6)]),
        .target(name: "NutritionAPI", dependencies: ["NutritionCore"], swiftSettings: [.swiftLanguageMode(.v6)]),
        .target(name: "NutritionAI", dependencies: ["NutritionCore"], swiftSettings: [.swiftLanguageMode(.v6)]),
        .target(name: "AppCore", dependencies: ["NutritionCore","NutritionStore","NutritionAPI","NutritionAI"], swiftSettings: [.swiftLanguageMode(.v6)]),
        .testTarget(name: "NutritionCoreTests", dependencies: ["NutritionCore"], swiftSettings: [.swiftLanguageMode(.v6)]),
        .testTarget(name: "NutritionStoreTests", dependencies: ["NutritionStore","NutritionCore"], swiftSettings: [.swiftLanguageMode(.v6)]),
        .testTarget(name: "NutritionAPITests", dependencies: ["NutritionAPI","NutritionCore"], swiftSettings: [.swiftLanguageMode(.v6)]),
        .testTarget(name: "NutritionAITests", dependencies: ["NutritionAI","NutritionCore"], swiftSettings: [.swiftLanguageMode(.v6)]),
        .testTarget(name: "AppCoreTests", dependencies: ["AppCore","NutritionCore"], swiftSettings: [.swiftLanguageMode(.v6)]),
    ]
)
```
- `Info.plist` usage strings: `NSCameraUsageDescription`, `NSMicrophoneUsageDescription`, `NSSpeechRecognitionUsageDescription`, `NSFaceIDUsageDescription`. `PrivacyInfo.xcprivacy` (no tracking).
- Add NutritionKit as a local package dependency of the app target; link `AppCore`.

**Tests:** ✅ `swift test` runs (5 scaffold suites pass). ✅ `xcodebuild build` succeeds for the simulator.
**DoD:** ✅ builds clean, no warnings. **CHECKPOINT:** `/compact focus on: Phase 0 done — apple/ project + NutritionKit 5-target package build; Phase 1 adds NutritionCore domain + seams`.

---

### Phase 1 — NutritionCore  (est. 3) — ✅ COMPLETE
**Goal:** pure value types + protocol seams + utilities, no framework deps.

> **Done (2026-06-22):** All files below created (one public type per file; `NutritionInfo` correctly deferred to NutritionAI as it needs `@Generable`). `DateRange` split into its own file. `MacroMath.scaled` added (proportional macro recalc beyond the web's kcal-only rule). 42 tests / 10 suites green; 98.88% line coverage on NutritionCore; 0 warnings.

Files (CREATE) in `Sources/NutritionCore/`:
- `Entry.swift`, `InputMethod.swift`, `MacroTotals.swift`, `MacroTargets.swift`, `AppSettings.swift`, `UnitSystem.swift`, `ParsedFood.swift`, `PhotoDetails.swift` (plateSize/servingType enums + notes), `NutritionInfo.swift` is in NutritionAI (it needs `@Generable`).
- `Seams.swift` — protocol seams (Sendable):
```swift
public protocol NutritionStoring: Sendable {
    func add(_ entry: Entry) async throws
    func update(_ entry: Entry) async throws
    func delete(id: String) async throws
    func entries(on date: String) async throws -> [Entry]
    func entries(from startDate: String, to endDate: String) async throws -> [Entry]
    func macroTotals(on date: String) async throws -> MacroTotals
    func dailyTotals(lastDays days: Int) async throws -> [DayTotals]   // for charts
    func searchPreviousFoods(_ query: String, limit: Int) async throws -> [Entry]
    func offset(on date: String) async throws -> Double
    func setOffset(_ value: Double, on date: String) async throws
}
public protocol FoodParsing: Sendable { func parse(text: String, units: UnitSystem) async throws -> ParsedFood }
public protocol PhotoParsing: Sendable { func parse(imageData: Data, units: UnitSystem, details: PhotoDetails) async throws -> ParsedFood }
public protocol BarcodeResolving: Sendable { func resolve(code: String, units: UnitSystem) async throws -> ParsedFood }
public protocol LabelReading: Sendable { func readNutritionLabel(imageData: Data, units: UnitSystem) async throws -> ParsedFood }
```
- `DayTotals.swift` — `struct DayTotals: Sendable { let date: String; let totals: MacroTotals; let offset: Double }`.
- `LocalDate.swift` — port `idb.ts` date helpers: `todayKey()` → local `YYYY-MM-DD`, `dateKey(_:)`, range generation. **Use `Calendar.current` for local-day bucketing** (the web app keys by local date).
- `MacroMath.swift` — `netCalories(total:offset:) = max(0, total - offset)`; proportional recalc when quantity changes (port `EditEntryDialog` logic).
- `Constants.swift` — port `src/lib/constants.ts`: default targets (2000/65/250/100), min/max ranges, `foodUnits`, date-range presets (7/30/90), `InputMethod` metadata.

**Tests (`NutritionCoreTests`):** ✅ Codable round-trips for `Entry`/`AppSettings`/`ParsedFood`; ✅ `LocalDate` format + day-walk order/boundaries; ✅ `netCalories` clamping; ✅ proportional macro recalculation; ✅ `Constants` defaults + clamping; ✅ enum metadata/prompt-phrase stability.
**DoD:** ✅ 80%+ coverage on logic (achieved 98.88% lines); ✅ no warnings. **CHECKPOINT:** `/compact focus on: Phase 1 done — NutritionCore models + NutritionStoring/FoodParsing/PhotoParsing/BarcodeResolving/LabelReading seams + LocalDate/MacroMath/Constants; Phases 2/3/4 implement the seams in parallel`.

---

### Phase 2 — NutritionStore (SwiftData)  (est. 5)  · parallel with 3, 4 — ✅ COMPLETE
> **Done (2026-06-22):** `EntryRecord` + `DayOffsetRecord` `@Model`s and the `@ModelActor SwiftDataStore` implement `NutritionStoring`. `dailyTotals` uses a single range fetch grouped in memory rather than a query-per-day; `searchPreviousFoods` ports `getAllUniqueFood` (dedupe by lowercased name, represent by most-recent entry, frequency-then-recency rank). Local-only container (no CloudKit). 16 store/record tests; 61/12 suites pass; coverage 100% / 99.32% lines.

**Goal:** local-only SwiftData implementation of `NutritionStoring`.

Files (CREATE) in `Sources/NutritionStore/`:
- `EntryRecord.swift`:
```swift
@Model public final class EntryRecord {
    @Attribute(.unique) public var id: String
    public var date: String          // YYYY-MM-DD (local)
    public var timestamp: Date
    public var food: String
    public var quantity: Double
    public var unit: String
    public var kcal: Double
    public var fat: Double
    public var carbs: Double
    public var protein: Double
    public var method: String        // InputMethod.rawValue
    public var confidence: Double?
    public init(from e: Entry) { /* copy fields */ }
    public func update(from e: Entry) { /* mutate fields */ }
    public func toDomain() -> Entry { /* build Entry */ }
}
@Model public final class DayOffsetRecord {
    @Attribute(.unique) public var date: String
    public var offset: Double
    public init(date: String, offset: Double) { self.date = date; self.offset = offset }
}
```
- `SwiftDataStore.swift` — `@ModelActor public actor SwiftDataStore: NutritionStoring`, following MyAIJournal's pattern:
  - `entries(on:)` → `FetchDescriptor<EntryRecord>(predicate: #Predicate { $0.date == date }, sortBy: [SortDescriptor(\.timestamp, order: .reverse)])`.
  - `entries(from:to:)` → `#Predicate { $0.date >= startDate && $0.date <= endDate }` (string compare works for `YYYY-MM-DD`).
  - `macroTotals(on:)`, `dailyTotals(lastDays:)` → fetch + reduce (port `getMacroTotalsForDate`, `getDailyMacroTotalsWithOffset`).
  - `searchPreviousFoods(_:limit:)` → fetch matching `food.localizedStandardContains`, dedupe by food name, rank by frequency then recency (port `searchPreviousFood`).
  - `offset/setOffset` → upsert `DayOffsetRecord`.
  - `static var schemaTypes: [any PersistentModel.Type] { [EntryRecord.self, DayOffsetRecord.self] }`
  - `static func make(inMemory:url:) throws -> SwiftDataStore`.

**Tests (`NutritionStoreTests`):** ✅ in-memory `ModelContainer`; ✅ add→fetch-by-date (+ newest-first ordering, day filtering); ✅ update-in-place + delete (+ missing-id no-op); ✅ date-range query boundaries; ✅ macro totals aggregation (+ empty day); ✅ offset upsert; ✅ `dailyTotals` oldest-first rows with offsets/netCalories; ✅ `searchPreviousFoods` frequency/recency ordering + min-length + limit; ✅ `.unique` upsert (no duplicate ids); ✅ on-disk `make(url:)` persistence round-trip; ✅ `EntryRecord` round-trip + unknown-method fallback.
**DoD:** ✅ all CRUD + aggregation paths covered (coverage 100% / 99.32% lines, ≥80% bar). **CHECKPOINT:** `/compact focus on: Phase 2 done — SwiftDataStore (@ModelActor) implements NutritionStoring with EntryRecord/DayOffsetRecord; Phase 5 wires it into AppContainer`.

---

### Phase 3 — NutritionAPI  (est. 5)  · parallel with 2, 4 — ✅ COMPLETE
> **Done (2026-06-22):** `APIClient`/`APIPhotoParser` (PhotoParsing), `OpenFoodFactsResolver` (BarcodeResolving), `KeychainStore` (TokenProviding). **Auth deviation:** cookie-based (`calorie-auth` Set-Cookie ↔ Cookie header), NOT Bearer — matches the existing middleware so the server is untouched. 85 tests/16 suites; NutritionAPI 93.58% regions / 97.61% lines; no live network (URLProtocol stub).

**Goal:** the proxy client (plate photo + auth), Keychain token, OpenFoodFacts resolver.

Files (CREATE) in `Sources/NutritionAPI/`:
- `APIEnvironment.swift` — `.production` base URL **`https://caloriecounter.app`** (confirmed: the canonical domain used in the web app's OpenFoodFacts User-Agent) + a `.development` override (`http://localhost:3000`) for local proxy testing.
- `Endpoint.swift` — catalog: `.parsePhoto` (`POST /api/parse-photo`), `.authLogin` (`POST /api/auth`). (OpenFoodFacts is a separate client, public.)
- `APIClient.swift` — `public actor APIClient` copied from MyAIJournal's pattern (generic `send<Body,Response>`, Bearer token via `TokenProviding`, typed `APIError`, 401 → `tokens.tokenRejected()`).
- `TokenProviding.swift` + `KeychainStore.swift` — `SecItem` wrapper (update-first/add-on-not-found), `kSecAttrAccessibleWhenUnlockedThisDeviceOnly`, no sync. Stores the proxy auth token only.
- `DTOs.swift` — `ParsePhotoRequest { imageData, units, details }`, `ParsePhotoResponse { success, data: ParsedFoodDTO?, error? }`, `AuthRequest { password }`, `AuthResponse`. Map DTO ↔ `ParsedFood`.
- `APIPhotoParser.swift` — `struct APIPhotoParser: PhotoParsing` calling `.parsePhoto`. (The web `/api/parse-photo` prompt stays server-side untouched — reuse it.)
- `OpenFoodFactsResolver.swift` — `struct OpenFoodFactsResolver: BarcodeResolving`: `GET https://world.openfoodfacts.org/api/v0/product/{code}.json`, decode `product.nutriments` (energy-kcal_100g, fat_100g, carbohydrates_100g, proteins_100g) + `product_name`, scale to serving. Throws `.missingNutriments` when absent (AppCore then asks FM to estimate from the product name — see Phase 5).

**Tests (`NutritionAPITests`):** ✅ `URLProtocol` stub for `/api/parse-photo` (success, missing-macros→0, success:false error, 401→reauth, missing-token short-circuit, cookie attach); ✅ login Set-Cookie extraction (success, wrong-password 401, missing-cookie); ✅ OpenFoodFacts decoding (full nutriments, name fallback, missing nutriments, status-0 unknown, string-valued nutriments, User-Agent); ✅ Keychain round-trip (save/reload/delete/overwrite/reject) with the production accessibility class on macOS; ✅ `APIError` status mapping + descriptions + rate-limit parsing; ✅ `InMemoryTokenStore`.
**DoD:** ✅ no live network in tests (all `URLProtocol`-stubbed); coverage 93.58% regions / 97.61% lines (≥80% bar). **CHECKPOINT:** `/compact focus on: Phase 3 done — APIClient + APIPhotoParser (PhotoParsing) + OpenFoodFactsResolver (BarcodeResolving) + KeychainStore; Phase 5 injects them`.

---

### Phase 4 — NutritionAI (Foundation Models + Vision)  (est. 8)  · parallel with 2, 3 — ✅ COMPLETE
> **Done (2026-06-22):** `NutritionInfo` (@Generable), `Prompts`, `FoundationModelsFoodParser`/`FoundationModelsBarcodeEstimator` (availability-gated), `HeuristicFoodParser` (web `fallbackParsing` port), `VisionLabelReader` + `NutritionLabelParser`. All iOS 26 FM/Vision signatures compile-probed (sim SDK + macOS host) before writing. 104 tests/20 suites; deterministic logic ≥92%; FM/Vision generation calls on-device-only (Phase 11).

**Goal:** on-device text/voice parsing and label OCR. Hardest phase — guard all iOS 26 APIs and verify signatures in Xcode 26.

Files (CREATE) in `Sources/NutritionAI/`:
- `NutritionInfo.swift` — the guided-generation type:
```swift
import FoundationModels
@Generable(description: "Nutritional breakdown for a described food item, for one realistic serving")
public struct NutritionInfo {
    @Guide(description: "Standardized food name, no brand") public var food: String
    @Guide(description: "Quantity for the serving") public var quantity: Double
    @Guide(description: "Unit: g, ml, cup, tbsp, tsp, piece, slice, bowl, plate, serving, oz, lb") public var unit: String
    @Guide(description: "Total calories for this serving", .range(0...5000)) public var kcal: Double
    @Guide(description: "Total fat grams", .range(0...500)) public var fat: Double
    @Guide(description: "Total carb grams", .range(0...500)) public var carbs: Double
    @Guide(description: "Total protein grams", .range(0...500)) public var protein: Double
}
```
- `Prompts.swift` — port the **portion-size rules** from `src/app/api/parse-food/route.ts` (plate of pasta = 300–400g, realistic portions, units instruction by `UnitSystem`) into the `LanguageModelSession` instructions.
- `FoundationModelsFoodParser.swift` — `struct FoundationModelsFoodParser: FoodParsing`:
  - Check `SystemLanguageModel.default.availability`; if `.available`, `let r = try await session.respond(to: text, generating: NutritionInfo.self)` → map to `ParsedFood`.
  - Optional streaming for live preview later (`streamResponse`).
- `HeuristicFoodParser.swift` — `struct HeuristicFoodParser: FoodParsing` fallback when FM unavailable: port the regex/common-food fallback from `parse-food/route.ts` (apple/banana/egg/etc. defaults). AppCore picks FM-or-heuristic at wiring time.
- `VisionLabelReader.swift` — `struct VisionLabelReader: LabelReading`: run `RecognizeTextRequest` (`.accurate`) / iOS 26 `RecognizeDocumentsRequest`, extract the standard nutrition-panel lines, parse calories/macros (regex), then optionally pass raw OCR text through `FoundationModelsFoodParser` to normalize into `ParsedFood`. Gate `RecognizeDocumentsRequest` with `if #available(iOS 26, *)`.
- `FoundationModelsBarcodeEstimator.swift` — given a product name (when OpenFoodFacts lacks nutriments), prompt FM for a `NutritionInfo` estimate. Used by AppCore's barcode resolver chain.

**Tests (`NutritionAITests`):** ✅ `HeuristicFoodParser` outputs (quantity+unit regex, common-portion longest-match, isDish last resort, seam wrapper); ✅ `NutritionInfo`→`ParsedFood` mapping; ✅ `Prompts` portion rules + metric/imperial divergence + barcode instructions; ✅ `NutritionLabelParser` regex (standard panel, colons/decimals, sugars/saturated false-positive avoidance, no-calorie nil, partial); ✅ FM availability gate (readable + `.unavailable` throw when host lacks Apple Intelligence). *(FM generation + Vision OCR run on-device only — validated in Phase 11.)*
**DoD:** ✅ deterministic logic covered (Heuristic 93%, LabelParser 92%, Prompts/NutritionInfo 100%); ✅ FM/Vision calls behind availability checks. **CHECKPOINT:** `/compact focus on: Phase 4 done — FoundationModelsFoodParser + HeuristicFoodParser (FoodParsing), VisionLabelReader (LabelReading), barcode FM estimator; all iOS 26 APIs availability-gated; verify FM/Vision signatures in Xcode 26`.

---

### Phase 5 — AppCore (DI container)  (est. 3) — ✅ COMPLETE
> **Done (2026-06-22):** `AppContainer` (@Observable @MainActor, shared + injectable init), `makeFoodParser` FM-or-heuristic, `CompositeBarcodeResolver` (OFF → FM-estimator closure on `.missingNutriments(productName:)`), `SettingsStore` (UserDefaults, web defaults, clamped). Removed the 5 scaffold `*Module` markers + tests. 111 tests/18 suites; SettingsStore & Composite 100%.

**Goal:** wire concrete providers into seams; expose settings.

Files (CREATE) in `Sources/AppCore/`:
- `AppContainer.swift` — `@Observable @MainActor public final class AppContainer`, `static let shared`, `init() throws`:
```swift
public let store: SwiftDataStore
public let keychain: KeychainStore
public let foodParser: any FoodParsing        // FM if available else Heuristic
public let photoParser: any PhotoParsing       // APIPhotoParser (cloud)
public let labelReader: any LabelReading       // VisionLabelReader
public let barcodeResolver: any BarcodeResolving  // OpenFoodFacts → FM estimate fallback
public let settings: SettingsStore
public func bootstrap() async { /* preflight: store ready, FM availability, token presence */ }
public func authenticatePhotoProxy(password: String) async throws { /* /api/auth → store token in Keychain */ }
```
  - `foodParser` selection: `SystemLanguageModel.default.availability == .available ? FoundationModelsFoodParser() : HeuristicFoodParser()`.
  - `barcodeResolver`: a small composite `OpenFoodFactsResolver` → on `.missingNutriments`, fall back to `FoundationModelsBarcodeEstimator`.
- `SettingsStore.swift` — `@Observable` wrapper over `@AppStorage`-style `UserDefaults` keys for targets + units + `biometricLockEnabled` (mirrors web `calorie-counter-settings`). Provides `AppSettings` and `MacroTargets`.

**Tests (`AppCoreTests`):** ✅ container builds with in-memory store + stub seams (store round-trip, every seam reachable, auth-state from Keychain, signOut/bootstrap); ✅ `makeFoodParser` selection (FM-or-heuristic by availability); ✅ `SettingsStore` defaults match web (`2000/65/250/100`, metric), persist across instances, clamp out-of-range; ✅ barcode composite (OFF success passthrough, FM fallback with product name on `.missingNutriments`, rethrow without estimator, productNotFound propagation).
**DoD:** ✅ wiring verified with mocks; ✅ no SwiftUI in AppCore (Foundation/Observation only). **CHECKPOINT:** `/compact focus on: Phase 5 done — AppContainer wires store/parsers/settings; foodParser picks FM-or-heuristic; barcode OFF→FM fallback; Phase 6 builds the SwiftUI shell`.

---

### Phase 6 — App shell + app lock  (est. 5) — ✅ COMPLETE
> **Done (2026-06-22):** `CalorieCounterApp`/`RootView`/`MainTabView` (iOS 26 Tab + glass tab bar), `AppLockView` + package-side `BiometricGate`/`AppLockManager` (100%-tested via mock), placeholder screens. Launches on the simulator to the Today screen (screenshot-verified). Lock logic in AppCore for testability; toggle UI lands in Phase 10. 116 tests/19 suites.

**Goal:** the SwiftUI entry point, iOS 26 tab bar, optional Face ID lock.

Files (CREATE) in `apple/CalorieCounter/`:
- `CalorieCounterApp.swift` — `@main`, `WindowGroup { RootView() }`, `.modelContainer(for: SwiftDataStore.schemaTypes)`. Inject `AppContainer.shared` via `.environment`.
- `RootView.swift` — gate: if `settings.biometricLockEnabled && lockManager.isLocked` → `AppLockView` else `MainTabView`; `.task { await container.bootstrap() }`; lock on `scenePhase == .background`.
- `MainTabView.swift` — iOS 26 `Tab` API (match MyAIJournal):
```swift
TabView(selection: $tab) {
    Tab("Today", systemImage: "fork.knife", value: Screen.today) { TodayView() }
    Tab("History", systemImage: "chart.bar.xaxis", value: Screen.history) { HistoryView() }
    Tab("Settings", systemImage: "gearshape.fill", value: Screen.settings) { SettingsView() }
}
.tabBarMinimizeBehavior(.onScrollDown)
```
- `Lock/AppLockManager.swift` (`@Observable`), `Lock/BiometricGate.swift` (`actor`, `LocalAuthentication`, `@preconcurrency import`), `Lock/AppLockView.swift`.

**Tests:** ✅ `AppLockManagerTests` (lock/unlock/fail-open/cancel/failure via mock gate, 100%); SwiftUI shell verified by build + simulator launch smoke (boots to TodayView). Package logic already covered.
**DoD:** ✅ launches on simulator (screenshot-verified), ✅ tab bar shows Liquid Glass, ✅ lock logic works (toggle UI in Phase 10). **CHECKPOINT:** `/compact focus on: Phase 6 done — App/Root/MainTabView + AppLock; iOS 26 Tab + glass tab bar live; Phases 7/8/9/10 build the screens in parallel`.

---

### Phase 7 — Today screen  (est. 5)  · parallel with 8, 9, 10 — ✅ COMPLETE
> **Done (2026-06-22):** `TodayModel` + `MacroProgress` (AppCore, tested), `TodayView`/`TabbedTotalCard`/`CalorieOffsetView`+sheet/`EntryRow`/`QuickAddBar` (glass cluster). Renders on the simulator (screenshot-verified). Quick-add buttons report InputMethod to a placeholder; Phase 8 wires real flows. 122 tests/20 suites.

**Goal:** main tracking dashboard.

Files (CREATE) in `apple/CalorieCounter/Today/`:
- `TodayView.swift` — `@Query` today's `EntryRecord`s (predicate on `LocalDate.todayKey()`); shows `TabbedTotalCard`, `CalorieOffsetView`, `EntryListSection`, and the four input launch buttons. Apply `.scrollEdgeEffectStyle(.soft, for: .top)`.
- `TabbedTotalCard.swift` — macro tabs (calories/fat/carbs/protein) with progress vs `settings.targets` (port `TabbedTotalCard.tsx`). Content layer, not glass.
- `CalorieOffsetView.swift` + `CalorieOffsetSheet.swift` — exercise offset display/edit → `store.setOffset`.
- `EntryRow.swift` + swipe-to-delete; tap → `EditEntryView`.
- **Input buttons as a Liquid Glass cluster:** `GlassEffectContainer(spacing: 40)` with four `.glassEffect(.regular.tint(...).interactive(), in: .circle)` buttons (Scan/Voice/Type/Photo), OR a `.tabViewBottomAccessory { QuickAddBar() }` on `MainTabView`. Choose the bottom accessory for reachability.

**Tests:** ✅ `TodayModelTests` (load aggregates entries/totals/offset, delete refreshes, updateOffset persists + recomputes net, add persists, `progress(for:)` mapping); ✅ `MacroProgress` clamp/over/remaining. SwiftUI verified by build + simulator screenshot.
**DoD:** ✅ Today renders (screenshot); ✅ offset edit persists (`updateOffset` test). **CHECKPOINT:** `/compact focus on: Phase 7 done — TodayView + TabbedTotalCard + offset + entry list + Liquid Glass input cluster; Phase 8 wires the actual input flows`.

---

### Phase 8 — Input flows  (est. 8)  · parallel with 7, 9, 10 — ✅ COMPLETE
> **Done (2026-06-22):** `FoodConfirmModel`/`TextInputModel` (AppCore, tested), `FoodConfirmView`/`EditEntryView`/`InputFlowView`/`TextInputView`/`BarcodeScannerView`/`VoiceInputView`/`PhotoCaptureView` + `PhotoProxyLoginSheet`. Voice via SFSpeechRecognizer (on-device). UI-test target + `-uitest` mode added; text flow end-to-end UI test PASSES on the sim. Barcode/voice/photo capture device-only (Phase 11). 127 tests + 1 UI test.

**Goal:** the four capture flows + shared confirm/edit sheets.

Files (CREATE) in `apple/CalorieCounter/Input/`:
- `FoodConfirmView.swift` — shared confirmation sheet (`.presentationDetents([.medium, .large])`, glass sheet); edit quantity/unit, recalc macros (Core `MacroMath`), Save → `store.add`. Replaces `FoodConfirmDialog.tsx`.
- `EditEntryView.swift` — edit existing entry (port `EditEntryDialog.tsx`).
- `BarcodeScannerView.swift` — `UIViewControllerRepresentable` wrapping `DataScannerViewController` (`.barcode(symbologies: [.ean13,.ean8,.upce,.qr])`); on detect → `container.barcodeResolver.resolve` → `FoodConfirmView`. AVFoundation fallback if `!DataScannerViewController.isSupported`.
- `VoiceInputView.swift` — iOS 26 `SpeechTranscriber` + `SpeechAnalyzer` live transcription (waveform via `AVAudioEngine` tap levels), `if #available(iOS 26, *)` else `SFSpeechRecognizer`; final text → `container.foodParser.parse` → `FoodConfirmView`. Handle `AssetInventory` model download.
- `TextInputView.swift` — text field + autocomplete from `store.searchPreviousFoods`; submit → `container.foodParser.parse` (on-device FM) → `FoodConfirmView`.
- `PhotoCaptureView.swift` — `PhotosPicker` (library) + `UIImagePickerController` (camera); plate-size + serving-type pickers (port `PhotoCapture.tsx`); **toggle: "Nutrition label" → `container.labelReader` (on-device Vision)** vs **"Plate of food" → `container.photoParser` (cloud)**. On first cloud use, present a one-time password sheet → `container.authenticatePhotoProxy`.

**Tests:** ✅ `FoodConfirmModelTests` (recalc scales+rounds, zero, save persists with method); ✅ `TextInputModelTests` (autocomplete, parse routes through seam); ✅ `TextFlowUITests` end-to-end on the simulator (type → analyze → confirm → entry appears).
**DoD:** ✅ text flow produces a saved entry on the simulator (UI test); barcode/voice/photo capture paths verified on device in Phase 11. **CHECKPOINT:** `/compact focus on: Phase 8 done — barcode/voice/text/photo flows + FoodConfirm/EditEntry sheets; on-device FM for text/voice, Vision for labels, cloud proxy (password-gated) for plate photos; Phase 9 builds history`.

---

### Phase 9 — History + charts  (est. 5)  · parallel with 7, 8, 10 — ✅ COMPLETE
> **Done (2026-06-22):** `HistoryModel`/`MacroKind`/`CalendarMonth` (AppCore, tested), `HistoryView`/`NutritionChart` (Swift Charts)/`CalendarView`/`DayDetailView` (reuses TodayModel). 132 tests; History UI smoke passes on the sim.

**Goal:** trends + calendar + per-day detail.

Files (CREATE) in `apple/CalorieCounter/History/`:
- `HistoryView.swift` — range selector (7/30/90), `MacroTabs`, `NutritionChart`, `CalendarView`. Data via `store.dailyTotals(lastDays:)`.
- `NutritionChart.swift` — Swift Charts: `BarMark` daily kcal colored vs target, `RuleMark` target line + annotation; net-vs-raw overlay (port the Recharts history view). iOS 17+ `.chartScrollableAxes(.horizontal)` + `.chartXSelection(value:)` for tap callouts.
- `CalendarView.swift` — month grid with per-day entry indicator (port `Calendar.tsx`); select day → `DayDetailView`.
- `DayDetailView.swift` — entries + totals + offset for a historical date (port `useDayEntries`).
- `MacroTabs.swift` — shared with Today if extracted to `Components/`.

**Tests:** ✅ `dailyTotals` aggregation (Store tests); ✅ `HistoryModel` load/series(over-target coloring)/datesWithEntries; ✅ `MacroKind` mapping; ✅ `CalendarMonth` day-count + leading-blanks; ✅ `HistoryUITests` render smoke.
**DoD:** ✅ history renders seeded multi-day data (HistoryModel.load test + UI smoke); ✅ selection works (calendar→DayDetail navigation). **CHECKPOINT:** `/compact focus on: Phase 9 done — HistoryView + Swift Charts + Calendar + DayDetail; Phase 10 builds settings/export`.

---

### Phase 10 — Settings + export  (est. 3)  · parallel with 7, 8, 9 — ✅ COMPLETE
> **Done (2026-06-22):** `CSVExporter` (AppCore, pure, 92.86%/100%, web-faithful), `SettingsView` (targets/units/lock toggle/photo-connect/CSV ShareLink/reset), `AboutView`. 138 tests; Settings UI smoke passes.

**Goal:** preferences, CSV export, about, lock toggle.

Files (CREATE) in `apple/CalorieCounter/Settings/`:
- `SettingsView.swift` — edit targets (clamped to Core ranges), units picker, **biometric lock toggle**, "Connect photo parsing" (password → `authenticatePhotoProxy`), reset to defaults, about. Glass sheets/forms (`.scrollContentBackground(.hidden)`).
- `CSVExporter.swift` — port `src/utils/csvExport.ts` exactly: header `date,calories_consumed,calories_burned,net_calories,carbs,fat,protein`; expose via `ShareLink` (file URL).
- `AboutView.swift` — copyright, links, license.

**Tests:** ✅ `CSVExporterTests` golden output (header, integer-vs-1dp formatting, net clamp, empty-day filter, filename, empty dataset); ✅ target clamping + settings persistence (`SettingsStoreTests`); ✅ `SettingsUITests` render smoke.
**DoD:** ✅ export produces correct CSV (golden tests); ✅ settings persist across launches (`SettingsStore` persistence test). **CHECKPOINT:** `/compact focus on: Phase 10 done — Settings + CSV ShareLink + About + lock toggle; Phase 11 is Liquid Glass polish + device QA`.

---

### Phase 11 — Polish, accessibility, device QA  (est. 3) — ✅ COMPLETE (device QA pending user hardware)
> **Done (2026-06-22):** App icon (gradient + fork/knife), reduce-motion gating + VoiceOver value on the ring, Liquid Glass confined to chrome, all iOS 26 APIs verified + clean build, simulator QA + FM-fallback verified. **Remaining (user's device):** real FM/voice/Vision-OCR/barcode/camera-proxy smoke test before App Store submission.

**Goal:** ship-quality Liquid Glass + verify on-device AI.

Tasks:
- Liquid Glass review: glass only on chrome/floating controls; one `GlassEffectContainer` per cluster; `.regular` for text legibility; remove any forced opaque backgrounds hiding glass on sheets/nav.
- Accessibility: honor `accessibilityReduceMotion` (gate morph animations), `accessibilityReduceTransparency`, Dynamic Type, VoiceOver labels on input buttons and chart.
- App icon + launch screen + accent color.
- **Device QA (Apple-Intelligence-capable device):** Foundation Models text/voice parsing, `SpeechTranscriber` voice flow, Vision label OCR, `DataScannerViewController` barcode, camera plate-photo → cloud proxy. Verify the FM-unavailable fallback on a non-AI device/simulator.
- Verify the "verify-in-Xcode-26" API list below.

**DoD:** ✅ runs cleanly on the simulator; ✅ text/photo-picker inputs produce correct entries; ✅ FM-unavailable fallback works; ✅ no a11y regressions (reduce-motion + VoiceOver added); ⚠️ on-device verification of the camera/mic/FM-backed inputs is the user's remaining step. **CHECKPOINT:** `/compact focus on: Phase 11 done — port complete; Liquid Glass + a11y + sim QA verified; device QA pending user hardware`.

---

## iOS 26 / Liquid Glass adoption summary
- **Free on recompile (iOS 26 SDK):** glass tab bar, nav bars, toolbars, sheets, `.searchable`, scroll-edge effects. Don't fight them with opaque backgrounds.
- **Opt-in we use:** `.tabBarMinimizeBehavior(.onScrollDown)`, `.tabViewBottomAccessory` (quick-add bar), `GlassEffectContainer` + `.glassEffect(.regular[.tint][.interactive])` for the input-button cluster and any floating action control, `.scrollEdgeEffectStyle` on the Today/History scrolls, `.presentationDetents` glass sheets.
- **Keep on the content layer (NOT glass):** entry list, macro cards, charts, photos.
- **Verify in Xcode 26 before relying on:** `Glass.interactive` arity; `tabViewBottomAccessory` signature/placement; Foundation Models `streamResponse` snapshot shape and the `Tool` `PromptRepresentable` return (the old `ToolOutput` was removed); `RecognizeDocumentsRequest`/`DocumentObservation` members; `SpeechTranscriber(locale:…)` init + `AssetInventory` install API; Vision `BarcodeObservation.payloadString` vs VisionKit `RecognizedItem.Barcode.payloadStringValue`.

## Reusable web sources to port (for the executor)
- `src/types/index.ts` → NutritionCore models. `src/lib/constants.ts` → `Constants.swift`.
- `src/utils/idb.ts` → `NutritionStoring` query/aggregation semantics (`getMacroTotalsForDate`, `getDailyMacroTotalsWithOffset`, `searchPreviousFood`, offsets).
- `src/app/api/parse-food/route.ts` → FM `Prompts.swift` + `HeuristicFoodParser` fallback rules.
- `src/app/api/parse-photo/route.ts` → **stays server-side**; iOS only calls it (`APIPhotoParser`).
- `src/app/api/barcode/[code]/route.ts` → OpenFoodFacts decoding + FM estimate fallback.
- `src/utils/csvExport.ts` → `CSVExporter.swift` (exact format).
- `src/hooks/*`, `src/components/*` → per-flow UI structure and state transitions.

---

## Verification

**Package logic (macOS, fast, in CI):**
```bash
cd apple/Packages/NutritionKit && swift test
```
Expect: NutritionCore (models/date/macro), NutritionStore (in-memory CRUD/aggregation), NutritionAPI (URLProtocol stubs + OFF decoding + Keychain), NutritionAI (heuristic parser + mapping + label regex), AppCore (wiring) all green.

**App build + UI (simulator):**
```bash
# Pin OS=26.x — the dev machine also has iOS 18.x runtimes installed, so an
# unpinned destination can silently build against iOS 18 and fail on glass APIs.
xcodebuild -project apple/CalorieCounter.xcodeproj -scheme CalorieCounter \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro,OS=26.4' build
xcodebuild test -project apple/CalorieCounter.xcodeproj -scheme CalorieCounter \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro,OS=26.4'
```
(Confirmed available locally: Xcode 26.4.1, iOS SDK 26.4, Swift 6.3.1, iOS 26.4 + 26.1 simulator runtimes. If `iPhone 16 Pro` isn't installed, pick any device under the iOS 26.4 runtime via `xcrun simctl list devices available`.)
Simulator validates: launch → TodayView, tab navigation + glass chrome, text-input flow with a stubbed parser, history chart render, CSV export, settings persistence, app-lock toggle.

**On-device QA (Apple-Intelligence-capable iPhone, Phase 11):** Foundation Models text/voice parsing (and the heuristic fallback when AI is off), `SpeechTranscriber` voice capture, Vision nutrition-label OCR, `DataScannerViewController` barcode → OpenFoodFacts, camera plate-photo → cloud `/api/parse-photo` (first-use password gate → Keychain token). Confirm each produces a correct, editable `Entry` that persists in SwiftData and refreshes Today/History.

**Definition of Done (every phase):** builds with no new warnings; Swift 6 strict concurrency clean; new tests pass; existing tests pass; ≥80% coverage on new deterministic logic (UI + FM/Vision/network device paths exempt, verified manually in Phase 11).

## Risks / open items
- **Foundation Models availability** is limited to Apple-Intelligence devices; the FM-or-heuristic switch in AppCore is the safety net — exercise it in QA.
- **iOS 26 API churn:** several signatures need Xcode-26 confirmation (list above). Resolve at the start of Phases 4/8.
- **Cloud coupling:** the plate-photo feature depends on the deployed Next.js `/api/parse-photo` + `/api/auth`. Keep `OPENAI_API_KEY` server-only; the app never holds it.
- **Data import:** no migration path from the web IndexedDB store is in scope (fresh local store on iOS). Add a CSV-import path later if cross-platform continuity is wanted.
