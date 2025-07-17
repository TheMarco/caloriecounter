'use client';

import { useState, useEffect, useCallback } from 'react';
import { getEntriesByDate, deleteEntry, getMacroTotalsForDate, getCalorieOffset } from '@/utils/idb';
import type { Entry, MacroTotals } from '@/types';

export function useDayEntries(date: string) {
  const [entries, setEntries] = useState<Entry[]>([]);
  const [macroTotals, setMacroTotals] = useState<MacroTotals>({
    calories: 0,
    fat: 0,
    carbs: 0,
    protein: 0,
  });
  const [calorieOffset, setCalorieOffset] = useState<number>(0);
  const [isLoading, setIsLoading] = useState(true);
  const [isRefreshing, setIsRefreshing] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const loadDayData = useCallback(async () => {
    try {
      setError(null);
      const [dayEntries, dayTotals, dayOffset] = await Promise.all([
        getEntriesByDate(date),
        getMacroTotalsForDate(date),
        getCalorieOffset(date)
      ]);

      setEntries(dayEntries);
      setMacroTotals(dayTotals);
      setCalorieOffset(dayOffset);
    } catch (err) {
      console.error('Failed to load day data:', err);
      setError('Failed to load day data');
    } finally {
      setIsLoading(false);
      setIsRefreshing(false);
    }
  }, [date]);

  // Load data when date changes
  useEffect(() => {
    if (date) {
      setIsLoading(true);
      loadDayData();
    }
  }, [loadDayData, date]);

  const refreshData = useCallback(async () => {
    setIsRefreshing(true);
    await loadDayData();
  }, [loadDayData]);

  const deleteDayEntry = useCallback(async (id: string): Promise<boolean> => {
    try {
      const success = await deleteEntry(id);
      if (success) {
        await refreshData();
      }
      return success;
    } catch (err) {
      console.error('Failed to delete entry:', err);
      return false;
    }
  }, [refreshData]);

  const formatDate = (dateStr: string) => {
    // Parse the date string as local date to avoid timezone issues
    const [year, month, day] = dateStr.split('-').map(Number);
    const date = new Date(year, month - 1, day); // month is 0-indexed
    return date.toLocaleDateString('en-US', {
      weekday: 'long',
      month: 'long',
      day: 'numeric'
    });
  };

  const isToday = () => {
    const today = new Date();
    const todayStr = `${today.getFullYear()}-${String(today.getMonth() + 1).padStart(2, '0')}-${String(today.getDate()).padStart(2, '0')}`;
    return date === todayStr;
  };

  return {
    entries,
    macroTotals,
    calorieOffset,
    isLoading,
    isRefreshing,
    error,
    refreshData,
    deleteEntry: deleteDayEntry,
    formattedDate: formatDate(date),
    isToday: isToday(),
    date
  };
}
