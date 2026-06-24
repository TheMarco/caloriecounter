#!/usr/bin/env python3
"""Preprocess the three raw USDA dumps into one slim, app-bundled food database
(`NutritionAI/Resources/FoodDB.json`).

Sources (all git-ignored, kept locally under apple/):
  - FNDDS.json        SurveyFoods    — composite/prepared DISHES (carry recipes)
  - legacyfoods.json  SRLegacyFoods  — raw + branded ingredients
  - USDA.json         FoundationFoods — generic whole foods

Each output row (compact keys to keep the bundle small):
  n  name
  t  "dish" (FNDDS) | "food" (SR Legacy / Foundation)
  k  kcal / 100 g          p/f/c  protein/fat/carbs g / 100 g
  fi fiber g / 100 g       so  sodium MG / 100 g       su  sugars g / 100 g   (optional)
  ps [[label, grams], ...] up to 3 real household portions
  r  [[ingredient, grams], ...] recipe (FNDDS dishes only)

USDA stores sodium (id 1093) in MILLIGRAMS in these dumps, so — unlike the
OpenFoodFacts path — NO unit conversion is applied here.

    python3 apple/scripts/build_food_db.py
"""

import json
import os

HERE = os.path.dirname(os.path.abspath(__file__))
APPLE = os.path.dirname(HERE)
DST = os.path.join(APPLE, "Packages/NutritionKit/Sources/NutritionAI/Resources/FoodDB.json")

SOURCES = [
    # (filename, top-level key, source tag) — order sets dedup preference.
    ("FNDDS.json", "SurveyFoods", "fndds"),
    ("USDA.json", "FoundationFoods", "foundation"),
    ("legacyfoods.json", "SRLegacyFoods", "sr"),
]

# Energy falls back measured → Atwater specific → Atwater general.
ENERGY = (1008, 2048, 2047)
PROTEIN, FAT, CARBS, FIBER, SODIUM = 1003, 1004, 1005, 1079, 1093
SUGAR = (2000, 1063)

GENERIC_PORTION = "quantity not specified"
MAX_PORTIONS = 3
MAX_RECIPE = 12


def _amount(food, *ids):
    by = {}
    for n in food.get("foodNutrients", []):
        nut = (n or {}).get("nutrient") or {}
        nid = nut.get("id")
        amt = n.get("amount")
        if amt is None:
            amt = n.get("median")
        if nid is not None and amt is not None and nid not in by:
            by[nid] = amt
    for i in ids:
        if i in by:
            return by[i]
    return None


def _round(value, places=1):
    return None if value is None else round(value, places)


def _num(x):
    """Trim 1.0 → 1 for compact portion labels."""
    return int(x) if float(x).is_integer() else x


def _portions(food, source):
    out = []
    for p in food.get("foodPortions", []):
        grams = p.get("gramWeight")
        if not grams or grams <= 0:
            continue
        if source == "fndds":
            label = (p.get("portionDescription") or "").strip()
        else:
            # SR Legacy / Foundation: amount + modifier ("1 serving", "0.5 cup").
            modifier = (p.get("modifier") or "").strip()
            amount = p.get("amount") or p.get("value")
            if modifier and modifier.lower() not in ("undetermined", ""):
                label = f"{_num(amount)} {modifier}" if amount else modifier
            else:
                label = ""
        if not label or label.lower() == GENERIC_PORTION:
            continue
        item = [label, round(grams, 1)]
        if item not in out:
            out.append(item)
        if len(out) >= MAX_PORTIONS:
            break
    return out


def _recipe(food):
    out = []
    for i in food.get("inputFoods", []):
        name = (i.get("ingredientDescription") or i.get("foodDescription") or "").strip()
        grams = i.get("ingredientWeight")
        if not name or not grams or grams <= 0:
            continue
        out.append([name, round(grams, 1)])
        if len(out) >= MAX_RECIPE:
            break
    return out


def slim(food, source):
    """Pure: raw USDA food dict → slim record, or None if unusable. Tested directly."""
    name = (food.get("description") or "").strip()
    kcal = _amount(food, *ENERGY)
    protein = _amount(food, PROTEIN)
    if not name or kcal is None or protein is None:
        return None

    rec = {
        "n": name,
        "t": "dish" if source == "fndds" else "food",
        "k": _round(kcal),
        "p": _round(protein),
        "f": _round(_amount(food, FAT) or 0),
        "c": _round(_amount(food, CARBS) or 0),
    }
    fiber = _amount(food, FIBER)
    sodium = _amount(food, SODIUM)   # already mg
    sugar = _amount(food, *SUGAR)
    if fiber is not None:
        rec["fi"] = _round(fiber)
    if sodium is not None:
        rec["so"] = _round(sodium, 0)
    if sugar is not None:
        rec["su"] = _round(sugar)

    portions = _portions(food, source)
    if portions:
        rec["ps"] = portions
    if source == "fndds":
        recipe = _recipe(food)
        if recipe:
            rec["r"] = recipe
    return rec


def main():
    out = []
    seen = set()                      # normalized name → first (highest-preference) wins
    counts = {}
    for filename, key, source in SOURCES:
        path = os.path.join(APPLE, filename)
        if not os.path.exists(path):
            print(f"  ! missing {filename} — skipping")
            continue
        foods = [f for f in json.load(open(path)).get(key, []) if isinstance(f, dict)]
        kept = 0
        for food in foods:
            rec = slim(food, source)
            if rec is None:
                continue
            norm = rec["n"].lower().strip()
            if norm in seen:
                continue
            seen.add(norm)
            out.append(rec)
            kept += 1
        counts[source] = kept

    out.sort(key=lambda x: x["n"].lower())
    os.makedirs(os.path.dirname(DST), exist_ok=True)
    with open(DST, "w") as f:
        json.dump(out, f, ensure_ascii=False, separators=(",", ":"))

    size = os.path.getsize(DST)
    print(f"wrote {len(out)} foods -> {DST}")
    print(f"  by source: {counts}")
    print(f"  size: {size/1_048_576:.2f} MB ({size} bytes)")
    dishes = sum(1 for r in out if r["t"] == "dish")
    with_recipe = sum(1 for r in out if "r" in r)
    with_portion = sum(1 for r in out if "ps" in r)
    print(f"  dishes: {dishes}, with recipe: {with_recipe}, with portion: {with_portion}")


if __name__ == "__main__":
    main()
