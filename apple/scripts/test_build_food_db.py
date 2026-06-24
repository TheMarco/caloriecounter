#!/usr/bin/env python3
"""Asserts for build_food_db's pure extractors, run on tiny hand-built dumps so the
pipeline's behavior is pinned without the 270 MB raw files.

    python3 apple/scripts/test_build_food_db.py   # prints OK or raises
"""

import build_food_db as b


def test_dish_with_recipe_and_portion():
    food = {
        "description": "Bacon, lettuce, tomato sandwich on white",
        "foodNutrients": [
            {"nutrient": {"id": 1008}, "amount": 231},
            {"nutrient": {"id": 1003}, "amount": 9.4},
            {"nutrient": {"id": 1004}, "amount": 11.6},
            {"nutrient": {"id": 1005}, "amount": 23.1},
            {"nutrient": {"id": 1079}, "amount": 1.6},
            {"nutrient": {"id": 1093}, "amount": 466},   # sodium already mg
            {"nutrient": {"id": 2000}, "amount": 3.0},
        ],
        "foodPortions": [
            {"portionDescription": "Quantity not specified", "gramWeight": 0},
            {"portionDescription": "1 sandwich, any size", "gramWeight": 105},
        ],
        "inputFoods": [
            {"ingredientDescription": "Pork bacon, cooked", "ingredientWeight": 16},
            {"ingredientDescription": "Bread, white", "ingredientWeight": 60},
        ],
    }
    rec = b.slim(food, source="fndds")
    assert rec["n"] == "Bacon, lettuce, tomato sandwich on white"
    assert rec["t"] == "dish"
    assert rec["k"] == 231 and rec["p"] == 9.4
    assert rec["so"] == 466                       # mg, unchanged
    assert rec["ps"] == [["1 sandwich, any size", 105]]   # generic portion dropped
    assert rec["r"] == [["Pork bacon, cooked", 16], ["Bread, white", 60]]


def test_sr_ingredient_sodium_mg_and_modifier_portion():
    food = {
        "description": "Anchovies, canned",
        "foodNutrients": [
            {"nutrient": {"id": 1008}, "amount": 210},
            {"nutrient": {"id": 1003}, "amount": 28.9},
            {"nutrient": {"id": 1093}, "amount": 5400},   # mg, no conversion
        ],
        "foodPortions": [
            {"amount": 1, "modifier": "serving", "measureUnit": {"name": "undetermined"}, "gramWeight": 34},
        ],
    }
    rec = b.slim(food, source="sr")
    assert rec["t"] == "food"
    assert rec["so"] == 5400
    assert rec["ps"] == [["1 serving", 34]]
    assert "r" not in rec                          # no recipe for SR ingredients


def test_drops_food_without_energy_or_protein():
    no_energy = {"description": "Mystery", "foodNutrients": [{"nutrient": {"id": 1003}, "amount": 5}]}
    no_protein = {"description": "Mystery", "foodNutrients": [{"nutrient": {"id": 1008}, "amount": 100}]}
    assert b.slim(no_energy, source="sr") is None
    assert b.slim(no_protein, source="sr") is None


def test_energy_fallback_chain_for_foundation():
    food = {
        "description": "Generic thing",
        "foodNutrients": [
            {"nutrient": {"id": 2048}, "amount": 88},   # Atwater specific, no 1008
            {"nutrient": {"id": 1003}, "amount": 2},
        ],
    }
    rec = b.slim(food, source="foundation")
    assert rec["k"] == 88


def run():
    for name, fn in sorted(globals().items()):
        if name.startswith("test_") and callable(fn):
            fn()
            print(f"  ✓ {name}")
    print("OK")


if __name__ == "__main__":
    run()
