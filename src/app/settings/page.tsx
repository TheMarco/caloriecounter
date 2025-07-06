'use client';

import { useState, useEffect } from 'react';
import Link from 'next/link';
import { useSettings } from '@/hooks/useSettings';

import {
  HomeIconComponent,
  ChartIconComponent,
  SettingsIconComponent,
  CheckIconComponent,
  InfoIconComponent
} from '@/components/icons';

export default function Settings() {
  const { settings, isLoading, updateSetting, resetSettings } = useSettings();
  const [isSaving, setIsSaving] = useState(false);
  const [mounted, setMounted] = useState(false);

  useEffect(() => {
    setMounted(true);
  }, []);

  const handleSave = async () => {
    setIsSaving(true);
    try {
      // Settings are automatically saved when changed, so just show success
      alert('Settings saved successfully!');
    } catch {
      alert('Failed to save settings. Please try again.');
    } finally {
      setIsSaving(false);
    }
  };

  const handleReset = async () => {
    if (confirm('Are you sure you want to reset all settings to default?')) {
      const success = resetSettings();
      if (success) {
        alert('Settings reset to defaults successfully!');
      } else {
        alert('Failed to reset settings. Please try again.');
      }
    }
  };

  const handleClearData = () => {
    if (confirm('Are you sure you want to clear all your calorie data? This cannot be undone.')) {
      // Clear IndexedDB data
      if (typeof window !== 'undefined' && 'indexedDB' in window) {
        indexedDB.deleteDatabase('keyval-store');
        alert('All data cleared successfully!');
      }
    }
  };

  // Prevent hydration mismatch
  if (!mounted) {
    return (
      <div className="min-h-screen bg-black">
        <div className="animate-pulse">
          <header className="bg-black shadow-sm border-b border-gray-800">
            <div className="max-w-md mx-auto px-6 py-4">
              <h1 className="text-2xl font-bold text-center text-white">Settings</h1>
            </div>
          </header>
          <main className="max-w-md mx-auto px-6 py-6">
            <div className="bg-gray-900 rounded-2xl shadow-sm border border-gray-800 p-6 mb-6">
              <div className="h-4 bg-gray-700 rounded w-1/3 mb-4"></div>
              <div className="h-10 bg-gray-700 rounded"></div>
            </div>
          </main>
        </div>
      </div>
    );
  }

  return (
    <div className="min-h-screen bg-black transition-theme">
      {/* Header */}
      <header className="bg-black/80 backdrop-blur-xl border-b border-gray-800/50 sticky top-0 z-10 transition-theme">
        <div className="max-w-md mx-auto px-6 py-4">
          <h1 className="text-2xl font-bold text-center text-white">Settings</h1>
        </div>
      </header>

      {/* Main Content */}
      <main className="max-w-md mx-auto px-6 py-6 pb-24">

        {isLoading && (
          <div className="text-center py-8">
            <div className="animate-spin rounded-full h-8 w-8 border-b-2 border-blue-500 dark:border-blue-400 mx-auto mb-4"></div>
            <p className="text-gray-200">Loading settings...</p>
          </div>
        )}

        {/* Daily Target */}
        <div className="bg-gray-900 rounded-2xl shadow-sm border border-gray-800/50 p-6 mb-6 transition-theme hover:shadow-md hover:scale-105 duration-200">
          <h2 className="text-lg font-semibold text-white mb-6">Daily Calorie Target</h2>
          <div className="space-y-4">
            <div>
              <label className="block text-sm font-semibold text-gray-200 mb-3">
                Target Calories per Day
              </label>
              <input
                type="number"
                value={settings.dailyTarget}
                onChange={(e) => updateSetting('dailyTarget', Number(e.target.value))}
                className="w-full px-4 py-4 border border-gray-600 rounded-xl focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-blue-500 bg-gray-800 text-white transition-all font-medium text-lg"
                min="1000"
                max="5000"
                step="50"
                disabled={isLoading}
              />
              <p className="text-sm text-gray-400 mt-3 font-medium">
                Recommended: 1,800-2,400 calories for most adults
              </p>
            </div>
          </div>
        </div>

        {/* Preferences */}
        <div className="bg-gray-900 rounded-2xl shadow-sm border border-gray-800/50 p-6 mb-6 transition-theme hover:shadow-md hover:scale-105 duration-200">
          <h2 className="text-lg font-semibold text-white mb-6">Preferences</h2>
          <div className="space-y-6">

            {/* Units */}
            <div>
              <label className="block text-sm font-semibold text-gray-800 dark:text-gray-200 mb-4">
                Measurement Units
              </label>
              <div className="grid grid-cols-2 gap-3">
                <label className={`flex items-center p-4 rounded-xl border-2 cursor-pointer transition-all duration-200 ${
                  settings.units === 'metric'
                    ? 'border-blue-500 bg-blue-50 dark:bg-blue-900/20 text-blue-700 dark:text-blue-300'
                    : 'border-gray-200 dark:border-gray-700 hover:border-gray-300 dark:hover:border-gray-600 text-gray-800 dark:text-gray-200'
                }`}>
                  <input
                    type="radio"
                    value="metric"
                    checked={settings.units === 'metric'}
                    onChange={(e) => updateSetting('units', e.target.value as 'metric')}
                    className="sr-only"
                    disabled={isLoading}
                  />
                  <div className="text-center w-full">
                    <div className="font-semibold">Metric</div>
                    <div className="text-xs mt-1 opacity-75">g, kg, ml, l</div>
                  </div>
                </label>
                <label className={`flex items-center p-4 rounded-xl border-2 cursor-pointer transition-all duration-200 ${
                  settings.units === 'imperial'
                    ? 'border-blue-500 bg-blue-50 dark:bg-blue-900/20 text-blue-700 dark:text-blue-300'
                    : 'border-gray-200 dark:border-gray-700 hover:border-gray-300 dark:hover:border-gray-600 text-gray-800 dark:text-gray-200'
                }`}>
                  <input
                    type="radio"
                    value="imperial"
                    checked={settings.units === 'imperial'}
                    onChange={(e) => updateSetting('units', e.target.value as 'imperial')}
                    className="sr-only"
                    disabled={isLoading}
                  />
                  <div className="text-center w-full">
                    <div className="font-semibold">Imperial</div>
                    <div className="text-xs mt-1 opacity-75">oz, lb, fl oz, cups</div>
                  </div>
                </label>
              </div>
            </div>




          </div>
        </div>

        {/* Data Management */}
        <div className="bg-gray-900 rounded-2xl shadow-sm border border-gray-800/50 p-6 mb-6 transition-theme hover:shadow-md hover:scale-105 duration-200">
          <h2 className="text-lg font-semibold text-white mb-6">Data Management</h2>
          <div className="space-y-4">
            <button
              onClick={handleClearData}
              className="w-full bg-red-500 hover:bg-red-600 text-white px-6 py-4 rounded-xl text-sm font-semibold transition-all duration-200 hover:scale-105 active:scale-95"
            >
              Clear All Data
            </button>
            <p className="text-sm text-gray-300 font-medium">
              This will permanently delete all your calorie entries and cannot be undone.
            </p>
          </div>
        </div>

        {/* App Info */}
        <div className="bg-gray-900 rounded-2xl shadow-sm border border-gray-800/50 p-6 mb-8 transition-theme hover:shadow-md hover:scale-105 duration-200">
          <h2 className="text-lg font-semibold text-white mb-6">About</h2>
          <div className="space-y-3">
            <div className="flex items-center space-x-3 p-3 bg-blue-50 dark:bg-blue-900/20 rounded-xl border border-blue-200 dark:border-blue-800/50">
              <InfoIconComponent size="sm" className="text-blue-600 dark:text-blue-400" />
              <span className="font-semibold text-blue-700 dark:text-blue-300">Calorie Counter PWA v1.0.0</span>
            </div>
            <p className="text-sm text-gray-300 font-medium leading-relaxed">
              A lightning-fast calorie tracking app with barcode scanning and voice input.
            </p>
          </div>
        </div>

        {/* Action Buttons */}
        <div className="space-y-4">
          <button
            onClick={handleSave}
            disabled={isSaving || isLoading}
            className="w-full bg-blue-500 hover:bg-blue-600 disabled:bg-blue-300 text-white px-6 py-4 rounded-xl font-semibold transition-all duration-200 flex items-center justify-center space-x-3 hover:scale-105 active:scale-95 disabled:scale-100"
          >
            {isSaving ? (
              <div className="w-5 h-5 animate-spin rounded-full border-2 border-white border-t-transparent"></div>
            ) : (
              <CheckIconComponent size="sm" className="text-white" />
            )}
            <span>{isSaving ? 'Saving...' : 'Save Settings'}</span>
          </button>

          <button
            onClick={handleReset}
            className="w-full bg-gray-500 hover:bg-gray-600 text-white px-6 py-4 rounded-xl font-semibold transition-all duration-200 hover:scale-105 active:scale-95"
          >
            Reset to Defaults
          </button>
        </div>
      </main>

      {/* Bottom Navigation */}
      <nav className="fixed bottom-0 left-0 right-0 bg-black/80 backdrop-blur-xl border-t border-gray-800/50 transition-theme">
        <div className="max-w-md mx-auto px-6">
          <div className="flex justify-around py-3">
            <Link href="/" className="flex flex-col items-center py-2 px-4 text-gray-400 hover:text-white transition-colors">
              <div className="mb-1">
                <HomeIconComponent size="lg" className="text-gray-400 hover:text-white transition-colors" />
              </div>
              <div className="text-xs font-medium">Today</div>
            </Link>
            <Link href="/history" className="flex flex-col items-center py-2 px-4 text-gray-400 hover:text-white transition-colors">
              <div className="mb-1">
                <ChartIconComponent size="lg" className="text-gray-400 hover:text-white transition-colors" />
              </div>
              <div className="text-xs font-medium">History</div>
            </Link>
            <button className="flex flex-col items-center py-2 px-4 text-blue-500 dark:text-blue-400">
              <div className="mb-1">
                <SettingsIconComponent size="lg" solid className="text-blue-500 dark:text-blue-400" />
              </div>
              <div className="text-xs font-medium">Settings</div>
            </button>
          </div>
        </div>
      </nav>
    </div>
  );
}
