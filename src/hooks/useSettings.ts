'use client';

import { useState, useEffect, useCallback } from 'react';
import { useTheme } from '@/contexts/ThemeContext';

export interface AppSettings {
  dailyTarget: number;
  notifications: boolean;
  units: 'metric' | 'imperial';
}

const DEFAULT_SETTINGS: AppSettings = {
  dailyTarget: 2000,
  notifications: true,
  units: 'metric',
};

const SETTINGS_KEY = 'calorie-counter-settings';

export function useSettings() {
  const [settings, setSettings] = useState<AppSettings>(DEFAULT_SETTINGS);
  const [isLoading, setIsLoading] = useState(true);
  const { theme, setTheme, isDark } = useTheme();

  // Load settings from localStorage on mount
  useEffect(() => {
    try {
      const savedSettings = localStorage.getItem(SETTINGS_KEY);
      if (savedSettings) {
        const parsed = JSON.parse(savedSettings);
        const loadedSettings = { ...DEFAULT_SETTINGS, ...parsed };
        setSettings(loadedSettings);
      }
    } catch (error) {
      console.error('Failed to load settings:', error);
    } finally {
      setIsLoading(false);
    }
  }, []);

  // Save settings to localStorage
  const saveSettings = useCallback((newSettings: Partial<AppSettings>) => {
    try {
      const updatedSettings = { ...settings, ...newSettings };
      setSettings(updatedSettings);
      localStorage.setItem(SETTINGS_KEY, JSON.stringify(updatedSettings));
      return true;
    } catch (error) {
      console.error('Failed to save settings:', error);
      return false;
    }
  }, [settings]);

  // Update individual setting
  const updateSetting = useCallback(<K extends keyof AppSettings>(
    key: K,
    value: AppSettings[K]
  ) => {
    return saveSettings({ [key]: value });
  }, [saveSettings]);

  // Reset to defaults
  const resetSettings = useCallback(() => {
    try {
      setSettings(DEFAULT_SETTINGS);
      localStorage.removeItem(SETTINGS_KEY);
      return true;
    } catch (error) {
      console.error('Failed to reset settings:', error);
      return false;
    }
  }, []);

  // Theme-related functions
  const toggleDarkMode = useCallback(() => {
    setTheme(isDark ? 'light' : 'dark');
  }, [isDark, setTheme]);

  const setDarkMode = useCallback((enabled: boolean) => {
    setTheme(enabled ? 'dark' : 'light');
  }, [setTheme]);

  return {
    settings,
    isLoading,
    saveSettings,
    updateSetting,
    resetSettings,
    // Theme-related
    darkMode: isDark,
    toggleDarkMode,
    setDarkMode,
    theme,
  };
}
