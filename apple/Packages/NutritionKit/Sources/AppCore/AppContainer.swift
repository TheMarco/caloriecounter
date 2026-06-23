// App-level DI root — the only package layer the SwiftUI app imports directly.
// `@Observable` so views re-render only on the properties they read; `@MainActor`
// because it owns UI-facing settings and is created/held by the app shell.
//
// Wiring decisions:
//  • foodParser  — Foundation Models if available, else the heuristic fallback.
//  • photoParser — the cloud `/api/parse-photo` proxy (the only cloud call).
//  • labelReader — on-device Vision OCR.
//  • barcodeResolver — OpenFoodFacts, falling back to an on-device FM estimate
//    when OFF has the product but no nutriments.
//
// All persistence is local-only (no CloudKit); the only stored secret is the
// proxy auth token, in the Keychain.

import Foundation
import Observation
import NutritionCore
import NutritionStore
import NutritionAPI
import NutritionAI

@Observable
@MainActor
public final class AppContainer {

    // MARK: - Services / seams
    public let store: SwiftDataStore
    public let keychain: KeychainStore
    public let apiClient: APIClient
    public let foodParser: any FoodParsing
    public let photoParser: any PhotoParsing
    public let labelReader: any LabelReading
    public let barcodeResolver: any BarcodeResolving
    public let settings: SettingsStore

    /// Bumped whenever stored data changes in a way other screens must reflect
    /// (import, full reset, logging/editing/deleting a food, offset edits). Views
    /// key their `.task(id:)` on this so Today and History reload across tabs —
    /// not just on pull-to-refresh.
    public private(set) var dataVersion = 0

    /// Signal that stored data changed; triggers dependent views to reload.
    public func dataDidChange() { dataVersion &+= 1 }

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
        labelReader: any LabelReading,
        barcodeResolver: any BarcodeResolving,
        settings: SettingsStore
    ) {
        self.store = store
        self.keychain = keychain
        self.apiClient = apiClient
        self.foodParser = foodParser
        self.photoParser = photoParser
        self.labelReader = labelReader
        self.barcodeResolver = barcodeResolver
        self.settings = settings
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

    // MARK: - Real composition root
    public convenience init() throws {
        let keychain = KeychainStore()
        let client = APIClient(tokens: keychain)
        let store = (AppContainer.isUITest || AppContainer.isDemo)
            ? try SwiftDataStore.make(inMemory: true)
            : try SwiftDataStore.make(url: AppContainer.storeURL())
        let barcode = CompositeBarcodeResolver(
            primary: OpenFoodFactsResolver(),
            estimate: { name, units in
                try await FoundationModelsBarcodeEstimator().estimate(productName: name, units: units)
            }
        )
        self.init(
            store: store,
            keychain: keychain,
            apiClient: client,
            foodParser: AppContainer.makeFoodParser(),
            photoParser: APIPhotoParser(client: client),
            labelReader: VisionLabelReader(),
            barcodeResolver: barcode,
            settings: SettingsStore(defaultUnits: .deviceDefault)
        )
    }

    /// Foundation Models when usable, otherwise the deterministic heuristic.
    /// UI tests force the heuristic parser so parses are deterministic.
    public static func makeFoodParser() -> any FoodParsing {
        if isUITest { return HeuristicFoodParser() }
        return FoundationModelsFoodParser.isAvailable ? FoundationModelsFoodParser() : HeuristicFoodParser()
    }

    // MARK: - Lifecycle
    /// Preflight hook called from the root view's `.task`. Seeds demo data in
    /// `-demo` mode; otherwise the store is ready and FM availability is resolved
    /// at wiring time.
    public func bootstrap() async {
        if AppContainer.isDemo { await seedDemoData() }
    }

    /// Seed ~2 months of realistic, individually-named meals (breakfast / lunch /
    /// dinner / snacks) so every screen — Today, Day Detail, History — shows genuine
    /// food logs for screenshots. Deterministic (rotates the catalog by day index).
    private func seedDemoData() async {
        let today = LocalDate.today()
        guard ((try? await store.entries(on: today)) ?? []).isEmpty else { return }

        struct Meal { let food: String; let qty: Double; let unit: String; let kcal, fat, carbs, protein: Double; let method: InputMethod }
        let breakfasts: [Meal] = [
            .init(food: "Greek Yogurt & Berries", qty: 1, unit: "bowl", kcal: 220, fat: 5, carbs: 28, protein: 18, method: .voice),
            .init(food: "Oatmeal with Banana", qty: 1, unit: "bowl", kcal: 310, fat: 6, carbs: 54, protein: 10, method: .text),
            .init(food: "Scrambled Eggs & Toast", qty: 1, unit: "plate", kcal: 340, fat: 18, carbs: 24, protein: 20, method: .text),
            .init(food: "Avocado Toast", qty: 1, unit: "piece", kcal: 290, fat: 17, carbs: 28, protein: 8, method: .label),
            .init(food: "Protein Smoothie", qty: 1, unit: "cup", kcal: 250, fat: 4, carbs: 30, protein: 25, method: .voice),
        ]
        let lunches: [Meal] = [
            .init(food: "Grilled Chicken Salad", qty: 1, unit: "bowl", kcal: 420, fat: 18, carbs: 22, protein: 40, method: .text),
            .init(food: "Turkey Sandwich", qty: 1, unit: "piece", kcal: 380, fat: 12, carbs: 42, protein: 28, method: .text),
            .init(food: "Chicken Burrito Bowl", qty: 1, unit: "bowl", kcal: 620, fat: 20, carbs: 68, protein: 38, method: .voice),
            .init(food: "Tuna Wrap", qty: 1, unit: "piece", kcal: 400, fat: 14, carbs: 40, protein: 30, method: .label),
            .init(food: "Quinoa & Veggie Bowl", qty: 1, unit: "bowl", kcal: 480, fat: 16, carbs: 62, protein: 18, method: .text),
        ]
        let dinners: [Meal] = [
            .init(food: "Salmon, Rice & Greens", qty: 1, unit: "plate", kcal: 560, fat: 22, carbs: 50, protein: 38, method: .text),
            .init(food: "Spaghetti Bolognese", qty: 1, unit: "plate", kcal: 650, fat: 22, carbs: 78, protein: 32, method: .voice),
            .init(food: "Grilled Steak & Potatoes", qty: 1, unit: "plate", kcal: 700, fat: 30, carbs: 45, protein: 50, method: .text),
            .init(food: "Chicken Stir-fry", qty: 1, unit: "plate", kcal: 520, fat: 18, carbs: 48, protein: 38, method: .text),
            .init(food: "Veggie Curry & Rice", qty: 1, unit: "plate", kcal: 540, fat: 18, carbs: 72, protein: 16, method: .voice),
        ]
        let snacks: [Meal] = [
            .init(food: "Almonds", qty: 30, unit: "g", kcal: 174, fat: 15, carbs: 6, protein: 6, method: .label),
            .init(food: "Apple", qty: 1, unit: "piece", kcal: 95, fat: 0, carbs: 25, protein: 0, method: .barcode),
            .init(food: "Protein Bar", qty: 1, unit: "piece", kcal: 200, fat: 7, carbs: 22, protein: 20, method: .barcode),
            .init(food: "Greek Yogurt", qty: 1, unit: "cup", kcal: 120, fat: 0, carbs: 8, protein: 18, method: .voice),
        ]

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
                                  method: meal.method)
                seq += 1
                try? await store.add(entry)
            }
            await log(breakfasts[offset % breakfasts.count], hour: 8)
            await log(lunches[(offset + 1) % lunches.count], hour: 13)
            await log(dinners[(offset + 2) % dinners.count], hour: 19)
            if offset % 2 == 0 { await log(snacks[offset % snacks.count], hour: 16) }
            if offset % 3 == 0 { try? await store.setOffset(Double(260 + (offset % 4) * 70), on: key) }

            // A weekly weigh-in trending gently down (~84 kg → ~81.5 kg over 2 months).
            if offset % 7 == 0 {
                let kg = 81.5 + Double(offset) * 0.04 + Double((offset / 7) % 3) * 0.2 - 0.2
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
