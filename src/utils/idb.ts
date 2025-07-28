// IndexedDB wrapper using idb-keyval for local-first storage
import { get, set, del, keys, clear } from 'idb-keyval';
import { createId } from '@paralleldrive/cuid2';
import type { Entry, MacroTotals } from '@/types';

// Utility function to format date as YYYY-MM-DD in local timezone
const formatLocalDate = (date: Date): string => {
  const year = date.getFullYear();
  const month = String(date.getMonth() + 1).padStart(2, '0');
  const day = String(date.getDate()).padStart(2, '0');
  return `${year}-${month}-${day}`;
};

// Key generators
export const todayKey = (): string => formatLocalDate(new Date());

export const entryKey = (id: string): string => `entry:${id}`;

export const dateKey = (date: string): string => `date:${date}`;

export const offsetKey = (date: string): string => `offset:${date}`;

// Daily reset logic
export const checkDailyReset = (): void => {
  const today = todayKey();
  const lastDay = localStorage.getItem('lastDay');
  
  if (lastDay !== today) {
    localStorage.setItem('lastDay', today);
    // No data deletion - we filter by date instead
  }
};

// Entry management
export const addEntry = async (entryData: Omit<Entry, 'id' | 'ts' | 'dt'>, date?: string): Promise<Entry> => {
  const entry: Entry = {
    ...entryData,
    id: createId(),
    ts: Date.now(),
    dt: date || todayKey(),
  };

  await set(entryKey(entry.id), entry);
  return entry;
};

export const getEntry = async (id: string): Promise<Entry | undefined> => {
  return await get(entryKey(id));
};

export const updateEntry = async (id: string, updates: Partial<Entry>): Promise<Entry | null> => {
  const existing = await getEntry(id);
  if (!existing) return null;
  
  const updated = { ...existing, ...updates };
  await set(entryKey(id), updated);
  return updated;
};

export const deleteEntry = async (id: string): Promise<boolean> => {
  try {
    await del(entryKey(id));
    return true;
  } catch {
    return false;
  }
};

// Calorie offset management
export const getCalorieOffset = async (date: string): Promise<number> => {
  const offset = await get(offsetKey(date));
  return offset || 0; // Default to 0 if not set
};

export const getTodayCalorieOffset = async (): Promise<number> => {
  return await getCalorieOffset(todayKey());
};

export const setCalorieOffset = async (date: string, offset: number): Promise<void> => {
  await set(offsetKey(date), offset);
};

export const setTodayCalorieOffset = async (offset: number): Promise<void> => {
  await setCalorieOffset(todayKey(), offset);
};

// Query functions
export const getEntriesByDate = async (date: string): Promise<Entry[]> => {
  const allKeys = await keys();
  const entryKeys = allKeys.filter(key =>
    typeof key === 'string' && key.startsWith('entry:')
  );

  const entries: Entry[] = [];
  for (const key of entryKeys) {
    const entry = await get(key);
    if (entry && entry.dt === date) {
      entries.push(entry);
    }
  }

  return entries.sort((a, b) => b.ts - a.ts); // Most recent first
};

export const getTodayEntries = async (): Promise<Entry[]> => {
  return await getEntriesByDate(todayKey());
};

export const getEntriesInRange = async (startDate: string, endDate: string): Promise<Entry[]> => {
  const allKeys = await keys();
  const entryKeys = allKeys.filter(key => 
    typeof key === 'string' && key.startsWith('entry:')
  );
  
  const entries: Entry[] = [];
  for (const key of entryKeys) {
    const entry = await get(key);
    if (entry && entry.dt >= startDate && entry.dt <= endDate) {
      entries.push(entry);
    }
  }
  
  return entries.sort((a, b) => b.ts - a.ts);
};

// Statistics
export const getTotalCaloriesForDate = async (date: string): Promise<number> => {
  const entries = await getEntriesByDate(date);
  return entries.reduce((total, entry) => total + entry.kcal, 0);
};

export const getMacroTotalsForDate = async (date: string): Promise<MacroTotals> => {
  const entries = await getEntriesByDate(date);
  return entries.reduce((totals, entry) => ({
    calories: totals.calories + entry.kcal,
    fat: totals.fat + (entry.fat || 0),
    carbs: totals.carbs + (entry.carbs || 0),
    protein: totals.protein + (entry.protein || 0),
  }), {
    calories: 0,
    fat: 0,
    carbs: 0,
    protein: 0,
  });
};

export const getTodayTotal = async (): Promise<number> => {
  return await getTotalCaloriesForDate(todayKey());
};

export const getTodayMacroTotals = async (): Promise<MacroTotals> => {
  return await getMacroTotalsForDate(todayKey());
};

export const getDailyTotals = async (days: number): Promise<Array<{ date: string; total: number }>> => {
  const results: Array<{ date: string; total: number }> = [];
  const today = new Date();

  for (let i = 0; i < days; i++) {
    const date = new Date(today);
    date.setDate(date.getDate() - i);
    const dateStr = formatLocalDate(date);

    const total = await getTotalCaloriesForDate(dateStr);
    results.push({ date: dateStr, total });
  }

  return results.reverse(); // Oldest first for charts
};

export const getDailyMacroTotals = async (days: number): Promise<Array<{ date: string; totals: MacroTotals }>> => {
  const results: Array<{ date: string; totals: MacroTotals }> = [];
  const today = new Date();

  for (let i = 0; i < days; i++) {
    const date = new Date(today);
    date.setDate(date.getDate() - i);
    const dateStr = formatLocalDate(date);

    const totals = await getMacroTotalsForDate(dateStr);
    results.push({ date: dateStr, totals });
  }

  return results.reverse(); // Oldest first for charts
};

export const getDailyMacroTotalsWithOffset = async (days: number): Promise<Array<{ date: string; totals: MacroTotals; offset: number }>> => {
  const results: Array<{ date: string; totals: MacroTotals; offset: number }> = [];
  const today = new Date();

  for (let i = 0; i < days; i++) {
    const date = new Date(today);
    date.setDate(date.getDate() - i);
    const dateStr = formatLocalDate(date);

    const [totals, offset] = await Promise.all([
      getMacroTotalsForDate(dateStr),
      getCalorieOffset(dateStr)
    ]);

    results.push({ date: dateStr, totals, offset });
  }

  return results.reverse(); // Oldest first for charts
};

// Data migration for timezone fix
export const migrateTimezoneData = async (): Promise<void> => {
  try {
    const allKeys = await keys();
    const entryKeys = allKeys.filter(key =>
      typeof key === 'string' && key.startsWith('entry:')
    );

    let migratedCount = 0;

    for (const key of entryKeys) {
      const entry = await get(key);
      if (entry && entry.dt) {
        // Check if this entry has a UTC-based date that needs migration
        const entryDate = new Date(entry.dt + 'T00:00:00Z'); // Parse as UTC
        const localDate = formatLocalDate(entryDate);

        // If the local date is different from stored date, migrate it
        if (localDate !== entry.dt) {
          const updatedEntry = { ...entry, dt: localDate };
          await set(key, updatedEntry);
          migratedCount++;
        }
      }
    }

    if (migratedCount > 0) {
      console.log(`🔄 Migrated ${migratedCount} entries to local timezone`);
      // Update the migration flag
      localStorage.setItem('timezone-migrated', 'true');
    }
  } catch (error) {
    console.error('Error migrating timezone data:', error);
  }
};

// Check if migration is needed and run it
export const checkAndMigrateTimezone = async (): Promise<void> => {
  const migrated = localStorage.getItem('timezone-migrated');
  if (!migrated) {
    await migrateTimezoneData();
  }
};

// Utility functions
export const clearAllData = async (): Promise<void> => {
  await clear();
  localStorage.removeItem('lastDay');
  localStorage.removeItem('timezone-migrated');
};

export const exportData = async (): Promise<Entry[]> => {
  const allKeys = await keys();
  const entryKeys = allKeys.filter(key =>
    typeof key === 'string' && key.startsWith('entry:')
  );

  const entries: Entry[] = [];
  for (const key of entryKeys) {
    const entry = await get(key);
    if (entry) {
      entries.push(entry);
    }
  }

  return entries.sort((a, b) => a.ts - b.ts); // Chronological order
};

// Get all unique food entries for autocomplete, sorted by frequency
export const getAllUniqueFood = async (): Promise<Entry[]> => {
  const allKeys = await keys();
  const entryKeys = allKeys.filter(key =>
    typeof key === 'string' && key.startsWith('entry:')
  );

  // Track frequency and most recent entry for each food
  const foodMap = new Map<string, { entry: Entry; count: number; lastUsed: number }>();

  for (const key of entryKeys) {
    const entry = await get(key);
    if (entry) {
      // Use food name as the unique key (case-insensitive)
      const foodKey = entry.food.toLowerCase().trim();

      if (foodMap.has(foodKey)) {
        const existing = foodMap.get(foodKey)!;
        // Increment count and update to most recent entry if this one is newer
        foodMap.set(foodKey, {
          entry: entry.ts > existing.entry.ts ? entry : existing.entry,
          count: existing.count + 1,
          lastUsed: Math.max(existing.lastUsed, entry.ts)
        });
      } else {
        foodMap.set(foodKey, {
          entry,
          count: 1,
          lastUsed: entry.ts
        });
      }
    }
  }

  // Convert to array and sort by frequency (most frequent first), then by recency
  return Array.from(foodMap.values())
    .sort((a, b) => {
      // Primary sort: by frequency (descending)
      if (b.count !== a.count) {
        return b.count - a.count;
      }
      // Secondary sort: by most recent usage (descending)
      return b.lastUsed - a.lastUsed;
    })
    .map(item => item.entry);
};

// Search previous food entries by name, prioritizing frequently eaten foods
export const searchPreviousFood = async (query: string, limit: number = 15): Promise<Entry[]> => {
  if (!query || query.length < 2) return [];

  // Get all unique foods already sorted by frequency
  const uniqueFood = await getAllUniqueFood();
  const queryLower = query.toLowerCase().trim();

  // Filter matches - since uniqueFood is already sorted by frequency,
  // the most frequently eaten foods will appear first
  return uniqueFood
    .filter(entry => entry.food.toLowerCase().includes(queryLower))
    .slice(0, limit);
};

// Add sample data for testing previous entries feature (localhost only)
export const addSampleData = async (): Promise<void> => {
  // Only allow on localhost for development/testing
  if (typeof window !== 'undefined' &&
      !window.location.hostname.includes('localhost') &&
      !window.location.hostname.includes('127.0.0.1')) {
    console.warn('🚫 Sample data can only be added on localhost');
    throw new Error('Sample data is only available in development mode');
  }
  const sampleEntries = [
    {
      food: 'Grilled Chicken Breast',
      qty: 150,
      unit: 'g',
      kcal: 248,
      fat: 5.4,
      carbs: 0,
      protein: 46.2,
      method: 'text' as const,
    },
    {
      food: 'Brown Rice',
      qty: 100,
      unit: 'g',
      kcal: 111,
      fat: 0.9,
      carbs: 23,
      protein: 2.6,
      method: 'voice' as const,
    },
    {
      food: 'Green Apple',
      qty: 1,
      unit: 'piece',
      kcal: 95,
      fat: 0.3,
      carbs: 25,
      protein: 0.5,
      method: 'text' as const,
    },
    {
      food: 'Banana',
      qty: 1,
      unit: 'piece',
      kcal: 105,
      fat: 0.4,
      carbs: 27,
      protein: 1.3,
      method: 'barcode' as const,
    },
    {
      food: 'Salmon Fillet',
      qty: 120,
      unit: 'g',
      kcal: 208,
      fat: 12.4,
      carbs: 0,
      protein: 22.1,
      method: 'text' as const,
    },
    {
      food: 'Greek Yogurt',
      qty: 150,
      unit: 'g',
      kcal: 100,
      fat: 0.4,
      carbs: 6,
      protein: 17,
      method: 'voice' as const,
    },
    {
      food: 'Whole Wheat Bread',
      qty: 2,
      unit: 'slice',
      kcal: 160,
      fat: 2.5,
      carbs: 28,
      protein: 8,
      method: 'text' as const,
    },
    {
      food: 'Avocado',
      qty: 0.5,
      unit: 'piece',
      kcal: 160,
      fat: 14.7,
      carbs: 8.5,
      protein: 2,
      method: 'photo' as const,
    },
    {
      food: 'Almonds',
      qty: 30,
      unit: 'g',
      kcal: 174,
      fat: 15,
      carbs: 6.1,
      protein: 6.4,
      method: 'text' as const,
    },
    {
      food: 'Sweet Potato',
      qty: 150,
      unit: 'g',
      kcal: 129,
      fat: 0.2,
      carbs: 30,
      protein: 2.3,
      method: 'voice' as const,
    }
  ];

  console.log('🍎 Adding sample food entries...');

  // Add entries with different timestamps to simulate real usage over time
  for (let i = 0; i < sampleEntries.length; i++) {
    const entry = sampleEntries[i];
    const daysAgo = Math.floor(i / 2); // Spread entries over several days
    const date = new Date();
    date.setDate(date.getDate() - daysAgo);
    const dateString = formatLocalDate(date);

    await addEntry(entry, dateString);

    // Small delay to ensure different timestamps
    await new Promise(resolve => setTimeout(resolve, 10));
  }

  console.log('✅ Sample data added! Try typing "chicken", "apple", or "bread" in text input.');
};

// Check if sample data exists
export const hasSampleData = async (): Promise<boolean> => {
  const uniqueFood = await getAllUniqueFood();
  return uniqueFood.length > 0;
};

// Initialize daily reset check and timezone migration
export const initializeIDB = async (): Promise<void> => {
  checkDailyReset();
  await checkAndMigrateTimezone();
};
