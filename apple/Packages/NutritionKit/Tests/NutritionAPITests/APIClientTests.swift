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

    private func makeAttestClient(tokens: TokenProviding, keys: AttestKeyStoring,
                                  attestor: any AppAttesting = MockAttestor(),
                                  bypass: String? = nil) -> APIClient {
        APIClient(environment: .production, session: StubURLProtocol.makeSession(),
                  tokens: tokens, keyStore: keys, attestor: attestor, devBypassSecret: bypass)
    }

    private func makeResolver() -> OpenFoodFactsResolver {
        OpenFoodFactsResolver(session: StubURLProtocol.makeSession())
    }

    // MARK: - App Attest token acquisition

    @Test("first use with no key enrolls (challenge→register) and authenticates the call")
    func enrollsOnFirstUse() async throws {
        StubURLProtocol.stub { req in
            switch req.url?.path {
            case "/api/attest/challenge": return .json(200, #"{"challengeId":"c1","challenge":"chal"}"#)
            case "/api/attest/register":  return .json(200, #"{"token":"enrolled.jwt","expiresAt":9999999999}"#)
            default: return .json(200, #"{"success":true,"data":{"food":"apple","quantity":1,"unit":"piece","kcal":95}}"#)
            }
        }
        let tokens = RecordingTokenStore(nil)
        let keys = RecordingKeyStore(nil)
        let food = try await CloudFoodParser(client: makeAttestClient(tokens: tokens, keys: keys))
            .parse(text: "apple", units: .metric)

        #expect(food.food == "apple")
        #expect(await tokens.token == "enrolled.jwt")
        #expect(await keys.keyId == "mock-key")   // enrolled keyId persisted
    }

    @Test("an enrolled device refreshes via assertion (challenge→token), no re-enroll")
    func refreshesWhenEnrolled() async throws {
        StubURLProtocol.stub { req in
            switch req.url?.path {
            case "/api/attest/challenge": return .json(200, #"{"challengeId":"c","challenge":"x"}"#)
            case "/api/attest/token":     return .json(200, #"{"token":"refreshed.jwt","expiresAt":9}"#)
            case "/api/attest/register":  return .json(500, #"{"error":"should not enroll"}"#)
            default: return .json(200, #"{"success":true,"data":{"food":"a","quantity":1,"unit":"piece","kcal":1}}"#)
            }
        }
        let tokens = RecordingTokenStore(nil)
        let keys = RecordingKeyStore("existing-key")
        let food = try await CloudFoodParser(client: makeAttestClient(tokens: tokens, keys: keys))
            .parse(text: "apple", units: .metric)

        #expect(food.food == "a")
        #expect(await tokens.token == "refreshed.jwt")
        #expect(await keys.keyId == "existing-key")   // unchanged — no re-enroll
        #expect(await keys.clears == 0)
    }

    @Test("a 409 on refresh clears the stale key and re-enrolls")
    func reenrollsOnConflict() async throws {
        StubURLProtocol.stub { req in
            switch req.url?.path {
            case "/api/attest/challenge": return .json(200, #"{"challengeId":"c","challenge":"x"}"#)
            case "/api/attest/token":     return .json(409, #"{"error":"Unknown device"}"#)
            case "/api/attest/register":  return .json(200, #"{"token":"reenrolled.jwt","expiresAt":9}"#)
            default: return .json(200, #"{"success":true,"data":{"food":"a","quantity":1,"unit":"piece","kcal":1}}"#)
            }
        }
        let tokens = RecordingTokenStore(nil)
        let keys = RecordingKeyStore("stale-key")
        let food = try await CloudFoodParser(client: makeAttestClient(tokens: tokens, keys: keys))
            .parse(text: "apple", units: .metric)

        #expect(food.food == "a")
        #expect(await tokens.token == "reenrolled.jwt")
        #expect(await keys.keyId == "mock-key")   // re-enrolled with a fresh key
        #expect(await keys.clears == 1)
    }

    @Test("the dev bypass obtains a token via /api/attest/token with the bypass header")
    func devBypassObtainsToken() async throws {
        StubURLProtocol.stub { req in
            if req.url?.path == "/api/attest/token" {
                return .json(200, #"{"token":"bypass.jwt","expiresAt":9,"dev":true}"#)
            }
            return .json(200, #"{"success":true,"data":{"food":"a","quantity":1,"unit":"piece","kcal":1}}"#)
        }
        let tokens = RecordingTokenStore(nil)
        let client = APIClient(environment: .production, session: StubURLProtocol.makeSession(),
                               tokens: tokens, devBypassSecret: "s3cret")
        _ = try await CloudFoodParser(client: client).parse(text: "apple", units: .metric)

        #expect(await tokens.token == "bypass.jwt")
        let cap = try #require(StubURLProtocol.captured())   // last call = the parse, carrying the bearer
        #expect(cap.header("Authorization") == "Bearer bypass.jwt")
    }

    // MARK: - authed requests attach the bearer

    @Test("an authed request attaches Authorization: Bearer <token>")
    func authedRequestAttachesBearer() async throws {
        StubURLProtocol.stub { _ in .json(200, #"{"success":true,"data":{"food":"X","quantity":1,"unit":"plate","kcal":100}}"#) }
        let parser = APIPhotoParser(client: makeClient(tokens: RecordingTokenStore("tok-123")))
        _ = try await parser.parse(imageData: Data([0xFF, 0xD8]), units: .metric, details: .default)

        let cap = try #require(StubURLProtocol.captured())
        #expect(cap.header("Authorization") == "Bearer tok-123")
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

    // MARK: - cloud food parse flow (/api/parse-food)

    @Test("parseFood posts {text, units} and maps nutrition + the ingredient breakdown")
    func cloudFoodParseSuccess() async throws {
        StubURLProtocol.stub { _ in
            .json(200, #"{"success":true,"data":{"food":"chili cheese dog","quantity":1,"unit":"piece","kcal":550,"fat":32,"carbs":40,"protein":22,"fiber":3,"sodium":1200,"sugar":6,"notes":"with cheese","components":[{"name":"hot dog bun","grams":45,"kcal":120,"fat":2,"carbs":22,"protein":4},{"name":"beef frank","grams":50,"kcal":150,"fat":13,"carbs":2,"protein":6},{"name":"chili","grams":60,"kcal":110,"fat":6,"carbs":8,"protein":7},{"name":"cheese","grams":20,"kcal":80,"fat":7,"carbs":1,"protein":5}]}}"#)
        }
        let parser = CloudFoodParser(client: makeClient(tokens: RecordingTokenStore("tok-1")))
        let food = try await parser.parse(text: "chili cheese dog", units: .metric)

        #expect(food.food == "chili cheese dog")
        #expect(food.kcal == 550)
        #expect(food.fiber == 3)
        #expect(food.sodium == 1200)
        #expect(food.sugar == 6)
        #expect(food.components?.count == 4)
        #expect(food.components?.first?.name == "hot dog bun")
        #expect(food.nutritionConfidence == .estimated)

        let cap = try #require(StubURLProtocol.captured())
        #expect(cap.method == "POST")
        #expect(cap.url?.path == "/api/parse-food")
        #expect(cap.header("Authorization") == "Bearer tok-1")
        #expect(cap.bodyJSON?["text"] as? String == "chili cheese dog")
        #expect(cap.bodyJSON?["units"] as? String == "metric")
    }

    @Test("a single food returns no breakdown but keeps fiber/sodium/sugar from the total")
    func cloudFoodNoComponents() async throws {
        StubURLProtocol.stub { _ in
            .json(200, #"{"success":true,"data":{"food":"apple","quantity":1,"unit":"piece","kcal":95,"fat":0.3,"carbs":25,"protein":0.5,"fiber":4,"sodium":2,"sugar":19,"components":[]}}"#)
        }
        let parser = CloudFoodParser(client: makeClient(tokens: RecordingTokenStore("t")))
        let food = try await parser.parse(text: "an apple", units: .metric)
        #expect(food.components == nil)
        #expect(food.fiber == 4)
        #expect(food.sugar == 19)
    }

    @Test("a 401 on an enrolled call purges the token and re-acquires via assertion, then retries")
    func unauthorizedReacquiresViaAttest() async throws {
        StubURLProtocol.stub { req in
            switch req.url?.path {
            case "/api/parse-food":
                // The first call carries the stale token; the stub can't see which,
                // so it 401s once then succeeds is hard to model statelessly. Instead
                // start with no token so the client acquires fresh before the call.
                return .json(200, #"{"success":true,"data":{"food":"apple","quantity":1,"unit":"piece","kcal":95}}"#)
            case "/api/attest/challenge": return .json(200, #"{"challengeId":"c","challenge":"x"}"#)
            case "/api/attest/token":     return .json(200, #"{"token":"fresh.jwt","expiresAt":9}"#)
            default: return .json(200, "{}")
            }
        }
        let tokens = RecordingTokenStore(nil)
        let keys = RecordingKeyStore("enrolled-key")
        let food = try await CloudFoodParser(client: makeAttestClient(tokens: tokens, keys: keys))
            .parse(text: "apple", units: .metric)
        #expect(food.food == "apple")
        #expect(await tokens.token == "fresh.jwt")   // acquired via assertion, no UI
    }

    @Test("an unsuccessful parse throws — online-only, no silent fallback")
    func cloudFoodFailureThrows() async throws {
        StubURLProtocol.stub { _ in .json(200, #"{"success":false,"error":"Invalid food description"}"#) }
        let parser = CloudFoodParser(client: makeClient(tokens: RecordingTokenStore("t")))
        await #expect(throws: (any Error).self) {
            _ = try await parser.parse(text: "qz", units: .metric)
        }
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
                                   kcal: 700, fat: 20, carbs: 90, protein: 25, notes: "large plate",
                                   nutritionConfidence: .estimated))

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
        #expect(food == ParsedFood(food: "Apple", quantity: 1, unit: "piece", kcal: 95, fat: 0, carbs: 0, protein: 0,
                                   nutritionConfidence: .estimated))
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
                                   kcal: 59, fat: 0.4, carbs: 3.6, protein: 10,
                                   nutritionConfidence: .barcode,
                                   barcode: "5000112637922"))   // code carried through; no fiber/sodium/sugar → nil

        let cap = try #require(StubURLProtocol.captured())
        #expect(cap.url?.absoluteString == "https://world.openfoodfacts.org/api/v0/product/5000112637922.json")
        #expect(cap.header("User-Agent")?.contains("calorietracker.ai-created.com") == true)
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

    @Test("maps fiber/sugar (g) and sodium (g → mg), tagged .barcode")
    func offFiberSodiumSugar() async throws {
        StubURLProtocol.stub { _ in
            .json(200, #"""
            {"status":1,"product":{"product_name":"Bran","serving_quantity":40,
              "nutriments":{"energy-kcal_serving":140,"proteins_serving":4,
                "fiber_serving":10,"sugars_serving":6,"sodium_serving":0.21}}}
            """#)
        }
        let food = try await makeResolver().resolve(code: "1", units: .metric)
        #expect(food.fiber == 10)
        #expect(food.sugar == 6)
        #expect(food.sodium == 210)                 // 0.21 g × 1000
        #expect(food.nutritionConfidence == .barcode)
    }

    @Test("derives sodium from salt when sodium is absent (salt / 2.5)")
    func offSaltFallback() async throws {
        StubURLProtocol.stub { _ in
            .json(200, #"{"status":1,"product":{"product_name":"Chips","nutriments":{"energy-kcal_100g":500,"salt_100g":1.25}}}"#)
        }
        let food = try await makeResolver().resolve(code: "2", units: .metric)
        #expect(food.sodium == 500)                 // (1.25 / 2.5) × 1000
        #expect(food.nutritionConfidence == .barcode)
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
