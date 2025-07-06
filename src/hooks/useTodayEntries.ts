'use client';

import { useState, useEffect, useCallback } from 'react';
import { getTodayEntries, deleteEntry, getTodayTotal, todayKey } from '@/utils/idb';
import type { Entry } from '@/types';

export function useTodayEntries() {
  const [entries, setEntries] = useState<Entry[]>([]);
  const [total, setTotal] = useState<number>(0);
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

      const [todayEntries, todayTotal] = await Promise.all([
        getTodayEntries(),
        getTodayTotal(),
      ]);

      console.log('📊 useTodayEntries: Loaded', todayEntries.length, 'entries, total:', todayTotal);
      setEntries(todayEntries);
      setTotal(todayTotal);
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
      }

      // Delete from IndexedDB
      const success = await deleteEntry(id);

      if (!success) {
        // Revert optimistic update
        if (entryToDelete) {
          setEntries(prev => [...prev, entryToDelete].sort((a, b) => b.ts - a.ts));
          setTotal(prev => prev + entryToDelete.kcal);
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
    isLoading,
    isRefreshing,
    error,
    deleteEntry: handleDeleteEntry,
    refreshEntries,
    todayDate: todayKey(),
  };
}
