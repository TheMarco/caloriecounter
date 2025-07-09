'use client';

import { useState, useEffect, useCallback } from 'react';

export interface AppSettings {
  dailyTarget: number;
  fatTarget: number;
  carbsTarget: number;
  proteinTarget: number;
  units: 'metric' | 'imperial';
}

const DEFAULT_SETTINGS: AppSettings = {
  dailyTarget: 2000,
  fatTarget: 65,
  carbsTarget: 250,
  proteinTarget: 100,
  units: 'metric',
};

const SETTINGS_KEY = 'calorie-counter-settings';

export function useSettings() {
  const [settings, setSettings] = useState<AppSettings>(DEFAULT_SETTINGS);
  const [isLoading, setIsLoading] = useState(true);

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
      setSettings(currentSettings => {
        const updatedSettings = { ...currentSettings, ...newSettings };
        localStorage.setItem(SETTINGS_KEY, JSON.stringify(updatedSettings));
        return updatedSettings;
      });
      return true;
    } catch (error) {
      console.error('Failed to save settings:', error);
      return false;
    }
  }, []);

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

  return {
    settings,
    isLoading,
    saveSettings,
    updateSetting,
    resetSettings,
  };
}
