// Locks the display labels and AI-prompt phrases carried by the domain enums.
// The `promptDescription` strings are forwarded verbatim to the cloud photo
// parser (web `sizeMap` / `typeMap`), so drift here is a real behavior change —
// these assertions are the guard.

import Testing
@testable import NutritionCore

@Suite("Enum metadata")
struct EnumMetadataTests {

    @Test("every InputMethod exposes label, detail, and an SF Symbol")
    func inputMethodMetadata() {
        for method in InputMethod.allCases {
            #expect(!method.label.isEmpty)
            #expect(!method.detail.isEmpty)
            #expect(!method.systemImage.isEmpty)
        }
        #expect(InputMethod.voice.label == "Voice")
        #expect(InputMethod.photo.detail == "Take a photo of food")
        #expect(InputMethod.barcode.systemImage == "barcode.viewfinder")
    }

    @Test("UnitSystem labels")
    func unitSystemLabels() {
        #expect(UnitSystem.metric.label == "Metric")
        #expect(UnitSystem.imperial.label == "Imperial")
    }

    @Test("every PlateSize has a non-empty label and inch-bearing prompt phrase")
    func plateSizeMetadata() {
        for size in PlateSize.allCases {
            #expect(!size.label.isEmpty)
            #expect(size.promptDescription.contains("inches"))
        }
        #expect(PlateSize.extraLarge.label == "Extra large plate/bowl")
        #expect(PlateSize.large.promptDescription == "large plate/bowl (about 11-12 inches)")
    }

    @Test("every ServingType has a non-empty label and prompt phrase")
    func servingTypeMetadata() {
        for type in ServingType.allCases {
            #expect(!type.label.isEmpty)
            #expect(!type.promptDescription.isEmpty)
        }
        #expect(ServingType.fastFood.label == "Fast food")
        #expect(ServingType.home.promptDescription == "home cooking (typically smaller, more controlled portions)")
    }

    @Test("MacroTotals + combines two totals componentwise")
    func macroTotalsPlusOperator() {
        let a = MacroTotals(calories: 200, fat: 5, carbs: 10, protein: 8)
        let b = MacroTotals(calories: 100, fat: 1, carbs: 20, protein: 2)
        #expect(a + b == MacroTotals(calories: 300, fat: 6, carbs: 30, protein: 10))
    }

    @Test("MacroTotals.adding accumulates a single entry onto a running total")
    func macroTotalsAddingSingle() {
        let running = MacroTotals(calories: 100, fat: 2, carbs: 5, protein: 3)
        let entry = Entry(
            id: "e", date: "2026-06-22", timestamp: .init(timeIntervalSince1970: 0),
            food: "Egg", quantity: 1, unit: "piece",
            kcal: 78, fat: 5, carbs: 0.6, protein: 6, method: .text
        )
        #expect(running.adding(entry) == MacroTotals(calories: 178, fat: 7, carbs: 5.6, protein: 9))
    }
}
