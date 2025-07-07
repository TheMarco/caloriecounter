// IndexedDB wrapper using idb-keyval for local-first storage
import { get, set, del, keys, clear } from 'idb-keyval';
import { createId } from '@paralleldrive/cuid2';
import type { Entry, MacroTotals } from '@/types';

// Key generators
export const todayKey = (): string => new Date().toISOString().slice(0, 10);

export const entryKey = (id: string): string => `entry:${id}`;

export const dateKey = (date: string): string => `date:${date}`;

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
export const addEntry = async (entryData: Omit<Entry, 'id' | 'ts' | 'dt'>): Promise<Entry> => {
  const entry: Entry = {
    ...entryData,
    id: createId(),
    ts: Date.now(),
    dt: todayKey(),
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
    const dateStr = date.toISOString().slice(0, 10);

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
    const dateStr = date.toISOString().slice(0, 10);

    const totals = await getMacroTotalsForDate(dateStr);
    results.push({ date: dateStr, totals });
  }

  return results.reverse(); // Oldest first for charts
};

// Utility functions
export const clearAllData = async (): Promise<void> => {
  await clear();
  localStorage.removeItem('lastDay');
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

// Initialize daily reset check
export const initializeIDB = (): void => {
  checkDailyReset();
};
