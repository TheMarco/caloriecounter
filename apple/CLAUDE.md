# CLAUDE.md — iOS app (`apple/`)

Guidance for Claude Code when working in the **native iOS app**. This is a SwiftUI
(iOS 26, Swift 6) port of the calorie tracker. The Next.js web app at the repo root
is a separate codebase **and** doubles as this app's API backend (see Networking).

## Build, Run & Test

```bash
# Regenerate the Xcode project after ADDING/REMOVING source files (see below).
cd apple && xcodegen generate

# Build for the simulator (the canonical command used in this repo).
cd apple && xcodebuild build \
  -project CalorieCounter.xcodeproj -scheme CalorieCounter \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -derivedDataPath DerivedData

# Unit tests — the NutritionKit Swift package (fast, no simulator).
cd apple/Packages/NutritionKit && swift test

# UI tests — the CalorieCounterUITests target, via the app scheme.
cd apple && xcodebuild test \
  -project CalorieCounter.xcodeproj -scheme CalorieCounter \
  -destination 'platform=iOS Simulator,name=iPhone 17' -derivedDataPath DerivedData
```

`DerivedData/` is local build output. To run a built app on the simulator:
`xcrun simctl install "iPhone 17" <path-to>/CalorieCounter.app` then
`xcrun simctl launch "iPhone 17" com.aidashcreated.caloriecounter [flags]`.

## Project generation (XcodeGen)

- **`project.yml` is the source of truth.** The `.xcodeproj` is generated from it
  and committed, so Xcode/CI open normally without anyone running XcodeGen day-to-day.
- App sources are **auto-globbed** from `CalorieCounter/`. Adding a file in that tree
  needs no project edit — but you **must `xcodegen generate`** for Xcode/`xcodebuild`
  to see it. (Editing existing files needs nothing.)
- Bundle id `com.aidashcreated.caloriecounter`; iOS 26 deployment target; Swift 6
  with `SWIFT_STRICT_CONCURRENCY: complete`. Signing team is set for the on-device
  HealthKit/iCloud entitlements; simulator builds ignore it.

## Architecture

UI (the `CalorieCounter` app target) depends on one Swift package, **`NutritionKit`**
(`Packages/NutritionKit/`), layered so features depend on protocol "seams", not
frameworks:

- **`NutritionCore`** — pure domain: `Entry`, `MacroTotals`/`MacroTargets`, `LocalDate`,
  `MacroMath`, goal-planning math, and the protocol seams (`HealthSyncing`, parsers,
  stores). No platform frameworks.
- **`NutritionStore`** — SwiftData persistence (`@ModelActor`): entries, day offsets,
  weights, and learned `CorrectionRecord`s. Keyed by local calendar day (`YYYY-MM-DD`).
- **`NutritionAPI`** — the cloud calls: `CloudFoodParser` (`/api/parse-food`),
  `APIPhotoParser` (`/api/parse-photo`), `OpenFoodFactsResolver`. `APIEnvironment`
  holds the base URLs.
- **`NutritionHealth`** — the **only** module that imports HealthKit
  (`AppleHealthKitService`). Everything else uses the `HealthSyncing` seam.
- **`AppCore`** — the composition root. `AppContainer` (`@MainActor @Observable`) wires
  the real-or-mock implementations and is the single thing the UI imports for DI; also
  hosts the view models (`TodayModel`, `HistoryModel`, etc.) and gates (subscription,
  free tier).

App target folders (`CalorieCounter/`): `Today/`, `History/`, `Input/`, `Setup/`,
`Settings/`, `Paywall/`, `Lock/`, `DesignSystem/` + `RootView`, `MainTabView`,
`CalorieCounterApp`. See `FEATURES.md` for the user-facing feature map.

## Networking

The app never holds an OpenAI key. Text/voice/photo parsing goes through a **server
proxy** — the Next.js app at the repo root — which holds the key server-side.
`APIEnvironment` (in `NutritionAPI`): production `https://caloriecounter.ai-created.com`,
development `http://localhost:3000`. Barcodes hit Open Food Facts directly. Do **not**
commit proxy credentials or keys into the repo.

## Conventions & gotchas

- **Swift 6 strict concurrency** everywhere — respect actor isolation; `@MainActor` on
  UI-facing models. `nonisolated` for values referenced from non-isolated contexts
  (e.g. StoreKit product-ID statics on the `@MainActor` `SubscriptionManager`).
- **Seams for testability.** Demo / UI-test / unit-test builds inject **mocks**
  (`MockHealthSyncService`, heuristic parser) and bypass StoreKit. Don't reach for a
  framework directly when a seam exists.
- **Launch flags** (dev/testing): `-demo` (seed ~2 months of data, in-memory),
  `-show-paywall`, `-gate` (force not-Pro + free allowance spent), `-subscribed`
  (force Pro). Mirrored by `AppContainer.isDemo` / `isUITest` / `isGateTest`.
- **HealthKit:** all reads/writes are opt-in and best-effort; the app stays fully
  usable when Health is unavailable or denied. **Read authorization is invisible** to
  the app (HealthKit hides read status by design) — never assume access from a granted
  prompt; verify by whether queries return data. StoreKit testing in
  Xcode/simulator uses `CalorieCounter.storekit` (wired into the run scheme); it does
  **not** apply to `simctl launch`.
- After editing `project.yml` or adding files, regenerate before building.
