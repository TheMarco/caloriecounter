import { getAllUniqueFood, searchPreviousFood, addEntry } from '@/utils/idb';

describe('Previous Entries Functionality', () => {
  beforeEach(async () => {
    // Clear all data from fake IndexedDB
    const { default: FDBFactory } = await import('fake-indexeddb/lib/FDBFactory');
    const { default: FDBKeyRange } = await import('fake-indexeddb/lib/FDBKeyRange');

    global.indexedDB = new FDBFactory();
    global.IDBKeyRange = FDBKeyRange;

    // Clear idb-keyval store specifically
    try {
      const { clear } = await import('idb-keyval');
      await clear();
    } catch {
      // Ignore errors during cleanup
    }
  });

  describe('getAllUniqueFood', () => {
    it('should return unique food entries sorted by frequency, then recency', async () => {
      // Add some test entries
      await addEntry({
        food: 'Apple',
        qty: 1,
        unit: 'piece',
        kcal: 95,
        fat: 0.3,
        carbs: 25,
        protein: 0.5,
        method: 'text',
      });

      // Wait a bit to ensure different timestamps
      await new Promise(resolve => setTimeout(resolve, 10));

      await addEntry({
        food: 'Banana',
        qty: 1,
        unit: 'piece',
        kcal: 105,
        fat: 0.4,
        carbs: 27,
        protein: 1.3,
        method: 'text',
      });

      // Add duplicate apple (should increase frequency)
      await new Promise(resolve => setTimeout(resolve, 10));
      await addEntry({
        food: 'Apple',
        qty: 2,
        unit: 'piece',
        kcal: 190,
        fat: 0.6,
        carbs: 50,
        protein: 1.0,
        method: 'voice',
      });

      // Add another apple (frequency = 3)
      await new Promise(resolve => setTimeout(resolve, 10));
      await addEntry({
        food: 'Apple',
        qty: 1,
        unit: 'piece',
        kcal: 95,
        fat: 0.3,
        carbs: 25,
        protein: 0.5,
        method: 'text',
      });

      const uniqueFood = await getAllUniqueFood();

      expect(uniqueFood).toHaveLength(2);
      expect(uniqueFood[0].food).toBe('Apple'); // Most frequent first (3 entries)
      expect(uniqueFood[1].food).toBe('Banana'); // Less frequent (1 entry)
    });

    it('should handle case-insensitive duplicates', async () => {
      await addEntry({
        food: 'Apple',
        qty: 1,
        unit: 'piece',
        kcal: 95,
        fat: 0.3,
        carbs: 25,
        protein: 0.5,
        method: 'text',
      });

      await addEntry({
        food: 'APPLE',
        qty: 1,
        unit: 'piece',
        kcal: 95,
        fat: 0.3,
        carbs: 25,
        protein: 0.5,
        method: 'voice',
      });

      const uniqueFood = await getAllUniqueFood();

      expect(uniqueFood).toHaveLength(1);
      expect(uniqueFood[0].food).toBe('APPLE'); // Most recent version
    });
  });

  describe('searchPreviousFood', () => {
    beforeEach(async () => {
      // Add test data
      const testEntries = [
        { food: 'Apple', qty: 1, unit: 'piece', kcal: 95, fat: 0.3, carbs: 25, protein: 0.5, method: 'text' as const },
        { food: 'Banana', qty: 1, unit: 'piece', kcal: 105, fat: 0.4, carbs: 27, protein: 1.3, method: 'text' as const },
        { food: 'Chicken Breast', qty: 150, unit: 'g', kcal: 248, fat: 5.4, carbs: 0, protein: 46.2, method: 'barcode' as const },
        { food: 'Green Apple', qty: 1, unit: 'piece', kcal: 80, fat: 0.2, carbs: 22, protein: 0.4, method: 'voice' as const },
      ];

      for (const entry of testEntries) {
        await addEntry(entry);
        // Small delay to ensure different timestamps
        await new Promise(resolve => setTimeout(resolve, 5));
      }
    });

    it('should return empty array for short queries', async () => {
      const results = await searchPreviousFood('a');
      expect(results).toHaveLength(0);
    });

    it('should search food names case-insensitively', async () => {
      const results = await searchPreviousFood('apple');
      expect(results).toHaveLength(2);
      expect(results.map(r => r.food)).toContain('Apple');
      expect(results.map(r => r.food)).toContain('Green Apple');
    });

    it('should limit results to specified limit', async () => {
      const results = await searchPreviousFood('apple', 1);
      expect(results).toHaveLength(1);
    });

    it('should return results sorted by frequency first', async () => {
      // Add more Apple entries to increase its frequency
      await addEntry({ food: 'Apple', qty: 1, unit: 'piece', kcal: 95, fat: 0.3, carbs: 25, protein: 0.5, method: 'text' as const });
      await addEntry({ food: 'Apple', qty: 1, unit: 'piece', kcal: 95, fat: 0.3, carbs: 25, protein: 0.5, method: 'text' as const });

      const results = await searchPreviousFood('apple');
      expect(results[0].food).toBe('Apple'); // Most frequent (3 total entries)
      expect(results[1].food).toBe('Green Apple'); // Less frequent (1 entry)
    });

    it('should handle partial matches', async () => {
      const results = await searchPreviousFood('chick');
      expect(results).toHaveLength(1);
      expect(results[0].food).toBe('Chicken Breast');
    });
  });
});
