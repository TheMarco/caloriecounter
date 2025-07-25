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

// Initialize daily reset check and timezone migration
export const initializeIDB = async (): Promise<void> => {
  checkDailyReset();
  await checkAndMigrateTimezone();
};
