#!/usr/bin/env python3
"""Generate an importable demo CSV (Settings → Import) that fills the app with ~2
months of realistic data for screenshots — foods, exercise offsets, and weekly
weigh-ins. Mirrors AppContainer.seedDemoData, but anchored to TODAY so the Today
screen is populated when you import it the same day. Re-run to refresh the dates.

    python3 apple/scripts/make-demo-data.py
    # writes apple/scripts/calorie-counter-demo.csv

Format matches CSVExporter exactly (date,time,food,…,method), incl. weight rows.
"""

import datetime
import os

HERE = os.path.dirname(os.path.abspath(__file__))
DST = os.path.join(HERE, "calorie-counter-demo.csv")

HEADER = "date,time,food,quantity,unit,calories,fat,carbs,protein,fiber,sodium,sugar,method"

# (food, qty, unit, kcal, fat, carbs, protein, fiber|None, sodium|None, sugar|None, method)
BREAKFASTS = [
    ("Greek Yogurt & Berries", 1, "bowl", 220, 5, 28, 18, 3, 80, 18, "label"),
    ("Oatmeal with Banana", 1, "bowl", 310, 6, 54, 10, 6, 120, 14, "text"),
    ("Scrambled Eggs & Toast", 1, "plate", 340, 18, 24, 20, 2, 520, 4, "text"),
    ("Avocado Toast", 1, "piece", 290, 17, 28, 8, 7, 380, 3, "label"),
    ("Protein Smoothie", 1, "cup", 250, 4, 30, 25, 4, 150, 22, "voice"),
]
LUNCHES = [
    ("Grilled Chicken Salad", 1, "bowl", 420, 18, 22, 40, 5, 480, 6, "text"),
    ("Turkey Sandwich", 1, "piece", 380, 12, 42, 28, 4, 920, 6, "barcode"),
    ("Chicken Burrito Bowl", 1, "bowl", 620, 20, 68, 38, 12, 1100, 8, "voice"),
    ("Tuna Wrap", 1, "piece", 400, 14, 40, 30, 4, 850, 4, "label"),
    ("Quinoa & Veggie Bowl", 1, "bowl", 480, 16, 62, 18, 10, 420, 7, "text"),
]
DINNERS = [
    ("Salmon, Rice & Greens", 1, "plate", 560, 22, 50, 38, 6, 380, 4, "text"),
    ("Spaghetti Bolognese", 1, "plate", 650, 22, 78, 32, 7, 980, 12, "voice"),
    ("Grilled Steak & Potatoes", 1, "plate", 700, 30, 45, 50, 5, 650, 3, "text"),
    ("Chicken Stir-fry", 1, "plate", 520, 18, 48, 38, 6, 1200, 10, "text"),
    ("Takeout Pad Thai", 1, "plate", 720, 26, 92, 26, 4, 1900, 18, "voice"),
]
SNACKS = [
    ("Almonds", 30, "g", 174, 15, 6, 6, 4, 0, 1, "label"),
    ("Apple", 1, "piece", 95, 0, 25, 0, 4, 2, 19, "barcode"),
    ("Protein Bar", 1, "piece", 200, 7, 22, 20, 6, 200, 14, "barcode"),
    ("Greek Yogurt", 1, "cup", 120, 0, 8, 18, None, 60, 6, "voice"),
]


def num(v):
    """Whole numbers without a decimal (matches CSVExporter.number)."""
    return str(int(v)) if float(v) == int(v) else str(v)


def one_decimal(v):
    return f"{v:.1f}"


def opt_number(v):
    return "" if v is None else num(v)


def opt_one_decimal(v):
    return "" if v is None else one_decimal(v)


def escape(field):
    s = str(field)
    if any(c in s for c in (",", '"', "\n")):
        return '"' + s.replace('"', '""') + '"'
    return s


def meal_row(date, hh, mm, meal):
    food, qty, unit, kcal, fat, carbs, protein, fiber, sodium, sugar, method = meal
    return ",".join([
        date, f"{hh:02d}:{mm:02d}", escape(food), num(qty), escape(unit),
        num(kcal), one_decimal(fat), one_decimal(carbs), one_decimal(protein),
        opt_one_decimal(fiber), opt_number(sodium), opt_one_decimal(sugar), method,
    ])


def main():
    today = datetime.date.today()
    lines = [HEADER]

    for offset in range(0, 61):
        day = today - datetime.timedelta(days=offset)
        date = day.isoformat()
        seq = 0

        def at(hour):
            nonlocal seq
            minute = (seq * 11) % 60
            seq += 1
            return hour, minute

        h, m = at(8);  lines.append(meal_row(date, h, m, BREAKFASTS[offset % len(BREAKFASTS)]))
        h, m = at(13); lines.append(meal_row(date, h, m, LUNCHES[(offset + 1) % len(LUNCHES)]))
        h, m = at(19); lines.append(meal_row(date, h, m, DINNERS[(offset + 2) % len(DINNERS)]))
        if offset % 2 == 0:
            h, m = at(16); lines.append(meal_row(date, h, m, SNACKS[offset % len(SNACKS)]))

        if offset % 3 == 0:
            value = 260 + (offset % 4) * 70
            lines.append(",".join([date, "", "Exercise & Adjustment", "", "", num(value), "", "", "", "", "", "", "offset"]))

        if offset % 7 == 0:
            kg = 81.5 + offset * 0.04 + ((offset // 7) % 3) * 0.2 - 0.2
            lines.append(",".join([date, "07:30", "Weight", one_decimal(kg), "kg", "", "", "", "", "", "", "", "weight"]))

    with open(DST, "w") as f:
        f.write("\n".join(lines) + "\n")
    print(f"wrote {len(lines) - 1} rows -> {DST}")
    print(f"  date range: {(today - datetime.timedelta(days=60)).isoformat()} … {today.isoformat()}")


if __name__ == "__main__":
    main()
