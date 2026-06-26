// App-level DI root — the only package layer the SwiftUI app imports directly.
// `@Observable` so views re-render only on the properties they read; `@MainActor`
// because it owns UI-facing settings and is created/held by the app shell.
//
// Wiring decisions (all food AI is cloud — the OpenAI proxy):
//  • foodParser  — the `/api/parse-food` proxy (heuristic stub in test/demo).
//  • photoParser — the cloud `/api/parse-photo` proxy.
//  • barcodeResolver — OpenFoodFacts, falling back to a cloud estimate of the
//    product name when OFF has the product but no nutriments.
//
// All persistence is local-only (no CloudKit); the only stored secret is the
// proxy auth token, in the Keychain.

import Foundation
import Observation
import NutritionCore
import NutritionStore
import NutritionAPI
import NutritionHealth

@Observable
@MainActor
public final class AppContainer {

    // MARK: - Services / seams
    public let store: SwiftDataStore
    public let keychain: KeychainStore
    public let apiClient: APIClient
    public let foodParser: any FoodParsing
    public let photoParser: any PhotoParsing
    public let barcodeResolver: any BarcodeResolving
    public let settings: SettingsStore
    /// Apple Health integration (behind a seam; a no-op mock in tests/demo).
    public let healthSync: any HealthSyncing

    /// StoreKit 2 subscription state — "is this person Pro?", answered on-device.
    public let subscription: SubscriptionManager
    /// The free-entry tally (iCloud-backed, no account).
    public let freeTier: FreeTierCounter
    /// Drives the paywall sheet from anywhere — a blocked log raises it.
    public var isPaywallPresented = false

    /// Per-food correction memory — the app's record of *your* numbers. The local
    /// store conforms to FoodCorrectionStoring, so this is the same SwiftData store
    /// (in-memory in test/demo); FoodConfirmModel pre-applies and remembers through it.
    public var corrections: any FoodCorrectionStoring { store }
    /// User-verified nutrition labels, keyed by barcode — the same local SwiftData
    /// store. Drives "Verify with label": confirmed values are remembered here and
    /// reused (as "Label verified") on the next scan of that product.
    public var barcodeLabels: any BarcodeLabelStoring { store }
    /// Whether HealthKit exists on this device — cached once at launch so views
    /// never call the (potentially slow) availability check during a render.
    public let isHealthAvailable: Bool

    /// Bumped whenever stored data changes in a way other screens must reflect
    /// (import, full reset, logging/editing/deleting a food, offset edits). Views
    /// key their `.task(id:)` on this so Today and History reload across tabs —
    /// not just on pull-to-refresh.
    public private(set) var dataVersion = 0

    /// Signal that stored data changed; triggers dependent views to reload.
    public func dataDidChange() { dataVersion &+= 1 }

    // MARK: - Free-tier gate (10 food entries, then Pro)

    /// Free food logs still available (0 once the limit is hit; irrelevant for Pro).
    public var freeFoodEntriesRemaining: Int {
        max(0, Constants.freeFoodEntryLimit - freeTier.count)
    }

    /// Whether the user may log another NEW food entry right now.
    public var canLogFood: Bool {
        if subscription.isSubscribed { return true }
        // Don't gate while the entitlement is still resolving at cold launch — a real
        // subscriber would otherwise be locked out for the first moment after launch.
        if !subscription.entitlementResolved { return true }
        return freeTier.count < Constants.freeFoodEntryLimit
    }

    /// Call when the user initiates logging a NEW food entry. Returns true if allowed
    /// (the caller proceeds); false if blocked — the paywall is raised.
    @discardableResult
    public func beginFoodLog() -> Bool {
        if canLogFood { return true }
        isPaywallPresented = true
        return false
    }

    /// Record a new, user-initiated food entry against the free allowance. No-op for
    /// Pro users. Deliberately NOT called for undo-restores, CSV imports, demo seeds,
    /// or onboarding's sample meal — only the real "+ / relog a usual" paths.
    public func didLogFood() {
        guard !subscription.isSubscribed else { return }
        freeTier.increment()
    }

    // MARK: - Apple Health sync glue (opt-in; each is a no-op unless its toggle is
    // on AND HealthKit is available. Failures are swallowed — never block local use.)

    public func healthSyncFood(_ entry: Entry) async {
        guard settings.healthNutritionSyncEnabled, healthSync.isAvailable() else { return }
        do { try await healthSync.syncFoodEntry(entry); settings.healthLastSyncAt = Date() }
        catch { /* non-fatal: local entry is already saved */ }
    }
    public func healthDeleteFood(id: String) async {
        guard settings.healthNutritionSyncEnabled, healthSync.isAvailable() else { return }
        try? await healthSync.deleteSyncedFoodEntry(id: id)
    }
    public func healthSyncWeight(_ entry: WeightEntry) async {
        guard settings.healthWeightSyncEnabled, healthSync.isAvailable() else { return }
        do { try await healthSync.syncWeightEntry(entry); settings.healthLastSyncAt = Date() }
        catch { /* non-fatal */ }
    }

    /// Re-sync every food entry from the last `daysBack` days (Settings → Repair).
    public func repairHealthSync(daysBack: Int = 30) async {
        guard settings.healthNutritionSyncEnabled, healthSync.isAvailable() else { return }
        let keys = LocalDate.lastDays(daysBack)
        guard let start = keys.first, let end = keys.last else { return }
        let entries = (try? await store.entries(from: start, to: end)) ?? []
        for e in entries { try? await healthSync.syncFoodEntry(e) }
        settings.healthLastSyncAt = Date()
    }

    /// Import Health weights. Days with no local weight are added silently; days
    /// that differ from an existing local weight are returned as conflicts for the
    /// user to resolve.
    public func importHealthWeights(daysBack: Int = 365) async -> [WeightConflict] {
        guard settings.healthWeightImportEnabled, healthSync.isAvailable() else { return [] }
        let imported = (try? await healthSync.importWeights(daysBack: daysBack)) ?? []
        var conflicts: [WeightConflict] = []
        for w in imported {
            let localWeights = (try? await store.weights(from: w.date, to: w.date)) ?? []
            if let localKg = localWeights.first?.weightKg {
                if abs(localKg - w.weightKg) > 0.05 {
                    conflicts.append(WeightConflict(date: w.date, localKg: localKg, healthKg: w.weightKg))
                }
            } else {
                try? await store.addWeight(w)   // no local weight that day → import silently
            }
        }
        dataDidChange()
        return conflicts
    }

    /// Apply a conflict resolution: when `useHealth`, overwrite the local day.
    public func resolveWeightConflict(_ c: WeightConflict, useHealth: Bool) async {
        guard useHealth else { return }
        let w = WeightEntry(id: WeightEntry.id(for: c.date), date: c.date, timestamp: Date(), weightKg: c.healthKg)
        try? await store.addWeight(w)
        dataDidChange()
    }

    // MARK: - Workout offsets (read-only; opt-in)

    /// Ask Health for READ access to workouts + active energy (called when the user
    /// flips the toggle on). The app never writes either type.
    public func requestWorkoutAccess() async {
        guard healthSync.isAvailable() else { return }
        try? await healthSync.requestWorkoutAccess()
    }

    /// Whether flipping the workout-offset toggle would actually surface the iOS
    /// permission sheet — so the UI shows its priming explainer only when the system
    /// will really ask (iOS won't re-present it once answered).
    public func workoutAccessNeedsPrompt() async -> Bool {
        guard healthSync.isAvailable() else { return false }
        return await healthSync.workoutAccessNeedsPrompt()
    }

    /// Recent completed workouts not yet offered, newest-first. Empty unless the
    /// toggle is on AND HealthKit is available; already-handled workouts (accepted
    /// or dismissed) are filtered out so nothing is suggested twice.
    public func pendingWorkoutOffers() async -> [WorkoutSample] {
        guard settings.healthWorkoutOffsetEnabled, healthSync.isAvailable() else { return [] }
        let since = Date().addingTimeInterval(-Double(Constants.workoutLookbackHours) * 3600)
        let workouts = (try? await healthSync.recentWorkouts(since: since)) ?? []
        return workouts.filter { !settings.isWorkoutHandled($0.id) }
    }

    /// Human-readable troubleshooter for the in-app "Check recent workouts" button:
    /// what HealthKit can actually see in the lookback window, and why each workout
    /// did or didn't become an offer (energy source, the floor, already-handled, or
    /// — when nothing comes back — the likely missing READ permission).
    public func workoutOffsetDiagnostics() async -> String {
        guard healthSync.isAvailable() else {
            return "Apple Health isn't available on this device."
        }
        guard settings.healthWorkoutOffsetEnabled else {
            return "“Offset calories from workouts” is off. Turn it on above first."
        }
        let hours = Constants.workoutLookbackHours
        let since = Date().addingTimeInterval(-Double(hours) * 3600)
        let probes = await healthSync.probeRecentWorkouts(since: since)

        guard !probes.isEmpty else {
            return """
            No workouts found in the last \(hours) hours.

            If you definitely finished one, the app probably wasn't granted read access. Open Settings ▸ Health ▸ Data Access & Devices ▸ CalorieCounter and make sure BOTH “Workouts” and “Active Energy” are ON. iOS only asks once, and these default to off.
            """
        }

        var lines = ["Found \(probes.count) workout\(probes.count == 1 ? "" : "s") in the last \(hours)h:\n"]
        for p in probes {
            let status: String
            if settings.isWorkoutHandled(p.id) {
                status = "already added or dismissed"
            } else if p.qualifies {
                status = "✓ should be offered on Today"
            } else if p.kcal <= 0 {
                status = "no Active Energy data — turn on “Active Energy” read access"
            } else {
                status = "below the \(Constants.minWorkoutMinutes)-min / \(Int(Constants.minWorkoutKcal))-kcal minimum"
            }
            lines.append("• \(p.activityName): \(p.durationMinutes) min, \(Int(p.kcal)) kcal — \(status)")
        }
        return lines.joined(separator: "\n")
    }

    /// Accept an offer: add the workout's calories to its day's offset and mark it
    /// handled. Stacks on any existing offset for that day.
    public func applyWorkoutOffset(_ workout: WorkoutSample) async {
        let current = (try? await store.offset(on: workout.date)) ?? 0
        try? await store.setOffset(current + workout.kcal, on: workout.date)
        settings.markWorkoutHandled(id: workout.id, date: workout.date)
        dataDidChange()
    }

    /// Decline an offer: mark it handled (so it's never suggested again) without
    /// touching the day's offset.
    public func dismissWorkoutOffer(_ workout: WorkoutSample) {
        settings.markWorkoutHandled(id: workout.id, date: workout.date)
    }

    /// Begin watching Apple Health for newly completed workouts in the background, so
    /// we can post a notification even while the app is closed. No-op unless the
    /// toggle is on and HealthKit is available; registers at most once per process.
    public func startWorkoutObservation() async {
        guard settings.healthWorkoutOffsetEnabled, healthSync.isAvailable() else { return }
        await healthSync.startWorkoutBackgroundDelivery {
            await AppContainer.shared.handleWorkoutBackgroundUpdate()
        }
    }

    /// Called when HealthKit wakes us for a new workout: notify (once) for any pending,
    /// not-yet-announced workout. The Today banner still handles in-app offering, so a
    /// notification is purely the proactive nudge.
    public func handleWorkoutBackgroundUpdate() async {
        let fresh = await pendingWorkoutOffers().filter { !settings.isWorkoutNotified($0.id) }
        guard !fresh.isEmpty,
              await WorkoutNotificationScheduler.requestAuthorizationIfNeeded() else { return }
        for offer in fresh {
            await WorkoutNotificationScheduler.post(offer)
            settings.markWorkoutNotified(id: offer.id, date: offer.date)
        }
    }

    /// Stop all future sync without deleting anything already in Apple Health.
    public func disconnectHealth() {
        settings.healthNutritionSyncEnabled = false
        settings.healthWeightSyncEnabled = false
        settings.healthWeightImportEnabled = false
        settings.healthWorkoutOffsetEnabled = false
    }

    /// Delete everything this app previously wrote to Apple Health.
    public func removeAllHealthData() async {
        try? await healthSync.removeAllAppData()
    }

    // MARK: - Shared instance
    public static let shared: AppContainer = {
        do { return try AppContainer() }
        catch { fatalError("AppContainer init failed: \(error)") }
    }()

    // MARK: - Designated init (injectable for tests/previews)
    public init(
        store: SwiftDataStore,
        keychain: KeychainStore,
        apiClient: APIClient,
        foodParser: any FoodParsing,
        photoParser: any PhotoParsing,
        barcodeResolver: any BarcodeResolving,
        settings: SettingsStore,
        healthSync: any HealthSyncing,
        subscription: SubscriptionManager? = nil,
        freeTier: FreeTierCounter? = nil
    ) {
        self.store = store
        self.keychain = keychain
        self.apiClient = apiClient
        self.foodParser = foodParser
        self.photoParser = photoParser
        self.barcodeResolver = barcodeResolver
        self.settings = settings
        self.healthSync = healthSync
        self.isHealthAvailable = healthSync.isAvailable()
        // Demo / UI-test builds (and unit tests) bypass StoreKit so nothing is gated
        // and no network is touched — except under `-gate`, which exercises the paywall.
        let underUnitTest = ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
        self.subscription = subscription ?? SubscriptionManager(
            bypassed: underUnitTest || ((AppContainer.isUITest || AppContainer.isDemo) && !AppContainer.isGateTest)
        )
        self.freeTier = freeTier ?? FreeTierCounter()
    }

    /// Launch in a clean, deterministic state for UI tests (in-memory store, no
    /// network model): pass `-uitest` as a launch argument.
    public static var isUITest: Bool {
        ProcessInfo.processInfo.arguments.contains("-uitest")
    }

    /// Launch with seeded sample data in an in-memory store (App Store screenshots
    /// / demos): pass `-demo` as a launch argument.
    public static var isDemo: Bool {
        ProcessInfo.processInfo.arguments.contains("-demo")
    }

    /// Force the onboarding wizard even under `-uitest` (which otherwise suppresses
    /// it), so the onboarding flow can be UI-tested deterministically: pass
    /// `-onboarding` alongside `-uitest`.
    public static var forcesOnboarding: Bool {
        ProcessInfo.processInfo.arguments.contains("-onboarding")
    }

    /// Exercise the paywall gate: don't bypass StoreKit (so the user reads as NOT Pro)
    /// and start with the free allowance spent. Pass `-gate` (with `-demo` for data).
    public static var isGateTest: Bool {
        ProcessInfo.processInfo.arguments.contains("-gate")
    }

    // MARK: - Real composition root
    /// Shared proxy password. TEMPORARY: hardcoded so the app auto-authenticates with
    /// no login screen (single-user, pre-release). Replace with a real login / secret
    /// before distributing — anyone with the binary can read this.
    private static let proxyPassword = "sub2marco"

    public convenience init() throws {
        let keychain = KeychainStore()
        let client = APIClient(tokens: keychain, autoLoginPassword: AppContainer.proxyPassword)
        let store = (AppContainer.isUITest || AppContainer.isDemo)
            ? try SwiftDataStore.make(inMemory: true)
            : try SwiftDataStore.make(url: AppContainer.storeURL())
        // The OpenAI proxy parser. Production text/voice "Analyze" goes here, and the
        // barcode resolver reuses it to estimate products OFF recognizes but has no
        // nutriments for. UI-test/demo builds swap in the deterministic heuristic.
        let cloudParser = CloudFoodParser(client: client)
        let barcode = CompositeBarcodeResolver(
            primary: OpenFoodFactsResolver(),
            estimate: { name, units in try await cloudParser.parse(text: name, units: units) }
        )
        // Outermost layer: user-verified labels win over the database/estimate, so a
        // re-scan of a verified product returns its trusted values instantly.
        let verifiedBarcode = VerifiedLabelBarcodeResolver(labels: store, fallback: barcode)
        let offline = AppContainer.isUITest || AppContainer.isDemo
        self.init(
            store: store,
            keychain: keychain,
            apiClient: client,
            // Production routes text/voice to the OpenAI proxy (/api/parse-food) — a
            // strong cloud model returns the nutrition estimate and an editable
            // breakdown, like the original web app. Online-only by design; a network
            // failure surfaces as "couldn't analyze". UI tests/demos use the
            // deterministic offline heuristic (no network).
            foodParser: offline ? HeuristicFoodParser() : cloudParser,
            photoParser: APIPhotoParser(client: client),
            barcodeResolver: verifiedBarcode,
            settings: SettingsStore(defaultUnits: .deviceDefault),
            healthSync: offline ? MockHealthSyncService() : AppleHealthKitService()
        )
    }

    // MARK: - Lifecycle
    /// Preflight hook called from the root view's `.task`. Seeds demo data in
    /// `-demo` mode; otherwise the store is already ready (all food AI is cloud).
    public func bootstrap() async {
        if AppContainer.isDemo { await seedDemoData() }
    }

    /// Seed ~2 months of realistic, individually-named meals (breakfast / lunch /
    /// dinner / snacks) so every screen — Today, Day Detail, History — shows genuine
    /// food logs for screenshots. Deterministic (rotates the catalog by day index).
    private func seedDemoData() async {
        let today = LocalDate.today()
        guard ((try? await store.entries(on: today)) ?? []).isEmpty else { return }

        // fiber (g) / sodium (mg) / sugar (g) included so every screen — Nutrition
        // Signals, History trends, insights — has realistic context data.
        struct Meal {
            let food: String; let qty: Double; let unit: String
            let kcal, fat, carbs, protein: Double
            let fiber, sodium, sugar: Double?
            let method: InputMethod
        }
        let breakfasts: [Meal] = [
            .init(food: "Greek Yogurt & Berries", qty: 1, unit: "bowl", kcal: 220, fat: 5, carbs: 28, protein: 18, fiber: 3, sodium: 80, sugar: 18, method: .label),
            .init(food: "Oatmeal with Banana", qty: 1, unit: "bowl", kcal: 310, fat: 6, carbs: 54, protein: 10, fiber: 6, sodium: 120, sugar: 14, method: .text),
            .init(food: "Scrambled Eggs & Toast", qty: 1, unit: "plate", kcal: 340, fat: 18, carbs: 24, protein: 20, fiber: 2, sodium: 520, sugar: 4, method: .text),
            .init(food: "Avocado Toast", qty: 1, unit: "piece", kcal: 290, fat: 17, carbs: 28, protein: 8, fiber: 7, sodium: 380, sugar: 3, method: .label),
            .init(food: "Protein Smoothie", qty: 1, unit: "cup", kcal: 250, fat: 4, carbs: 30, protein: 25, fiber: 4, sodium: 150, sugar: 22, method: .voice),
        ]
        let lunches: [Meal] = [
            .init(food: "Grilled Chicken Salad", qty: 1, unit: "bowl", kcal: 420, fat: 18, carbs: 22, protein: 40, fiber: 5, sodium: 480, sugar: 6, method: .text),
            .init(food: "Turkey Sandwich", qty: 1, unit: "piece", kcal: 380, fat: 12, carbs: 42, protein: 28, fiber: 4, sodium: 920, sugar: 6, method: .barcode),
            .init(food: "Chicken Burrito Bowl", qty: 1, unit: "bowl", kcal: 620, fat: 20, carbs: 68, protein: 38, fiber: 12, sodium: 1100, sugar: 8, method: .voice),
            .init(food: "Tuna Wrap", qty: 1, unit: "piece", kcal: 400, fat: 14, carbs: 40, protein: 30, fiber: 4, sodium: 850, sugar: 4, method: .label),
            .init(food: "Quinoa & Veggie Bowl", qty: 1, unit: "bowl", kcal: 480, fat: 16, carbs: 62, protein: 18, fiber: 10, sodium: 420, sugar: 7, method: .text),
        ]
        let dinners: [Meal] = [
            .init(food: "Salmon, Rice & Greens", qty: 1, unit: "plate", kcal: 560, fat: 22, carbs: 50, protein: 38, fiber: 6, sodium: 380, sugar: 4, method: .text),
            .init(food: "Spaghetti Bolognese", qty: 1, unit: "plate", kcal: 650, fat: 22, carbs: 78, protein: 32, fiber: 7, sodium: 980, sugar: 12, method: .voice),
            .init(food: "Grilled Steak & Potatoes", qty: 1, unit: "plate", kcal: 700, fat: 30, carbs: 45, protein: 50, fiber: 5, sodium: 650, sugar: 3, method: .text),
            .init(food: "Chicken Stir-fry", qty: 1, unit: "plate", kcal: 520, fat: 18, carbs: 48, protein: 38, fiber: 6, sodium: 1200, sugar: 10, method: .text),
            .init(food: "Takeout Pad Thai", qty: 1, unit: "plate", kcal: 720, fat: 26, carbs: 92, protein: 26, fiber: 4, sodium: 1900, sugar: 18, method: .voice),
        ]
        let snacks: [Meal] = [
            .init(food: "Almonds", qty: 30, unit: "g", kcal: 174, fat: 15, carbs: 6, protein: 6, fiber: 4, sodium: 0, sugar: 1, method: .label),
            .init(food: "Apple", qty: 1, unit: "piece", kcal: 95, fat: 0, carbs: 25, protein: 0, fiber: 4, sodium: 2, sugar: 19, method: .barcode),
            .init(food: "Protein Bar", qty: 1, unit: "piece", kcal: 200, fat: 7, carbs: 22, protein: 20, fiber: 6, sodium: 200, sugar: 14, method: .barcode),
            .init(food: "Greek Yogurt", qty: 1, unit: "cup", kcal: 120, fat: 0, carbs: 8, protein: 18, fiber: nil, sodium: 60, sugar: 6, method: .voice),
        ]

        func confidence(for method: InputMethod) -> NutritionConfidence {
            switch method { case .barcode: return .barcode; case .label: return .label; default: return .estimated }
        }

        let cal = Calendar.current
        let now = Date()

        for offset in 0..<61 {
            guard let day = cal.date(byAdding: .day, value: -offset, to: now) else { continue }
            let key = LocalDate.key(for: day)
            var seq = 0
            func log(_ meal: Meal, hour: Int) async {
                let ts = cal.date(bySettingHour: hour, minute: (seq * 11) % 60, second: 0, of: day) ?? day
                let entry = Entry(id: "demo-\(key)-\(seq)", date: key, timestamp: ts,
                                  food: meal.food, quantity: meal.qty, unit: meal.unit,
                                  kcal: meal.kcal, fat: meal.fat, carbs: meal.carbs, protein: meal.protein,
                                  method: meal.method,
                                  fiber: meal.fiber, sodium: meal.sodium, sugar: meal.sugar,
                                  nutritionConfidence: confidence(for: meal.method))
                seq += 1
                try? await store.add(entry)
            }
            await log(breakfasts[offset % breakfasts.count], hour: 8)
            await log(lunches[(offset + 1) % lunches.count], hour: 13)
            await log(dinners[(offset + 2) % dinners.count], hour: 19)
            if offset % 2 == 0 { await log(snacks[offset % snacks.count], hour: 16) }
            if offset % 3 == 0 { try? await store.setOffset(Double(260 + (offset % 4) * 70), on: key) }

            // ~3 weigh-ins a week (uneven 2–3 day gaps), jagging day-to-day around a
            // slow downward trend (~83.5 kg → ~80.6 kg over 2 months) — like real data.
            if offset % 7 == 0 || offset % 7 == 2 || offset % 7 == 5 {
                let o = Double(offset)
                let trend = 80.6 + o * 0.048
                let noise = 0.6 * sin(o * 1.3) + 0.35 * sin(o * 0.7 + 1) + 0.2 * sin(o * 2.9)
                let kg = ((trend + noise) * 10).rounded() / 10
                try? await store.addWeight(WeightEntry(id: WeightEntry.id(for: key), date: key, timestamp: day, weightKg: kg))
            }
        }
    }

    /// Whether the plate-photo proxy has a stored auth token.
    public func isPhotoProxyAuthenticated() async -> Bool {
        await keychain.authToken() != nil
    }

    /// Exchange the shared password for the proxy token (stored in the Keychain).
    public func authenticatePhotoProxy(password: String) async throws {
        try await apiClient.login(password: password)
    }

    /// Clear the stored proxy token (sign out of the photo feature).
    public func signOutPhotoProxy() async {
        await keychain.tokenRejected()
    }

    private static func storeURL() -> URL? {
        guard let dir = try? FileManager.default.url(
            for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true
        ) else { return nil }
        return dir.appendingPathComponent("CalorieCounter.store")
    }
}
