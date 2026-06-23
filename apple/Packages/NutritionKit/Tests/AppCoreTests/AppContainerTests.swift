// AppContainer wiring, proven with an in-memory store + stub seams (no disk, no
// network, no model). Confirms the composition root exposes working dependencies
// and reflects auth state from the Keychain token.

import Testing
import Foundation
@testable import AppCore
import NutritionCore
import NutritionStore
import NutritionAPI
import NutritionAI

private struct StubFoodParser: FoodParsing {
    func parse(text: String, units: UnitSystem) async throws -> ParsedFood {
        ParsedFood(food: text, quantity: 1, unit: "g", kcal: 1)
    }
}
private struct StubPhotoParser: PhotoParsing {
    func parse(imageData: Data, units: UnitSystem, details: PhotoDetails) async throws -> ParsedFood {
        ParsedFood(food: "photo", quantity: 1, unit: "plate", kcal: 1)
    }
}
private struct StubLabelReader: LabelReading {
    func readNutritionLabel(imageData: Data, units: UnitSystem) async throws -> ParsedFood {
        ParsedFood(food: "label", quantity: 1, unit: "serving", kcal: 1)
    }
}
private struct StubBarcode: BarcodeResolving {
    func resolve(code: String, units: UnitSystem) async throws -> ParsedFood {
        ParsedFood(food: "barcode", quantity: 100, unit: "g", kcal: 1)
    }
}

@MainActor
@Suite("AppContainer")
struct AppContainerTests {

    private func makeContainer(keychainToken: String? = nil) throws -> AppContainer {
        let svc = "com.test.caloriecounter.container.\(UUID().uuidString)"
        let keychain = KeychainStore(service: svc)
        let store = try SwiftDataStore.make(inMemory: true)
        let settings = SettingsStore(defaults: UserDefaults(suiteName: "test-c-\(UUID().uuidString)")!)
        return AppContainer(
            store: store,
            keychain: keychain,
            apiClient: APIClient(tokens: keychain),
            foodParser: StubFoodParser(),
            photoParser: StubPhotoParser(),
            labelReader: StubLabelReader(),
            barcodeResolver: StubBarcode(),
            settings: settings
        )
    }

    @Test("the injected store is live (entries round-trip through the container)")
    func storeWired() async throws {
        let container = try makeContainer()
        let entry = Entry(id: "e1", date: "2026-06-22", timestamp: Date(timeIntervalSince1970: 0),
                          food: "Egg", quantity: 1, unit: "piece", kcal: 78, fat: 5, carbs: 0.6, protein: 6, method: .text)
        try await container.store.add(entry)
        #expect(try await container.store.entries(on: "2026-06-22").first == entry)
    }

    @Test("seams are reachable through the container")
    func seamsWired() async throws {
        let container = try makeContainer()
        #expect(try await container.foodParser.parse(text: "apple", units: .metric).food == "apple")
        #expect(try await container.photoParser.parse(imageData: Data(), units: .metric, details: .default).food == "photo")
        #expect(try await container.labelReader.readNutritionLabel(imageData: Data(), units: .metric).food == "label")
        #expect(try await container.barcodeResolver.resolve(code: "1", units: .metric).food == "barcode")
        #expect(container.settings.units == .metric)
    }

    @Test("photo-proxy auth state reflects the Keychain token")
    func authState() async throws {
        let container = try makeContainer()
        #expect(await container.isPhotoProxyAuthenticated() == false)
        try await container.keychain.saveToken("1700000000.sig")
        #expect(await container.isPhotoProxyAuthenticated() == true)
    }

    @Test("signOutPhotoProxy clears the stored token; bootstrap is a safe no-op")
    func signOutAndBootstrap() async throws {
        let container = try makeContainer()
        try await container.keychain.saveToken("tok")
        #expect(await container.isPhotoProxyAuthenticated() == true)

        await container.signOutPhotoProxy()
        #expect(await container.isPhotoProxyAuthenticated() == false)

        await container.bootstrap()   // must not throw or change state
        #expect(await container.isPhotoProxyAuthenticated() == false)
    }

    @Test("foodParser selection falls back to the heuristic parser when FM is unavailable")
    func foodParserSelection() {
        let parser = AppContainer.makeFoodParser()
        if FoundationModelsFoodParser.isAvailable {
            #expect(parser is FoundationModelsFoodParser)
        } else {
            #expect(parser is HeuristicFoodParser)
        }
    }
}
