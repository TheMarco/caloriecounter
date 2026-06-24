# Attribution

## Data Sources

This app uses nutrition data sourced in part from USDA FoodData Central.

FoodData Central data is public domain / CC0. USDA does not endorse this app.

Citation:
U.S. Department of Agriculture, Agricultural Research Service, Beltsville Human Nutrition Research Center. FoodData Central. Available from https://fdc.nal.usda.gov/.

The native iOS app bundles a slimmed, preprocessed subset of FoodData Central
(FNDDS, SR Legacy, and Foundation Foods) for fully on-device generic-food lookup.
See `apple/scripts/build_food_db.py` for how the bundled `FoodDB.json` is generated.

Barcode and branded-product nutrition is retrieved from
[Open Food Facts](https://world.openfoodfacts.org/), whose data is published under
the Open Database License (ODbL).
