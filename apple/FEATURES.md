# CalorieCounter (iOS) — Complete Feature Guide

A local‑first calorie and macro tracker for **iOS 26**. Everything runs **on the
device** — food recognition, voice transcription, label scanning, and meal
planning all use Apple's built‑in frameworks (including **Apple Intelligence /
Foundation Models**). Your nutrition data never leaves the phone.

---

## 1. Philosophy & Privacy

- **On‑device first.** Text/voice food parsing, nutrition‑label OCR, and barcode
  scanning are all processed locally. The only network call is an anonymous
  barcode lookup to OpenFoodFacts (a public food database).
- **Your data stays put.** Entries, weights, and settings live in a local
  SwiftData store with no iCloud/CloudKit sync. The biometric‑lock token is kept
  in the Keychain, device‑only, non‑syncing.
- **No account required.** Open the app and start tracking.

---

## 2. Onboarding — the Setup Wizard

A five‑step wizard runs on first launch (and is re‑runnable anytime from
Settings). It turns who you are and what you want into concrete daily targets.

1. **Your Goal** — pick a weight goal:
   - Lose weight fast (~0.75 kg / 1.5 lb per week)
   - Lose slow & steady (~0.5 kg / 1 lb per week)
   - Maintain weight
   - Gain responsibly (~0.25 kg / 0.5 lb per week)
2. **Diet Style** — pick how your calories are split across macros (see §8):
   Balanced, High Protein, Low Carb, Keto, High Carb, or Mediterranean. Each card
   shows its macro split (e.g. "5% C · 25% P · 70% F" for Keto).
3. **About You** — sex, age, weight, height. Includes a **Metric/Imperial
   toggle**; weight and height re‑render instantly (kg↔lb, cm↔ft·in). Stats are
   stored canonically so switching units is lossless.
4. **Activity** — sedentary → extremely active.
5. **Your Plan** — shows the computed calorie + macro targets and the maintenance
   (TDEE) estimate. Finishing seeds your **starting weight** into weight history.

**The math:** Mifflin–St Jeor BMR × an activity factor = TDEE; the weight goal
applies a calorie delta; the diet style splits those calories across protein /
carbs / fat. Results are rounded to tidy numbers (calories to 25, macros to 5)
and never drop below a safe 1,200 kcal floor.

---

## 3. Logging Food — four on‑device methods

Capture buttons sit at the **top** of the Today screen (so they never clash with
the tab bar). Each parses input and shows a confirmation dialog before saving.

- **Scan (barcode).** Point at a product barcode (VisionKit DataScanner). Looks
  it up in OpenFoodFacts and uses **per‑serving** nutrition when the label
  provides it (e.g. per‑slice for bread). If the product isn't found, an on‑device
  Foundation Models estimate fills in. Changing the quantity/unit recalculates
  calories and macros live.
- **Speak (voice).** Tap the mic and say what you ate ("two eggs and a slice of
  toast"). On‑device speech recognition transcribes it, then Foundation Models
  structures it into food + quantity + nutrition.
- **Type (text).** Type a food description. As you type, **previously‑eaten foods
  matching what you've typed appear** (ranked by how often/recently you've logged
  them) — tap one to reuse its exact nutrition and skip the AI parse.
- **Label (OCR).** Photograph a nutrition label. On‑device Vision text
  recognition reads it and normalizes it into a food entry.

> Plate‑photo recognition was removed — the four methods above are all on‑device
> and reliable.

**Units everywhere.** Your Metric/Imperial setting tells the parsers whether to
describe foods in grams/ml or oz/lb/cups — so it affects *every* logging method,
not just onboarding.

**Editing.** Tap any entry to edit food, quantity, unit, calories, or macros;
the unit picker offers compatible units and recomputes nutrition. Swipe to delete.

---

## 4. The Today Screen

- **Calorie ring** — a large gradient ring showing your **net** calories (food
  minus any exercise/adjustment offset) against your goal, with the number and
  "of X goal" beneath.
- **Three macro rings** — protein, carbs, fat, each toward its target.
- **Over‑limit is unmistakable.** When you exceed a target, the ring wraps a
  warm‑red overage arc back over itself (more excess → more red), the number turns
  red, and the label switches to "X over". Works for calories and each macro.
- **Exercise / adjustment offset** — log calories burned (or any adjustment) for
  the day; the calorie ring tracks net accordingly.
- **Today's food list** — every entry with its nutrition; tap to edit, swipe to
  delete.
- Pull‑to‑refresh, and the screen **auto‑refreshes** whenever data changes
  elsewhere (an import, a reset, a weigh‑in).

---

## 5. The History Screen

A scrollable, range‑aware view of your trends.

- **Range selector:** 7 Days · 30 Days · 90 Days · **All** (All spans from your
  earliest entry to today).
- **Weight section** (top): your current weight and a line graph of your weigh‑ins
  over the selected range, plus a **Log** button (see §6).
- **Nutrition trends:** a bar chart for the chosen macro (Calories / Fat / Carbs /
  Protein) with a dashed goal line; bars that exceed the goal turn red. The chart
  fits the **entire** selected range in view (no hidden horizontal scroll) with
  auto‑strided date labels.
- **This Month calendar:** dots mark days with logged food; tap a day to open its
  detail screen (that day's entries and totals).

---

## 6. Weight Tracking

- **Log anytime** — tap **Log** in the History weight section and enter your
  current weight in your units. It saves as today's measurement; re‑logging a day
  updates it. No need to weigh in daily — it's a sparse series.
- **Trend graph** — a line chart with a padded (non‑zero) y‑axis so small changes
  are visible, and an x‑axis that spans the selected window so weekly weigh‑ins
  still sit on a real date scale.
- **Starts at onboarding** — your wizard weight becomes the first data point.
- Stored canonically in kilograms; displayed in kg or lb per your unit setting.

---

## 7. Goals & Diet Styles (comprehensive)

Two independent dimensions decide your targets:

- **Weight goal → how much you eat** (calorie delta from maintenance): radical
  loss, steady loss, maintain, or responsible gain.
- **Diet style → what those calories are made of** (macro split):

  | Style          | Carbs | Protein | Fat | Good for |
  |----------------|------:|--------:|----:|----------|
  | Balanced       |  40%  |   30%   | 30% | A flexible default |
  | High Protein   |  30%  |   40%   | 30% | Building/keeping muscle |
  | Low Carb       |  20%  |   35%   | 45% | Cutting carbs |
  | Keto           |   5%  |   25%   | 70% | Ketogenic eating |
  | High Carb      |  55%  |   25%   | 20% | Endurance / big training |
  | Mediterranean  |  45%  |   25%   | 30% | Whole foods, healthy fats |

Target ranges accommodate these extremes (fat up to 300 g, carbs as low as 20 g),
so Keto and Low‑Carb produce realistic numbers. You can fine‑tune any target
afterward in Settings.

---

## 8. Settings

- **Set targets from a goal** — re‑run the setup wizard (with a **Cancel** to back
  out without changing anything; only the mandatory first‑launch run can't be
  cancelled).
- **Daily Targets** — calories, fat, carbs, protein. Each is a **tappable, typeable
  field** (number pad) that highlights while active; values snap into valid ranges
  when you finish. A reliable "Done" pill sits above the keyboard, and swiping
  down also dismisses it.
- **Units** — Metric or Imperial (drives food‑logging units app‑wide).
- **Appearance** — **Auto / Light / Dark** theme.
- **Security** — require **Face ID / Touch ID** to open the app after it's
  backgrounded.
- **Your Data** — export and import (see §9).
- **Erase All Data & Start Over** — wipes every entry, weight, and offset, resets
  settings, and relaunches the setup wizard. Confirmed before it runs.
- **About** — app icon, version, on‑device privacy summary, and credits.

---

## 9. Data Export & Import (CSV)

- **Export** writes a complete, per‑entry backup: one row per logged food
  (`date, time, food, quantity, unit, calories, fat, carbs, protein, method`) plus
  a row per day's offset. Food names with commas are properly quoted.
- **Import** auto‑detects the format from the header:
  - the **per‑entry** format restores every individual food exactly;
  - the older **daily‑totals** format still imports (one summary row per day), so
    earlier exports keep working.
- Importing is idempotent (deterministic IDs), so re‑importing the same file
  doesn't create duplicates, and Today/History refresh automatically afterward.

> Note: imported data appears in History only if its dates fall within the
> selected range — History always looks backward from today's date.

---

## 10. Demo Mode

Launching with the `-demo` argument seeds ~2 months of realistic data — varied
breakfasts/lunches/dinners/snacks, exercise offsets, and a weekly weigh‑in trend
(~84 → 81.5 kg) — for screenshots and exploration, all in an in‑memory store.

---

## 11. Design & Accessibility

- **iOS 26 Liquid Glass** chrome: glass capture buttons, a minimizing tab bar,
  and soft scroll‑edge effects, over a calm, tasteful muted palette.
- **VoiceOver** labels and values throughout (rings announce "X of Y", and over‑
  target states are spoken).
- **Reduce Motion** respected (ring animations disable accordingly).
- Light/Dark/Auto theming.

---

## 12. Under the Hood (for the curious)

- **Swift 6** with strict concurrency; a layered Swift Package (`NutritionKit`)
  with protocol "seams" so features depend on abstractions, not frameworks.
- **SwiftData** (`@ModelActor`) for local storage; **@Observable** view models.
- **Foundation Models** (Apple Intelligence) for parsing, with a deterministic
  heuristic fallback when the model is unavailable.
- **Vision** (label OCR), **VisionKit** (barcode), **Speech** (voice),
  **LocalAuthentication** (biometric lock), **Swift Charts** (graphs).
- Heavily unit‑ and UI‑tested.
