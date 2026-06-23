// APIClient + APIPhotoParser + OpenFoodFactsResolver behavior, proven against the
// stubbed URLProtocol (no network). Covers request construction, the cookie-token
// auth model the web proxy actually uses (`calorie-auth` Set-Cookie ↔ Cookie
// header), error mapping, the 401 re-auth hook, the plate-photo parse flow, and
// OFF barcode decoding.
//
// ALL stub-using tests live in this ONE `.serialized` suite on purpose: the stub
// holds global state, and `.serialized` only serializes within a suite — two
// stub-using suites would run in parallel and clobber each other's handler.

import Testing
import Foundation
@testable import NutritionAPI
import NutritionCore

@Suite("Proxy client + OpenFoodFacts (stubbed transport)", .serialized)
struct APIClientTests {

    private func makeClient(tokens: TokenProviding) -> APIClient {
        APIClient(environment: .production, session: StubURLProtocol.makeSession(), tokens: tokens)
    }

    private func makeResolver() -> OpenFoodFactsResolver {
        OpenFoodFactsResolver(session: StubURLProtocol.makeSession())
    }

    // MARK: - login (cookie token model)

    @Test("login posts {password} to /api/auth and stores the calorie-auth cookie token")
    func loginExtractsCookieToken() async throws {
        StubURLProtocol.stub { _ in
            .json(200,
                  headers: ["Set-Cookie": "calorie-auth=1700000000.abcdef; Path=/; HttpOnly; SameSite=Strict"],
                  #"{"success":true}"#)
        }
        let tokens = RecordingTokenStore()
        try await makeClient(tokens: tokens).login(password: "hunter2")

        // Token captured from Set-Cookie and persisted.
        #expect(await tokens.token == "1700000000.abcdef")
        #expect(await tokens.saves == 1)

        let cap = try #require(StubURLProtocol.captured())
        #expect(cap.method == "POST")
        #expect(cap.url?.path == "/api/auth")
        #expect(cap.header("Authorization") == nil)         // login is unauthenticated
        #expect(cap.bodyJSON?["password"] as? String == "hunter2")
    }

    @Test("login on a wrong password (401) throws .unauthorized and stores nothing")
    func loginWrongPassword() async throws {
        StubURLProtocol.stub { _ in .json(401, #"{"error":"Incorrect password"}"#) }
        let tokens = RecordingTokenStore()
        await #expect(throws: APIError.unauthorized) {
            try await makeClient(tokens: tokens).login(password: "nope")
        }
        #expect(await tokens.saves == 0)
    }

    @Test("login succeeding without a Set-Cookie throws .invalidResponse")
    func loginMissingCookie() async throws {
        StubURLProtocol.stub { _ in .json(200, #"{"success":true}"#) }
        let tokens = RecordingTokenStore()
        await #expect(throws: APIError.invalidResponse) {
            try await makeClient(tokens: tokens).login(password: "x")
        }
    }

    // MARK: - authed requests attach the cookie

    @Test("an authed request attaches Cookie: calorie-auth=<token>")
    func authedRequestAttachesCookie() async throws {
        StubURLProtocol.stub { _ in .json(200, #"{"success":true,"data":{"food":"X","quantity":1,"unit":"plate","kcal":100}}"#) }
        let parser = APIPhotoParser(client: makeClient(tokens: RecordingTokenStore("tok-123")))
        _ = try await parser.parse(imageData: Data([0xFF, 0xD8]), units: .metric, details: .default)

        let cap = try #require(StubURLProtocol.captured())
        #expect(cap.header("Cookie") == "calorie-auth=tok-123")
        #expect(cap.url?.path == "/api/parse-photo")
    }

    @Test("an authed request with no token throws .unauthorized before hitting the network")
    func missingTokenShortCircuits() async throws {
        StubURLProtocol.stub { _ in .json(200, "{}") }
        let parser = APIPhotoParser(client: makeClient(tokens: RecordingTokenStore(nil)))
        await #expect(throws: APIError.unauthorized) {
            _ = try await parser.parse(imageData: Data([0xFF]), units: .metric, details: .default)
        }
    }

    @Test("a 401 on an authed call maps to .unauthorized and fires the re-auth hook once")
    func unauthorizedFiresReauth() async throws {
        StubURLProtocol.stub { _ in .json(401, #"{"error":"Unauthorized"}"#) }
        let tokens = RecordingTokenStore("stale")
        let parser = APIPhotoParser(client: makeClient(tokens: tokens))
        await #expect(throws: APIError.unauthorized) {
            _ = try await parser.parse(imageData: Data([0xFF]), units: .metric, details: .default)
        }
        #expect(await tokens.rejections == 1)
    }

    // MARK: - plate photo parse flow

    @Test("parse encodes a data-URL image + units + details and maps the response to ParsedFood")
    func photoParseSuccess() async throws {
        StubURLProtocol.stub { _ in
            .json(200, #"""
            {"success":true,"data":{"food":"Pasta with sauce","quantity":1,"unit":"plate","kcal":700,"fat":20,"carbs":90,"protein":25,"notes":"large plate"}}
            """#)
        }
        let parser = APIPhotoParser(client: makeClient(tokens: RecordingTokenStore("tok")))
        let details = PhotoDetails(plateSize: .extraLarge, servingType: .restaurant, additionalDetails: "shared")
        let food = try await parser.parse(imageData: Data([0xFF, 0xD8, 0xFF]), units: .imperial, details: details)

        #expect(food == ParsedFood(food: "Pasta with sauce", quantity: 1, unit: "plate",
                                   kcal: 700, fat: 20, carbs: 90, protein: 25, notes: "large plate"))

        // Wire body: imageData is a base64 data URL; units + web-faithful detail raw values.
        let cap = try #require(StubURLProtocol.captured())
        let imageData = try #require(cap.bodyJSON?["imageData"] as? String)
        #expect(imageData.hasPrefix("data:image/jpeg;base64,"))
        #expect(cap.bodyJSON?["units"] as? String == "imperial")
        let sentDetails = cap.bodyJSON?["details"] as? [String: Any]
        #expect(sentDetails?["plateSize"] as? String == "extra-large")
        #expect(sentDetails?["servingType"] as? String == "restaurant")
        #expect(sentDetails?["additionalDetails"] as? String == "shared")
    }

    @Test("parse maps missing macro fields to zero")
    func photoParseMissingMacros() async throws {
        StubURLProtocol.stub { _ in .json(200, #"{"success":true,"data":{"food":"Apple","quantity":1,"unit":"piece","kcal":95}}"#) }
        let parser = APIPhotoParser(client: makeClient(tokens: RecordingTokenStore("tok")))
        let food = try await parser.parse(imageData: Data([0xFF]), units: .metric, details: .default)
        #expect(food == ParsedFood(food: "Apple", quantity: 1, unit: "piece", kcal: 95, fat: 0, carbs: 0, protein: 0))
    }

    @Test("parse throws when the server reports no food (success:false)")
    func photoParseNoFood() async throws {
        StubURLProtocol.stub { _ in .json(200, #"{"success":false,"error":"No food visible in this image"}"#) }
        let parser = APIPhotoParser(client: makeClient(tokens: RecordingTokenStore("tok")))
        await #expect(throws: APIError.self) {
            _ = try await parser.parse(imageData: Data([0xFF]), units: .metric, details: .default)
        }
    }

    // MARK: - OpenFoodFacts barcode resolver

    @Test("a full nutriments payload maps to a 100 g serving ParsedFood")
    func offFullNutriments() async throws {
        StubURLProtocol.stub { _ in
            .json(200, #"""
            {"status":1,"product":{"product_name":"Greek Yogurt",
              "nutriments":{"energy-kcal_100g":59,"fat_100g":0.4,"carbohydrates_100g":3.6,"proteins_100g":10}}}
            """#)
        }
        let food = try await makeResolver().resolve(code: "5000112637922", units: .metric)
        #expect(food == ParsedFood(food: "Greek Yogurt", quantity: 100, unit: "g",
                                   kcal: 59, fat: 0.4, carbs: 3.6, protein: 10))

        let cap = try #require(StubURLProtocol.captured())
        #expect(cap.url?.absoluteString == "https://world.openfoodfacts.org/api/v0/product/5000112637922.json")
        #expect(cap.header("User-Agent")?.contains("caloriecounter.ai-created.com") == true)
    }

    @Test("product_name falls back to product_name_en then brands")
    func offProductNameFallback() async throws {
        StubURLProtocol.stub { _ in
            .json(200, #"""
            {"status":1,"product":{"product_name":"","brands":"StoreBrand",
              "nutriments":{"energy-kcal_100g":120,"fat_100g":5,"carbohydrates_100g":15,"proteins_100g":3}}}
            """#)
        }
        let food = try await makeResolver().resolve(code: "00000000", units: .metric)
        #expect(food.food == "StoreBrand")
    }

    @Test("a product with no energy-kcal_100g throws .missingNutriments carrying the name")
    func offMissingNutriments() async throws {
        StubURLProtocol.stub { _ in
            .json(200, #"{"status":1,"product":{"product_name":"Mystery","nutriments":{"fat_100g":5}}}"#)
        }
        do {
            _ = try await makeResolver().resolve(code: "123", units: .metric)
            Issue.record("expected .missingNutriments to be thrown")
        } catch let OpenFoodFactsError.missingNutriments(name) {
            #expect(name == "Mystery")
        }
    }

    @Test("status 0 (unknown product) throws .productNotFound")
    func offUnknownProduct() async throws {
        StubURLProtocol.stub { _ in .json(200, #"{"status":0,"status_verbose":"product not found"}"#) }
        await #expect(throws: OpenFoodFactsError.productNotFound) {
            _ = try await makeResolver().resolve(code: "999", units: .metric)
        }
    }

    @Test("explicit per-serving data is preferred (matches the package label)")
    func offPerServing() async throws {
        StubURLProtocol.stub { _ in
            .json(200, #"""
            {"status":1,"product":{"product_name":"Killer Bread","serving_size":"1 slice (45 g)","serving_quantity":45,
              "nutriments":{"energy-kcal_100g":244,"energy-kcal_serving":110,
                            "fat_100g":4,"fat_serving":1.8,
                            "carbohydrates_100g":49,"carbohydrates_serving":22,
                            "proteins_100g":11,"proteins_serving":5}}}
            """#)
        }
        let food = try await makeResolver().resolve(code: "1", units: .metric)
        #expect(food.quantity == 1)
        #expect(food.unit == "serving")
        #expect(food.kcal == 110)        // the per-slice value, not 244 (per-100g)
        #expect(food.fat == 1.8)
        #expect(food.carbs == 22)
        #expect(food.protein == 5)
        #expect(food.notes?.contains("1 slice (45 g)") == true)
    }

    @Test("per-serving is computed from per-100g × serving weight when not explicit")
    func offComputedPerServing() async throws {
        StubURLProtocol.stub { _ in
            .json(200, #"""
            {"status":1,"product":{"product_name":"Cereal","serving_quantity":30,
              "nutriments":{"energy-kcal_100g":380,"fat_100g":5,"carbohydrates_100g":80,"proteins_100g":8}}}
            """#)
        }
        let food = try await makeResolver().resolve(code: "2", units: .metric)
        #expect(food.quantity == 1)
        #expect(food.unit == "serving")
        #expect(food.kcal == 114)        // 380 × 30/100
        #expect(abs(food.fat - 1.5) < 1e-9)
        #expect(abs(food.carbs - 24) < 1e-9)
        #expect(food.notes?.contains("30 g") == true)
    }

    @Test("nutriment values delivered as strings are still parsed")
    func offStringValuedNutriments() async throws {
        StubURLProtocol.stub { _ in
            .json(200, #"""
            {"status":1,"product":{"product_name":"Soda",
              "nutriments":{"energy-kcal_100g":"42","fat_100g":"0","carbohydrates_100g":"10.6","proteins_100g":"0"}}}
            """#)
        }
        let food = try await makeResolver().resolve(code: "1", units: .metric)
        #expect(food.kcal == 42)
        #expect(food.carbs == 10.6)
    }
}
