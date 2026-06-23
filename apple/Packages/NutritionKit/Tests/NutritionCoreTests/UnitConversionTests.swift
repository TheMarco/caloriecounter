// UnitConversion: mass and volume families convert; abstract units don't.

import Testing
@testable import NutritionCore

@Suite("UnitConversion")
struct UnitConversionTests {

    @Test("identical units pass through unchanged")
    func identity() {
        #expect(UnitConversion.convert(5, from: "g", to: "g") == 5)
        #expect(UnitConversion.convert(1, from: "serving", to: "serving") == 1)
    }

    @Test("mass units convert (g / oz / lb)")
    func mass() throws {
        #expect(abs(try #require(UnitConversion.convert(100, from: "g", to: "oz")) - 3.5274) < 0.001)
        #expect(abs(try #require(UnitConversion.convert(1, from: "oz", to: "g")) - 28.3495) < 0.001)
        #expect(UnitConversion.convert(1, from: "lb", to: "oz") == 16)
    }

    @Test("volume units convert (ml / cup / tbsp / tsp)")
    func volume() throws {
        #expect(UnitConversion.convert(240, from: "ml", to: "cup") == 1)
        #expect(UnitConversion.convert(1, from: "cup", to: "tbsp") == 16)
        #expect(UnitConversion.convert(1, from: "tbsp", to: "tsp") == 3)
        #expect(UnitConversion.convert(1, from: "tsp", to: "ml") == 5)
    }

    @Test("abstract and cross-family units do not convert")
    func incompatible() {
        #expect(UnitConversion.convert(1, from: "slice", to: "g") == nil)
        #expect(UnitConversion.convert(1, from: "serving", to: "slice") == nil)
        #expect(UnitConversion.convert(1, from: "g", to: "ml") == nil)     // mass vs volume
        #expect(UnitConversion.convert(1, from: "piece", to: "oz") == nil)
    }

    @Test("areCompatible reflects convertibility")
    func compatibility() {
        #expect(UnitConversion.areCompatible("g", "lb"))
        #expect(UnitConversion.areCompatible("cup", "tsp"))
        #expect(!UnitConversion.areCompatible("slice", "g"))
        #expect(!UnitConversion.areCompatible("g", "cup"))
    }
}
