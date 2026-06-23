// BarcodeResolving via the public OpenFoodFacts API (no auth, no proxy).
//
// Prefers PER-SERVING data — which is what most US packaging shows (e.g. Dave's
// Killer Bread lists nutrition "per slice") — so a scan defaults to "1 serving"
// with the package's own numbers and the serving size in the notes. Falls back to
// per-100g when OFF has no serving data, then to `.missingNutriments` (which lets
// AppCore ask Foundation Models to estimate from the product name).

import Foundation
import NutritionCore

public enum OpenFoodFactsError: Error, Sendable, Equatable {
    /// OFF has no record for this barcode (`status != 1`).
    case productNotFound
    /// The product exists but lacks any usable nutrition. Carries the resolved
    /// product name so a caller (AppCore's composite) can ask FM to estimate.
    case missingNutriments(productName: String)
}

public struct OpenFoodFactsResolver: BarcodeResolving {
    private let session: URLSession
    private let baseURL: URL
    /// OFF asks API clients to identify themselves; use the app's real host.
    private static let userAgent = "CalorieCounter-iOS/1.0 (https://caloriecounter.ai-created.com)"

    public init(session: URLSession = .shared,
                baseURL: URL = URL(string: "https://world.openfoodfacts.org")!) {
        self.session = session
        self.baseURL = baseURL
    }

    public func resolve(code: String, units: UnitSystem) async throws -> ParsedFood {
        guard let url = URL(string: "\(baseURL.absoluteString)/api/v0/product/\(code).json") else {
            throw OpenFoodFactsError.productNotFound
        }
        var request = URLRequest(url: url)
        request.setValue(Self.userAgent, forHTTPHeaderField: "User-Agent")

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw OpenFoodFactsError.productNotFound
        }

        let payload = try JSONDecoder().decode(OFFResponse.self, from: data)
        guard payload.status == 1, let product = payload.product else {
            throw OpenFoodFactsError.productNotFound
        }

        let name = [product.productName, product.productNameEn, product.brands]
            .compactMap { $0 }
            .first(where: { !$0.trimmingCharacters(in: .whitespaces).isEmpty }) ?? "Unknown Product"

        guard let nutriments = product.nutriments else {
            throw OpenFoodFactsError.missingNutriments(productName: name)
        }
        let servingGrams = product.servingQuantity

        // 1) Per-serving — the package's own figures (explicit, or computed from
        //    per-100g × the serving weight). This is what users expect from a scan.
        if let kcal = perServing(nutriments.energyKcalServing, nutriments.energyKcal100g, servingGrams) {
            return ParsedFood(
                food: name, quantity: 1, unit: "serving",
                kcal: kcal,
                fat: perServing(nutriments.fatServing, nutriments.fat100g, servingGrams) ?? 0,
                carbs: perServing(nutriments.carbsServing, nutriments.carbs100g, servingGrams) ?? 0,
                protein: perServing(nutriments.proteinServing, nutriments.protein100g, servingGrams) ?? 0,
                notes: servingNote(size: product.servingSize, grams: servingGrams)
            )
        }

        // 2) Per-100g fallback.
        if let kcal = nutriments.energyKcal100g {
            return ParsedFood(
                food: name, quantity: 100, unit: "g",
                kcal: kcal,
                fat: nutriments.fat100g ?? 0,
                carbs: nutriments.carbs100g ?? 0,
                protein: nutriments.protein100g ?? 0
            )
        }

        throw OpenFoodFactsError.missingNutriments(productName: name)
    }

    /// A per-serving value: the explicit one if present, else per-100g scaled by
    /// the serving weight, else nil.
    private func perServing(_ explicit: Double?, _ per100g: Double?, _ servingGrams: Double?) -> Double? {
        if let explicit { return explicit }
        if let per100g, let servingGrams, servingGrams > 0 { return per100g * servingGrams / 100 }
        return nil
    }

    private func servingNote(size: String?, grams: Double?) -> String? {
        if let size, !size.trimmingCharacters(in: .whitespaces).isEmpty {
            return "Per serving: \(size)"
        }
        if let grams { return "Per serving: \(Int(grams)) g" }
        return nil
    }
}

// MARK: - OFF response decoding

private struct OFFResponse: Decodable {
    let status: Int?
    let product: Product?

    struct Product: Decodable {
        let productName: String?
        let productNameEn: String?
        let brands: String?
        let servingSize: String?
        let servingQuantity: Double?   // grams per serving (OFF may send string/number)
        let nutriments: Nutriments?

        enum CodingKeys: String, CodingKey {
            case productName = "product_name"
            case productNameEn = "product_name_en"
            case brands
            case servingSize = "serving_size"
            case servingQuantity = "serving_quantity"
            case nutriments
        }

        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            productName = try? c.decodeIfPresent(String.self, forKey: .productName)
            productNameEn = try? c.decodeIfPresent(String.self, forKey: .productNameEn)
            brands = try? c.decodeIfPresent(String.self, forKey: .brands)
            servingSize = try? c.decodeIfPresent(String.self, forKey: .servingSize)
            nutriments = try? c.decodeIfPresent(Nutriments.self, forKey: .nutriments)
            // serving_quantity is sometimes a number, sometimes a string.
            if let d = try? c.decode(Double.self, forKey: .servingQuantity) {
                servingQuantity = d
            } else if let s = try? c.decode(String.self, forKey: .servingQuantity) {
                servingQuantity = Double(s)
            } else {
                servingQuantity = nil
            }
        }
    }
}

/// OFF returns nutriment values as either numbers or strings; decode leniently,
/// for both the per-100g and per-serving variants.
private struct Nutriments: Decodable {
    let energyKcal100g: Double?
    let fat100g: Double?
    let carbs100g: Double?
    let protein100g: Double?
    let energyKcalServing: Double?
    let fatServing: Double?
    let carbsServing: Double?
    let proteinServing: Double?

    enum CodingKeys: String, CodingKey {
        case energyKcal100g = "energy-kcal_100g"
        case fat100g = "fat_100g"
        case carbs100g = "carbohydrates_100g"
        case protein100g = "proteins_100g"
        case energyKcalServing = "energy-kcal_serving"
        case fatServing = "fat_serving"
        case carbsServing = "carbohydrates_serving"
        case proteinServing = "proteins_serving"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        energyKcal100g = Nutriments.lenientDouble(c, .energyKcal100g)
        fat100g = Nutriments.lenientDouble(c, .fat100g)
        carbs100g = Nutriments.lenientDouble(c, .carbs100g)
        protein100g = Nutriments.lenientDouble(c, .protein100g)
        energyKcalServing = Nutriments.lenientDouble(c, .energyKcalServing)
        fatServing = Nutriments.lenientDouble(c, .fatServing)
        carbsServing = Nutriments.lenientDouble(c, .carbsServing)
        proteinServing = Nutriments.lenientDouble(c, .proteinServing)
    }

    private static func lenientDouble(_ c: KeyedDecodingContainer<CodingKeys>, _ key: CodingKeys) -> Double? {
        if let d = try? c.decode(Double.self, forKey: key) { return d }
        if let s = try? c.decode(String.self, forKey: key) { return Double(s) }
        return nil
    }
}
