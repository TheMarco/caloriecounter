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
            settings: SettingsStore()
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

    private func seedDemoData() async {
        let today = LocalDate.today()
        guard ((try? await store.entries(on: today)) ?? []).isEmpty else { return }
        let now = Date()
        let samples: [(String, Double, String, Double, Double, Double, Double, InputMethod)] = [
            ("Greek Yogurt & Berries", 1, "bowl", 180, 4, 22, 16, .voice),
            ("Grilled Chicken Breast", 150, "g", 248, 5, 0, 46, .text),
            ("Avocado Toast", 1, "piece", 290, 17, 28, 8, .photo),
            ("Banana", 1, "piece", 105, 0, 27, 1, .barcode),
            ("Almonds", 30, "g", 174, 15, 6, 6, .text),
        ]
        for (i, s) in samples.enumerated() {
            let entry = Entry(
                id: "demo-\(i)", date: today, timestamp: now.addingTimeInterval(Double(-i) * 1800),
                food: s.0, quantity: s.1, unit: s.2, kcal: s.3, fat: s.4, carbs: s.5, protein: s.6, method: s.7
            )
            try? await store.add(entry)
        }
        try? await store.setOffset(320, on: today)
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
