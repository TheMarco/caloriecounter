'use client';

import { useState, useEffect, useCallback } from 'react';
import { getTodayEntries, deleteEntry, getTodayTotal, getTodayMacroTotals, todayKey } from '@/utils/idb';
import type { Entry, MacroTotals } from '@/types';

export function useTodayEntries() {
  const [entries, setEntries] = useState<Entry[]>([]);
  const [total, setTotal] = useState<number>(0);
  const [macroTotals, setMacroTotals] = useState<MacroTotals>({
    calories: 0,
    fat: 0,
    carbs: 0,
    protein: 0,
  });
  const [isLoading, setIsLoading] = useState(true);
  const [isRefreshing, setIsRefreshing] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const loadEntries = useCallback(async (isInitialLoad = false) => {
    try {
      console.log('📥 useTodayEntries: Loading entries...');
      if (isInitialLoad) {
        setIsLoading(true);
      } else {
        setIsRefreshing(true);
      }
      setError(null);

      const [todayEntries, todayTotal, todayMacroTotals] = await Promise.all([
        getTodayEntries(),
        getTodayTotal(),
        getTodayMacroTotals(),
      ]);

      console.log('📊 useTodayEntries: Loaded', todayEntries.length, 'entries, total:', todayTotal, 'macros:', todayMacroTotals);
      setEntries(todayEntries);
      setTotal(todayTotal);
      setMacroTotals(todayMacroTotals);
    } catch (err) {
      console.error('❌ useTodayEntries: Failed to load entries:', err);
      setError(err instanceof Error ? err.message : 'Failed to load entries');
    } finally {
      setIsLoading(false);
      setIsRefreshing(false);
    }
  }, []);

  const handleDeleteEntry = useCallback(async (id: string) => {
    try {
      setError(null);

      // Optimistically remove from UI
      const entryToDelete = entries.find(e => e.id === id);
      if (entryToDelete) {
        setEntries(prev => prev.filter(e => e.id !== id));
        setTotal(prev => prev - entryToDelete.kcal);
        // Update macro totals as well
        setMacroTotals(prev => ({
          calories: prev.calories - entryToDelete.kcal,
          fat: prev.fat - (entryToDelete.fat || 0),
          carbs: prev.carbs - (entryToDelete.carbs || 0),
          protein: prev.protein - (entryToDelete.protein || 0),
        }));
      }

      // Delete from IndexedDB
      const success = await deleteEntry(id);

      if (!success) {
        // Revert optimistic update
        if (entryToDelete) {
          setEntries(prev => [...prev, entryToDelete].sort((a, b) => b.ts - a.ts));
          setTotal(prev => prev + entryToDelete.kcal);
          setMacroTotals(prev => ({
            calories: prev.calories + entryToDelete.kcal,
            fat: prev.fat + (entryToDelete.fat || 0),
            carbs: prev.carbs + (entryToDelete.carbs || 0),
            protein: prev.protein + (entryToDelete.protein || 0),
          }));
        }
        throw new Error('Failed to delete entry');
      }

      console.log('Entry deleted successfully:', id);
    } catch (err) {
      console.error('Failed to delete entry:', err);
      setError(err instanceof Error ? err.message : 'Failed to delete entry');

      // Reload entries to ensure consistency
      loadEntries(false);
    }
  }, [entries, loadEntries]);

  const refreshEntries = useCallback(() => {
    console.log('🔄 useTodayEntries: Refreshing entries...');
    loadEntries(false); // Not an initial load
  }, [loadEntries]);

  // Load entries on mount
  useEffect(() => {
    loadEntries(true); // Initial load
  }, [loadEntries]);

  // Auto-refresh when the day changes
  useEffect(() => {
    const checkDayChange = () => {
      const currentDay = todayKey();
      const lastDay = localStorage.getItem('lastRefreshDay');

      if (lastDay !== currentDay) {
        localStorage.setItem('lastRefreshDay', currentDay);
        loadEntries(false); // Not an initial load
      }
    };

    // Check every minute
    const interval = setInterval(checkDayChange, 60000);

    return () => clearInterval(interval);
  }, [loadEntries]);

  return {
    entries,
    total,
    macroTotals,
    isLoading,
    isRefreshing,
    error,
    deleteEntry: handleDeleteEntry,
    refreshEntries,
    todayDate: todayKey(),
  };
}
