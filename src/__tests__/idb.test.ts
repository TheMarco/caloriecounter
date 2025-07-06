import { 
  addEntry, 
  getEntry, 
  deleteEntry, 
  getTodayEntries, 
  getTodayTotal,
  todayKey 
} from '@/utils/idb';

describe('IndexedDB utilities', () => {
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

  describe('addEntry', () => {
    it('should add an entry and return it with id, ts, and dt', async () => {
      const entryData = {
        food: 'apple',
        qty: 150,
        unit: 'g',
        kcal: 78,
        method: 'text' as const,
      };

      const entry = await addEntry(entryData);

      expect(entry).toMatchObject(entryData);
      expect(entry.id).toBeDefined();
      expect(entry.ts).toBeDefined();
      expect(entry.dt).toBe(todayKey());
    });
  });

  describe('getEntry', () => {
    it('should retrieve an entry by id', async () => {
      const entryData = {
        food: 'banana',
        qty: 120,
        unit: 'g',
        kcal: 89,
        method: 'voice' as const,
      };

      const addedEntry = await addEntry(entryData);
      const retrievedEntry = await getEntry(addedEntry.id);

      expect(retrievedEntry).toEqual(addedEntry);
    });

    it('should return undefined for non-existent entry', async () => {
      const retrievedEntry = await getEntry('non-existent-id');
      expect(retrievedEntry).toBeUndefined();
    });
  });

  describe('deleteEntry', () => {
    it('should delete an entry and return true', async () => {
      const entryData = {
        food: 'orange',
        qty: 130,
        unit: 'g',
        kcal: 47,
        method: 'barcode' as const,
      };

      const addedEntry = await addEntry(entryData);
      const deleted = await deleteEntry(addedEntry.id);

      expect(deleted).toBe(true);

      const retrievedEntry = await getEntry(addedEntry.id);
      expect(retrievedEntry).toBeUndefined();
    });
  });

  describe('getTodayEntries', () => {
    it('should return all entries for today', async () => {
      const entries = [
        { food: 'apple', qty: 150, unit: 'g', kcal: 78, method: 'text' as const },
        { food: 'banana', qty: 120, unit: 'g', kcal: 89, method: 'voice' as const },
      ];

      await Promise.all(entries.map(addEntry));
      const todayEntries = await getTodayEntries();

      expect(todayEntries).toHaveLength(2);
      expect(todayEntries.map(e => e.food)).toContain('apple');
      expect(todayEntries.map(e => e.food)).toContain('banana');
    });

    it('should return entries sorted by timestamp (most recent first)', async () => {
      await addEntry({
        food: 'first',
        qty: 100,
        unit: 'g',
        kcal: 100,
        method: 'text' as const,
      });

      // Wait a bit to ensure different timestamps
      await new Promise(resolve => setTimeout(resolve, 10));

      await addEntry({
        food: 'second',
        qty: 100,
        unit: 'g',
        kcal: 100,
        method: 'text' as const,
      });

      const todayEntries = await getTodayEntries();

      expect(todayEntries[0].food).toBe('second');
      expect(todayEntries[1].food).toBe('first');
    });
  });

  describe('getTodayTotal', () => {
    it('should return the sum of calories for today', async () => {
      const entries = [
        { food: 'apple', qty: 150, unit: 'g', kcal: 78, method: 'text' as const },
        { food: 'banana', qty: 120, unit: 'g', kcal: 89, method: 'voice' as const },
        { food: 'orange', qty: 130, unit: 'g', kcal: 47, method: 'barcode' as const },
      ];

      await Promise.all(entries.map(addEntry));
      const total = await getTodayTotal();

      expect(total).toBe(78 + 89 + 47);
    });

    it('should return 0 when no entries exist', async () => {
      const total = await getTodayTotal();
      expect(total).toBe(0);
    });
  });

  describe('todayKey', () => {
    it('should return today\'s date in YYYY-MM-DD format', () => {
      const today = new Date();
      const expected = today.toISOString().slice(0, 10);
      const result = todayKey();

      expect(result).toBe(expected);
    });
  });
});
