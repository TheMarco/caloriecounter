# CalorieCounter — Feature Reference

A privacy-first calorie & macro tracker. This document describes the **native iOS app** (SwiftUI, iOS 26, under `apple/`) in detail, with a section on the **web app** (Next.js, repo root) at the end.

Built by Marco van Hylckama Vlieg · © 2026 Unthinking AI, LLC.

---

## Table of Contents

1. [Design Philosophy](#1-design-philosophy)
2. [Food Logging & Capture](#2-food-logging--capture)
3. [AI Parsing & Smart Corrections](#3-ai-parsing--smart-corrections)
4. [The Today Dashboard](#4-the-today-dashboard)
5. [Calorie Offsets & Workout Integration](#5-calorie-offsets--workout-integration)
6. [Quick Re-Log ("Your Usuals")](#6-quick-re-log-your-usuals)
7. [History, Charts & Insights](#7-history-charts--insights)
8. [Weight Tracking](#8-weight-tracking)
9. [Setup Wizard & Goal Planning](#9-setup-wizard--goal-planning)
10. [Apple Health Integration](#10-apple-health-integration)
11. [Subscription — CalorieCounter Pro](#11-subscription--caloriecounter-pro)
12. [Settings & Data Management](#12-settings--data-management)
13. [Notifications](#13-notifications)
14. [Design System & Accessibility](#14-design-system--accessibility)
15. [Launch Experience](#15-launch-experience)
16. [Storage, Architecture & Dev Modes](#16-storage-architecture--dev-modes)
17. [Privacy Summary](#17-privacy-summary)
18. [The Web App](#18-the-web-app)

---

## 1. Design Philosophy

- **No account, ever.** Open the app and start tracking. No sign-up, no email, no user ID.
- **Local-first & private.** Your food log, weights, targets, and settings live on your device. The only thing that leaves the phone is the text/photo you submit for food analysis.
- **Estimates, not judgment.** Calorie and macro figures are presented as guides. The app deliberately avoids moral language ("good/bad/cheat/fail") anywhere in insights or summaries.
- **Optional everything.** Apple Health, biometric lock, voice, and photo are all opt-in and off until you turn them on.

---

## 2. Food Logging & Capture

Four capture methods plus one-tap re-logging. Every method ends in the same **confirm-and-adjust** screen before anything is saved. Capture lives in a floating dock at the bottom of the screen — tap the green **+** to raise the four tools (Scan / Speak / Type / Photo).

### Text
- Type a description ("2 eggs and toast"); the app parses it into a food with calories and macros.
- Autocomplete suggests foods you've eaten before as you type (ranked by frequency/recency) — tap one to reuse its exact nutrition and skip the cloud parse.

### Voice
- Tap the mic, speak naturally ("three slices of pizza and a side salad"), see a live transcript, then analyze.
- **Speech is transcribed on-device** (Apple's speech recognition); only the resulting *text* is sent for parsing — never the audio.

### Barcode
- Native VisionKit scanner (EAN-13/8, UPC-E, QR, Code128) with a centered viewfinder.
- Looks the product up in **Open Food Facts** (global database, no account). Prefers the **per-serving** values printed on the package (e.g. per-slice for bread), falling back to per-100 g.
- If the product exists but has no nutrition data, the app estimates from the product name instead of failing.
- Barcode entries are treated as **measured data** (high confidence) — not subject to the AI "learning" corrections. Changing quantity/unit recalculates live.

#### Verify with label
A trust layer on top of any barcode result — make a packaged food honest and "stick":
- Every barcode result offers a small **"Verify with label"** action. When the lookup was only an estimate (Open Food Facts knew the product but had no nutrition), label scanning is **promoted as the primary call-to-action** — though you can still add the estimate as-is.
- The label scan is **fully on-device**: Apple's Vision OCR reads the Nutrition Facts panel and a built-in parser extracts serving size + calories/protein/carbs/fat. Nothing leaves the phone.
- A **comparison screen** shows the current values next to the scanned ones (differences highlighted) — nothing changes until you confirm.
- Confirmed values are **remembered locally for that barcode**. The next time you scan that product it shows **"Label verified"** and uses your trusted numbers instantly (no network).

### Photo
- Square camera frame → take a photo of the meal. The image is center-cropped to 1024×1024 and analyzed by an **OpenAI vision model**.
- **Portion context step** improves accuracy: pick a plate size (Small → XL), a serving type (Home / Restaurant / Fast-food / Snack), and an optional "I only ate about half" toggle.
- Very dark / lens-covered shots are rejected before upload.
- Multi-item plates are broken into editable components (e.g. chicken + rice + veggies).

> **Confirm & adjust screen (all methods):** shows a meal card with a confidence badge (Barcode / Photo estimate / Typed estimate). You can edit the name, quantity, and unit; use one-tap chips (**½, 2×, Less, More, Swap unit**); and for multi-part meals, adjust, add, or remove individual ingredients before saving. Tap any saved entry later to edit; swipe to delete (with undo).

---

## 3. AI Parsing & Smart Corrections

- **Cloud parsing** (text/voice/photo) uses OpenAI through the app's proxy. A primary model is used with an automatic fallback model for resilience. No name, account, or device ID is attached to requests.
- **Heuristic offline fallback** exists for text (regex + common-portion tables) so parsing degrades gracefully in non-production/offline builds; production food analysis is online.
- **Realistic portions & rounding:** the parser is instructed to use sensible serving sizes, respect your metric/imperial preference, round calories to the nearest 5 and macros to the nearest gram, and apply an **Atwater-floor correction** so calorie estimates can't fall below what the macros imply.
- **It learns your corrections.** When you adjust an *estimated* food (text/voice/photo), the app remembers your numbers for that food + unit. The next time you log the same thing, it pre-applies what you taught it and notes that it remembered. Corrections never override *measured* data (barcodes). Stored locally in a `CorrectionRecord` table.

---

## 4. The Today Dashboard

The home screen — your day at a glance.

- **Hero calorie ring:** large central ring showing **net calories** (food eaten − exercise/adjustment offset, floored at 0) against your goal. Fills 0–100 %, then wraps a red "overage" arc if you go over. Center shows the net number, "net kcal" / "kcal", and "of X goal" or "X over."
- **Three macro rings:** protein, carbs, and fat, each tracking consumed vs. target with the same fill-then-overage behavior, color-coded (protein = rose, carbs = blue, fat = gold).
- **Over-limit is unmistakable:** the ring wraps a warm-red overage arc, the number turns red, and the label switches to "X over" — for calories and each macro.
- **Food entry cards:** each logged item shows its capture-method icon, name, quantity/unit, calories, and colored macro pips. Tap to edit; swipe to edit or delete.
- **Undo everywhere:** deleting (or quick-logging) raises an undo toast that fully restores the entry.
- **Just-logged highlight:** a freshly added entry briefly glows green.
- **Pull-to-refresh** reloads the day; the screen also auto-refreshes when data changes elsewhere (import, reset, weigh-in), and re-checks for new workout offsets when you return to the app.

---

## 5. Calorie Offsets & Workout Integration

- **Manual offset chip** ("Exercise & Adjustments"): tap to add calories burned for the day via a stepper (0–5000 kcal, ±25) or exact entry. The offset reduces your net calories.
- **Automatic workout offsets (Apple Health, opt-in):**
  - After you finish a workout, the app offers to add its burned calories to that day's offset, via a **"Workout detected"** banner on Today (Add N kcal / Dismiss) and an optional local notification.
  - Only "real" workouts qualify: at least **10 minutes** and **80 kcal**. Incidental movement is filtered out.
  - Burned-calorie reading is **robust** — it resolves a workout's Active Energy from per-workout statistics, then associated samples, then the legacy total, so manually-added and third-party workouts aren't silently missed.
  - Read-only: the app never writes workouts back to Health.
  - A **permission primer** explains to tap "Turn On All" before the system prompt (Apple defaults the read switches to off), and a **"Check recent workouts"** troubleshooter in Settings reports exactly what Health returned and why each workout did or didn't qualify.
  - Each workout is remembered as handled/notified so it's never offered twice (ledgers auto-prune after ~35 days).

---

## 6. Quick Re-Log ("Your Usuals")

- A horizontal row on Today of up to **8** foods you log most often (ranked by frequency over the last 30 days, then recency), excluding anything already logged today.
- Tap one to instantly re-log it with the same nutrition — no parsing step — with full undo and Health sync.

---

## 7. History, Charts & Insights

- **Range selector:** 7 days / 30 days / 90 days / All (All spans from your earliest entry).
- **Weekly insights:** 1–3 plain, non-judgmental observations generated from the range, e.g. "You logged 6 of 7 days," "averaged 1,950 kcal, about 50 under your goal," and a protein note. Averages are computed **only over days you logged**, so blank days don't skew them.
- **Macro trend chart:** switch between Calories / Protein / Carbs / Fat. Daily bars across the whole range (no hidden horizontal scroll), bars over target turn red, with a dashed goal line. Tap a bar for a day summary ("Mon 22 · 1,850 kcal · P95 C210 F60"). Calories shown are **net**.
- **Weight chart:** line chart of weigh-ins over the range, auto-scaled (non-zero-based) so small changes are visible; honest linear interpolation for sparse data.
- **Month calendar:** today highlighted; each logged day shows a **provenance dot** — filled (all measured), half (mixed), or hollow ring (all estimated). Tap any day to open its detail.
- **Day detail:** the macro dashboard, offset, and food cards for any past day. You can delete entries from past days (syncs to Health).

> The app intentionally has **no streaks, scores, or adherence badges** — provenance and insights are factual, not motivational pressure.

---

## 8. Weight Tracking

- Log a weigh-in from History in your unit system (kg or lb, one decimal). One measurement per calendar day; re-logging the same day updates it. No need to weigh in daily — it's a sparse series.
- Weight is stored canonically in **kilograms** and displayed in your chosen units.
- Your wizard weight becomes the first data point.
- **Weight-drift nudge:** if your latest weight differs from the weight your plan was built on by **≥ 3 kg (~6–7 lb)**, Today shows a gentle "Refresh your plan?" banner that reopens the setup wizard pre-filled.
- Optional two-way sync with Apple Health (write your weigh-ins, import existing ones — see below).

---

## 9. Setup Wizard & Goal Planning

A guided onboarding (re-runnable any time from Settings) that computes personalized targets.

**Steps:** Welcome (privacy promise) → Try a meal → **Goal** (required) → Diet style → Body (sex, age, weight, height — with a live Metric/Imperial toggle) → Activity level → Plan (review & save).

**The math:**
- **BMR — Mifflin–St Jeor:** `10·kg + 6.25·cm − 5·age + (male +5 / female −161)`
- **TDEE:** `BMR × activity factor` — Sedentary 1.2, Light 1.375, Moderate 1.55, Active 1.725, Very Active 1.9
- **Daily calories:** `max(1200, round(TDEE + goal delta, nearest 25))` — a 1,200 kcal safety floor
  - Goal deltas: Lose fast (~0.75 kg/wk) −750 · Lose steady (~0.5 kg/wk) −500 · Maintain 0 · Gain (~0.25 kg/wk) +350 kcal
- **Macros** from your diet style, as % of calories ÷ (4 kcal/g protein & carbs, 9 kcal/g fat), rounded to 5 g and clamped:

  | Diet | Protein / Carbs / Fat | Good for |
  |---|---|---|
  | Balanced | 30 / 40 / 30 | A flexible default |
  | High Protein | 40 / 30 / 30 | Building/keeping muscle |
  | Low Carb | 35 / 20 / 45 | Cutting carbs |
  | Keto | 25 / 5 / 70 | Ketogenic eating |
  | High Carb | 25 / 55 / 20 | Endurance / heavy training |
  | Mediterranean | 25 / 45 / 30 | Whole foods, healthy fats |

- The Plan screen shows your maintenance (TDEE) estimate and an estimates-not-medical-advice disclaimer. Saving stores your targets and a profile (used for re-prefill and the drift nudge) and seeds an initial weigh-in.

**Manual targets:** you can also edit Calories / Fat / Carbs / Protein directly in Settings as tappable number fields. Values are clamped to sane ranges (Calories 1000–5000; Fat 20–300 g; Carbs 20–500 g; Protein 30–300 g). Defaults are 2000 / 65 / 250 / 100. The ranges deliberately accommodate Keto/Low-Carb extremes.

---

## 10. Apple Health Integration

Entirely opt-in, off by default, with four independent toggles (Settings → Apple Health):

1. **Sync nutrition to Health** — writes each food as an `HKCorrelation(.food)` with calories + protein/carbs/fat, tagged so edits/deletes stay in sync.
2. **Sync weight to Health** — writes your weigh-ins as body-mass samples (one per day).
3. **Import weight from Health** — pulls existing weigh-ins in; if a day conflicts with a local value, a **conflict sheet** lets you pick "Use Apple Health" or "Keep current." New days import silently. Default lookback 365 days; re-runnable on demand.
4. **Offset calories from workouts** — read-only workout/active-energy reads that power the automatic offsets in [section 5](#5-calorie-offsets--workout-integration).

**Supporting actions:** last-sync timestamp, "Import now," **Repair sync** (re-push the last 30 days), **Disconnect** (stop syncing, keep written data), and **Remove this app's data from Health** (deletes only what CalorieCounter wrote). All app data carries a `CalorieCounter` source marker so it's identifiable and never touches other apps' data. Health data is never sent to any server.

---

## 11. Subscription — CalorieCounter Pro

- **Free tier:** the first **10 food entries** are free. (Only food entries count — weights, offsets, and edits don't.)
- After that, logging requires **CalorieCounter Pro**, presented via a branded paywall.
- **Plans:** Monthly and Yearly, each with a **7-day free trial**. Real prices come from the App Store (localized); dev previews show $3.99/mo and $39.99/yr.
- **No account.** Built on **StoreKit 2** with on-device entitlement checks — no backend, no login. **Restore Purchases** and **Manage Subscription** are available in Settings and on the paywall.
- The free-entry counter is stored in **iCloud key-value storage**, so it survives reinstalls and follows your Apple ID across devices — still without an account. It's monotonic (deleting entries doesn't refund free slots).
- Settings shows your status: **Pro · Active** with Manage, or **Free plan · X of 10 used** with Upgrade / Restore.

---

## 12. Settings & Data Management

- **Daily targets** — edit calories & macros (tappable number fields, clamped on commit); "Reset targets to defaults."
- **Units** — Metric or Imperial (defaults to your device locale; drives food-logging units app-wide).
- **Appearance** — Light / Dark / System theme.
- **Haptics** — subtle taps on recognize/adjust/save/undo (on by default).
- **Security** — "Require Face ID / Touch ID": locks the app when it goes to the background. Local only; the lock token is held in the Keychain (device-only, non-syncing).
- **Re-run setup wizard** — recompute targets from a goal (cancellable when re-run; only the first-launch run is mandatory).
- **Export CSV** — full backup (every food entry + daily offsets + weigh-ins, including fiber/sodium/sugar and capture method) via the iOS share sheet. Names with commas are quoted.
- **Import CSV** — restore a backup; auto-detects the per-entry or legacy daily-totals format and de-duplicates via stable IDs ("Imported X days of data"). Today/History refresh automatically.
- **Erase All Data & Start Over** — two-step confirmation; wipes entries/offsets/weights, resets targets, and returns to onboarding.
- **About** — version, a "what stays on device" privacy diagram, data-source credits (Open Food Facts under ODbL, OpenAI), and the medical disclaimer.

> Note: imported data appears in History only if its dates fall within the selected range — History always looks backward from today.

---

## 13. Notifications

- **Workout-complete notifications** (only if workout offsets are enabled): "You burned about X kcal in a Y-min Z. Tap to add it to your calories." Posted when Health wakes the app for a new qualifying workout.
- Permission is requested **lazily** — only the first time a notification would actually fire, not when you flip the Settings toggle. Notifications are de-duplicated per workout.

---

## 14. Design System & Accessibility

**Visual language**
- **Glass for chrome, matte for content:** translucent iOS 26 "liquid glass" only for transient chrome (the floating dock, capture tray, undo toasts); solid matte surfaces for everything data-bearing (cards, dashboard) so your log stays calm and readable.
- **Macro color identity:** calories = sage green (the hero), protein = rose, carbs = blue, fat = gold, over-target = an unmistakable red.
- **Floating capture dock:** a custom bar with two quiet tabs (Today · History) and a raised green "+" jewel; Settings is a gear in the top-right. Tapping "+" rotates it to "×" and raises four capture tools (Scan / Speak / Type / Photo).

**Accessibility (first-class)**
- **Dynamic Type** throughout; at accessibility text sizes the UI *reflows rather than truncates*:
  - the macro rings become a clear text + progress-bar summary;
  - dock tabs go icon-only;
  - meal-card badges and macro chips stack vertically;
  - scroll content reserves real space so the last card ends **above** the dock instead of hiding behind it.
- **VoiceOver:** descriptive labels and hints on every control ("Banana, 1 medium, 105 calories"; rings read net-of-goal, and over-target states are spoken).
- **Contrast:** borders and text strengthen with Increase Contrast; meaning never relies on color alone.
- **Reduce Motion:** spring/scale animations become quiet crossfades; ring animations disable accordingly.
- **Semantic haptics:** distinct feedback for parsed / adjusted / saved / scan-success / uncertain, with a master toggle.

---

## 15. Launch Experience

- A native launch screen (full-screen splash image) hands off invisibly to an **in-app splash** that continues the same image, held a **minimum of 2 seconds**, then **crossfades** (0.45 s) into the app.
- During the splash the app bootstraps and — if biometric lock is on — authenticates, so you never see a half-loaded screen.

---

## 16. Storage, Architecture & Dev Modes

- **Local database:** SwiftData, on-device only (no CloudKit), accessed through a Swift-6-safe `@ModelActor`.
- **Records:** food entries, per-day exercise offsets, weigh-ins, and learned corrections — all keyed by **local calendar day** (`YYYY-MM-DD`, device timezone, no UTC). Stable IDs make import idempotent.
- **Architecture:** an `@MainActor @Observable` `AppContainer` is the single dependency-injection root; UI talks to protocol "seams" (`HealthSyncing`, parsers, stores) so Health, networking, and persistence are all swappable and testable (real vs. mock). Built with **Swift 6** strict concurrency in a layered Swift package (`NutritionKit`), and heavily unit- and UI-tested.
- **Frameworks:** VisionKit (barcode), Speech (on-device transcription), HealthKit, StoreKit 2, LocalAuthentication (biometric lock), Swift Charts (graphs).
- **Dev/test flags:**
  - `-demo` — seeds ~2 months of realistic data (varied meals, exercise offsets, a weekly weigh-in trend ~84 → 81.5 kg) in an in-memory store, for screenshots and exploration.
  - `-show-paywall`, `-gate`, `-subscribed` — exercise the subscription/paywall states.
  - Demo, UI-test, and unit-test builds bypass StoreKit and use mock services (no network).

---

## 17. Privacy Summary

| Data | Where it lives | Leaves device? |
|---|---|---|
| Food log, corrections, weights, targets, settings | On device (SwiftData / UserDefaults) | No |
| Biometric-lock token | Keychain (device-only) | No |
| Free-entry counter | iCloud key-value (your Apple ID) | iCloud only, no account |
| Food text / photo for analysis | Sent to OpenAI for parsing | Yes — only the submitted text/image |
| Voice | Transcribed **on device**; only text is sent | Audio: no |
| Barcodes | Looked up in Open Food Facts | The barcode number only |
| Apple Health data | Read/written locally via HealthKit | Never to any server |

No accounts, no analytics identity, no server-side profile. Under OpenAI's API terms, submitted data isn't used to train their models.

---

## 18. The Web App

The repo root hosts the original **Next.js 15 / React 19** web app — the same calorie tracker with the same core flows (barcode / voice / text / photo capture → OpenAI parsing → confirm → local save), backed by **IndexedDB** instead of SwiftData.

Web-specific traits:
- **Installable PWA** (`manifest.json`): standalone display, app shortcuts ("Add Food," "View History"), home-screen icons.
- **Offline-capable** via a service worker (Workbox): static assets precached; fonts CacheFirst; images stale-while-revalidate; API calls NetworkFirst with cache fallback; a dedicated `/offline` page.
- API routes mirror the iOS parsers: `/api/parse-food`, `/api/parse-photo`, `/api/barcode/[code]`.

The native iOS app adds what the web can't: Apple Health, on-device speech, biometric lock, VisionKit scanning, StoreKit subscriptions, native splash continuity, and the iOS 26 design system.

---

*Generated from the codebase. For build/run commands and architecture notes, see `CLAUDE.md`.*
