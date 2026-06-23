// Convert food amounts between compatible units. Mass units (g/oz/lb) and volume
// units (ml/cup/tbsp/tsp) convert within their family; the abstract serving units
// (piece/slice/bowl/plate/serving) have no physical conversion, so switching to or
// from them is a relabel, not a rescale. Pure and unit-tested.

import Foundation

public enum UnitConversion {
    public static let massUnits = ["g", "oz", "lb"]
    public static let volumeUnits = ["ml", "cup", "tbsp", "tsp"]
    /// Abstract portions with no physical conversion (relabels of one another).
    public static let abstractUnits = ["piece", "slice", "bowl", "plate", "serving"]

    /// Mass units expressed in grams.
    private static let massToGrams: [String: Double] = [
        "g": 1, "oz": 28.349523125, "lb": 453.59237,
    ]
    /// Volume units expressed in millilitres.
    private static let volumeToMl: [String: Double] = [
        "ml": 1, "cup": 240, "tbsp": 15, "tsp": 5,
    ]

    /// The units worth offering for a food currently measured in `unit`: its own
    /// physical family (mass, volume, or the abstract portions). Switching within a
    /// mass/volume family recomputes nutrition; abstract units are relabels.
    public static func compatibleUnits(with unit: String) -> [String] {
        if massUnits.contains(unit) { return massUnits }
        if volumeUnits.contains(unit) { return volumeUnits }
        if abstractUnits.contains(unit) { return abstractUnits }
        return [unit]
    }

    /// `amount` re-expressed from `from` into `to` when they share a family
    /// (mass↔mass or volume↔volume). Identical units pass through unchanged.
    /// Returns nil when the units aren't inter-convertible (e.g. `slice`↔`g`).
    public static func convert(_ amount: Double, from: String, to: String) -> Double? {
        if from == to { return amount }
        if let a = massToGrams[from], let b = massToGrams[to] { return amount * a / b }
        if let a = volumeToMl[from], let b = volumeToMl[to] { return amount * a / b }
        return nil
    }

    /// Whether two units can be converted between (same physical family).
    public static func areCompatible(_ a: String, _ b: String) -> Bool {
        convert(1, from: a, to: b) != nil
    }
}
