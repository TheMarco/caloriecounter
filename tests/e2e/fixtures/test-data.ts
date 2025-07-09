// Test data for Playwright tests

// Get today's date in YYYY-MM-DD format
const getTodayDate = () => {
  const today = new Date();
  return today.toISOString().slice(0, 10);
};

export const mockFoodEntries = [
  {
    id: 'test-entry-1',
    dt: getTodayDate(),
    ts: Date.now(),
    food: 'Apple',
    qty: 1,
    unit: 'piece',
    kcal: 95,
    fat: 0.3,
    carbs: 25,
    protein: 0.5,
    method: 'text' as const,
    confidence: 0.9
  },
  {
    id: 'test-entry-2',
    dt: getTodayDate(),
    ts: Date.now() - 3600000, // 1 hour ago
    food: 'Chicken Breast',
    qty: 150,
    unit: 'g',
    kcal: 248,
    fat: 5.4,
    carbs: 0,
    protein: 46.2,
    method: 'barcode' as const,
    confidence: 1.0
  },
  {
    id: 'test-entry-3',
    dt: getTodayDate(),
    ts: Date.now() - 7200000, // 2 hours ago
    food: 'Brown Rice',
    qty: 100,
    unit: 'g',
    kcal: 111,
    fat: 0.9,
    carbs: 23,
    protein: 2.6,
    method: 'voice' as const,
    confidence: 0.8
  }
];

export const mockBarcodeResponse = {
  success: true,
  data: {
    food: 'Coca-Cola Classic',
    kcal: 140,
    fat: 0,
    carbs: 39,
    protein: 0,
    unit: 'ml',
    serving_size: 355
  }
};

export const mockParseFoodResponse = {
  success: true,
  data: {
    food: 'Grilled Chicken Breast',
    quantity: 150,
    unit: 'g',
    kcal: 248,
    fat: 5.4,
    carbs: 0,
    protein: 46.2,
    notes: 'High protein, low carb option'
  }
};

export const mockSettings = {
  dailyTarget: 2000,
  fatTarget: 65,
  carbsTarget: 250,
  proteinTarget: 100,
  units: 'metric' as const
};

export const testBarcodes = {
  cocaCola: '049000028911',
  pepsi: '012000001765',
  premierProtein: '888849000123',
  invalidShort: '123',
  invalidLong: '123456789012345'
};

export const testFoodDescriptions = [
  '1 apple',
  '150g chicken breast',
  '2 slices of bread',
  'premier protein shake vanilla',
  'chili dog with cheese',
  '1 cup of rice',
  '2 tbsp olive oil'
];

export const testVoiceTranscripts = [
  'I had an apple for breakfast',
  'Two slices of whole wheat bread',
  'Grilled chicken breast about 150 grams',
  'Premier protein shake vanilla flavor',
  'One cup of brown rice'
];

export const expectedMacroTotals = {
  calories: 454, // Sum of mock entries
  fat: 6.6,
  carbs: 48,
  protein: 49.3
};
