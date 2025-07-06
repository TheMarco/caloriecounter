'use client';

import { useState, useEffect, useCallback } from 'react';
import { useTheme } from '@/contexts/ThemeContext';

export interface AppSettings {
  dailyTarget: number;
  notifications: boolean;
  darkMode: boolean;
  units: 'metric' | 'imperial';
}

const DEFAULT_SETTINGS: AppSettings = {
  dailyTarget: 2000,
  notifications: true,
  darkMode: false,
  units: 'metric',
};

const SETTINGS_KEY = 'calorie-counter-settings';

export function useSettings() {
  const [settings, setSettings] = useState<AppSettings>(DEFAULT_SETTINGS);
  const [isLoading, setIsLoading] = useState(true);

  // Safely get theme context (may not be available during SSR)
  let setTheme: ((theme: 'light' | 'dark') => void) | null = null;
  try {
    const themeContext = useTheme();
    setTheme = themeContext.setTheme;
  } catch {
    // Theme context not available (e.g., during SSR)
    setTheme = null;
  }

  // Load settings from localStorage on mount
  useEffect(() => {
    try {
      const savedSettings = localStorage.getItem(SETTINGS_KEY);
      if (savedSettings) {
        const parsed = JSON.parse(savedSettings);
        const loadedSettings = { ...DEFAULT_SETTINGS, ...parsed };
        setSettings(loadedSettings);
        // Apply theme immediately (if available)
        if (setTheme) {
          setTheme(loadedSettings.darkMode ? 'dark' : 'light');
        }
      }
    } catch (error) {
      console.error('Failed to load settings:', error);
    } finally {
      setIsLoading(false);
    }
  }, [setTheme]);

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
    const success = saveSettings({ [key]: value });

    // Apply theme change immediately (if available)
    if (key === 'darkMode' && success && setTheme) {
      setTheme(value as boolean ? 'dark' : 'light');
    }

    return success;
  }, [saveSettings, setTheme]);

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

  return {
    settings,
    isLoading,
    saveSettings,
    updateSetting,
    resetSettings,
  };
}
