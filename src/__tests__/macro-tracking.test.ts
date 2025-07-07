import { getMacroTotalsForDate, addEntry, clearAllData } from '@/utils/idb';

// Mock IndexedDB
import 'fake-indexeddb/auto';

describe('Macro Tracking', () => {
  beforeEach(async () => {
    // Clear all data before each test
    await clearAllData();
  });

  afterEach(async () => {
    // Clean up after each test
    await clearAllData();
  });

  it('should calculate macro totals correctly for a single entry', async () => {
    const testEntry = {
      food: 'Test Food',
      qty: 100,
      unit: 'g',
      kcal: 200,
      fat: 10,
      carbs: 20,
      protein: 15,
      method: 'text' as const,
    };

    await addEntry(testEntry);

    const today = new Date().toISOString().slice(0, 10);
    const totals = await getMacroTotalsForDate(today);

    expect(totals.calories).toBe(200);
    expect(totals.fat).toBe(10);
    expect(totals.carbs).toBe(20);
    expect(totals.protein).toBe(15);
  });

  it('should calculate macro totals correctly for multiple entries', async () => {
    const entry1 = {
      food: 'Food 1',
      qty: 100,
      unit: 'g',
      kcal: 200,
      fat: 10,
      carbs: 20,
      protein: 15,
      method: 'text' as const,
    };

    const entry2 = {
      food: 'Food 2',
      qty: 50,
      unit: 'g',
      kcal: 150,
      fat: 8,
      carbs: 15,
      protein: 12,
      method: 'text' as const,
    };

    await addEntry(entry1);
    await addEntry(entry2);

    const today = new Date().toISOString().slice(0, 10);
    const totals = await getMacroTotalsForDate(today);

    expect(totals.calories).toBe(350);
    expect(totals.fat).toBe(18);
    expect(totals.carbs).toBe(35);
    expect(totals.protein).toBe(27);
  });

  it('should handle entries with missing macro data', async () => {
    const entryWithMissingMacros = {
      food: 'Old Entry',
      qty: 100,
      unit: 'g',
      kcal: 200,
      method: 'text' as const,
    };

    // Add entry without macro data (simulating old entries)
    await addEntry(entryWithMissingMacros as Parameters<typeof addEntry>[0]);

    const today = new Date().toISOString().slice(0, 10);
    const totals = await getMacroTotalsForDate(today);

    expect(totals.calories).toBe(200);
    expect(totals.fat).toBe(0); // Should default to 0
    expect(totals.carbs).toBe(0); // Should default to 0
    expect(totals.protein).toBe(0); // Should default to 0
  });

  it('should return zero totals for dates with no entries', async () => {
    const yesterday = new Date();
    yesterday.setDate(yesterday.getDate() - 1);
    const yesterdayStr = yesterday.toISOString().slice(0, 10);

    const totals = await getMacroTotalsForDate(yesterdayStr);

    expect(totals.calories).toBe(0);
    expect(totals.fat).toBe(0);
    expect(totals.carbs).toBe(0);
    expect(totals.protein).toBe(0);
  });
});
