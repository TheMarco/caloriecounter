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

    // MARK: - Real composition root
    public convenience init() throws {
        let keychain = KeychainStore()
        let client = APIClient(tokens: keychain)
        let store = AppContainer.isUITest
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
    /// Preflight hook called from the root view's `.task`. The store is ready and
    /// FM availability is resolved at wiring time; reserved for future warm-up.
    public func bootstrap() async {}

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
